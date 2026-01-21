extends CharacterBody2D
## Player character controller for top-down movement and shooting.
##
## Uses physics-based movement with acceleration and friction for smooth control.
## Supports WASD and arrow key input via configured input actions.
## Shoots bullets towards the mouse cursor on left mouse button click.
## Features limited ammunition system with progressive spread.
## Includes health system for taking damage from enemy projectiles.

## Maximum movement speed in pixels per second.
@export var max_speed: float = 300.0

## Acceleration rate - how quickly the player reaches max speed.
@export var acceleration: float = 1200.0

## Friction rate - how quickly the player slows down when not moving.
@export var friction: float = 1000.0

## Bullet scene to instantiate when shooting.
@export var bullet_scene: PackedScene

## Offset from player center for bullet spawn position.
@export var bullet_spawn_offset: float = 20.0

## Maximum ammunition (default 90 bullets = 3 magazines of 30 for Normal mode).
## In Hard mode, this is reduced to 60 bullets (2 magazines).
@export var max_ammo: int = 90

## Maximum health of the player.
@export var max_health: int = 5

## Weapon loudness - determines how far gunshots propagate for enemy detection.
## Set to viewport diagonal (~1469 pixels) for assault rifle by default.
## This affects how far enemies can hear the player's gunshots.
@export var weapon_loudness: float = 1469.0

## Reload mode: simple (press R once) or sequence (R-F-R).
@export_enum("Simple", "Sequence") var reload_mode: int = 1  # Default to Sequence mode

## Time to reload in seconds (only used in Simple mode).
@export var reload_time: float = 1.5

## Color when at full health.
@export var full_health_color: Color = Color(0.2, 0.6, 1.0, 1.0)

## Color when at low health (interpolates based on health percentage).
@export var low_health_color: Color = Color(0.1, 0.2, 0.4, 1.0)

## Color to flash when hit.
@export var hit_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## Duration of hit flash effect in seconds.
@export var hit_flash_duration: float = 0.1

## Screen shake intensity per shot in pixels.
## The actual shake distance per shot is calculated as: intensity / fire_rate * 10
## Lower fire rate = larger shake per shot.
@export var screen_shake_intensity: float = 5.0

## Fire rate in shots per second (used for shake calculation).
## Default is 10.0 to match the assault rifle.
@export var fire_rate: float = 10.0

## Minimum recovery time for screen shake at minimum spread.
@export var screen_shake_min_recovery: float = 0.25

## Maximum recovery time for screen shake at maximum spread (min 50ms).
@export var screen_shake_max_recovery: float = 0.05

## Current ammunition count.
var _current_ammo: int = 90

## Current health of the player.
var _current_health: int = 5

## Whether the player is alive.
var _is_alive: bool = true

## Reference to the sprite for color changes.
@onready var _sprite: Sprite2D = $Sprite2D

## Progressive spread system parameters.
## Number of shots before spread starts increasing.
const SPREAD_THRESHOLD: int = 3
## Initial minimal spread in degrees.
const INITIAL_SPREAD: float = 0.5
## Spread increase per shot after threshold (degrees).
const SPREAD_INCREMENT: float = 0.6
## Maximum spread in degrees.
const MAX_SPREAD: float = 4.0
## Time in seconds for spread to reset after stopping fire.
const SPREAD_RESET_TIME: float = 0.25

## Current number of consecutive shots.
var _shot_count: int = 0
## Timer since last shot.
var _shot_timer: float = 0.0

## Reload sequence state (0 = waiting for R, 1 = waiting for F, 2 = waiting for R).
var _reload_sequence_step: int = 0

## Whether the player is currently in reload sequence (for Sequence mode).
var _is_reloading_sequence: bool = false

## Whether the player is currently reloading (for Simple mode).
var _is_reloading_simple: bool = false

## Timer for simple reload progress.
var _reload_timer: float = 0.0

## Signal emitted when ammo changes.
signal ammo_changed(current: int, maximum: int)

## Signal emitted when ammo is depleted.
signal ammo_depleted

## Signal emitted when the player is hit.
signal hit

## Signal emitted when health changes.
signal health_changed(current: int, maximum: int)

## Signal emitted when the player dies.
signal died

## Signal emitted when reload sequence progresses.
signal reload_sequence_progress(step: int, total: int)

## Signal emitted when reload completes.
signal reload_completed

## Signal emitted when reload starts (first step of sequence or simple reload).
## This signal notifies enemies that the player has begun reloading.
signal reload_started

## Signal emitted when grenade count changes.
signal grenade_changed(current: int, maximum: int)

## Signal emitted when a grenade is thrown.
signal grenade_thrown

## Grenade scene to instantiate when throwing.
@export var grenade_scene: PackedScene

## Maximum number of grenades the player can carry.
@export var max_grenades: int = 3

## Current number of grenades.
var _current_grenades: int = 3

## Whether the player is preparing to throw a grenade (G held down).
var _is_preparing_grenade: bool = false

## Position where the grenade throw drag started.
var _grenade_drag_start: Vector2 = Vector2.ZERO

## Whether the grenade throw drag has started.
var _grenade_drag_active: bool = false


func _ready() -> void:
	# Preload bullet scene if not set in inspector
	if bullet_scene == null:
		bullet_scene = preload("res://scenes/projectiles/Bullet.tscn")

	# Preload grenade scene if not set in inspector
	if grenade_scene == null:
		var grenade_path := "res://scenes/projectiles/FlashbangGrenade.tscn"
		if ResourceLoader.exists(grenade_path):
			grenade_scene = load(grenade_path)

	# Get max ammo from DifficultyManager based on current difficulty
	var difficulty_manager: Node = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager:
		max_ammo = difficulty_manager.get_max_ammo()
		# Connect to difficulty changes to update ammo limit mid-game
		if not difficulty_manager.difficulty_changed.is_connected(_on_difficulty_changed):
			difficulty_manager.difficulty_changed.connect(_on_difficulty_changed)

	_current_ammo = max_ammo
	_current_health = max_health
	_is_alive = true
	_update_health_visual()


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	var input_direction := _get_input_direction()

	if input_direction != Vector2.ZERO:
		# Apply acceleration towards the input direction
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
	else:
		# Apply friction to slow down
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	# Update spread reset timer
	_shot_timer += delta
	if _shot_timer >= SPREAD_RESET_TIME:
		_shot_count = 0

	# Update simple reload timer
	if _is_reloading_simple:
		_reload_timer += delta
		if _reload_timer >= reload_time:
			_complete_simple_reload()

	# Handle shooting input
	if Input.is_action_just_pressed("shoot"):
		_shoot()

	# Handle reload input based on mode
	if reload_mode == 0:  # Simple mode
		_handle_simple_reload_input()
	else:  # Sequence mode
		_handle_sequence_reload_input()

	# Handle grenade input
	_handle_grenade_input()


func _get_input_direction() -> Vector2:
	var direction := Vector2.ZERO
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")

	# Normalize to prevent faster diagonal movement
	if direction.length() > 1.0:
		direction = direction.normalized()

	return direction


## Calculate current spread based on consecutive shots.
func _get_current_spread() -> float:
	if _shot_count <= SPREAD_THRESHOLD:
		return INITIAL_SPREAD
	else:
		var extra_shots := _shot_count - SPREAD_THRESHOLD
		var spread := INITIAL_SPREAD + extra_shots * SPREAD_INCREMENT
		return minf(spread, MAX_SPREAD)


func _shoot() -> void:
	if bullet_scene == null:
		return

	# Check ammo
	if _current_ammo <= 0:
		# Play empty click sound
		var audio_manager: Node = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.has_method("play_empty_click"):
			audio_manager.play_empty_click(global_position)
		ammo_depleted.emit()
		return

	# Calculate direction towards mouse cursor
	var mouse_pos := get_global_mouse_position()
	var shoot_direction := (mouse_pos - global_position).normalized()

	# Apply spread
	var spread := _get_current_spread()
	var spread_radians := deg_to_rad(spread)
	var random_spread := randf_range(-spread_radians, spread_radians)
	shoot_direction = shoot_direction.rotated(random_spread)

	# Create bullet instance
	var bullet := bullet_scene.instantiate()

	# Set bullet position with offset in shoot direction
	bullet.global_position = global_position + shoot_direction * bullet_spawn_offset

	# Set bullet direction
	bullet.direction = shoot_direction

	# Set shooter ID to identify this player as the source
	# This prevents the player from being hit by their own bullets
	bullet.shooter_id = get_instance_id()

	# Set shooter position for distance-based penetration calculation
	# Direct assignment - the bullet script defines this property
	bullet.shooter_position = global_position

	# Add bullet to the scene tree (parent's parent to avoid it being a child of player)
	get_tree().current_scene.add_child(bullet)

	# Play shooting sound
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_m16_shot"):
		audio_manager.play_m16_shot(global_position)

	# Emit gunshot sound for in-game sound propagation (alerts enemies)
	# Uses weapon_loudness to determine propagation range
	var sound_propagation: Node = get_node_or_null("/root/SoundPropagation")
	if sound_propagation and sound_propagation.has_method("emit_sound"):
		# Use emit_sound with custom range for weapon-specific loudness
		sound_propagation.emit_sound(0, global_position, 0, self, weapon_loudness)  # 0 = GUNSHOT, 0 = PLAYER

	# Play shell casing sound with a small delay
	if audio_manager and audio_manager.has_method("play_shell_rifle"):
		_play_delayed_shell_sound()

	# Trigger screen shake
	_trigger_screen_shake(shoot_direction)

	# Update ammo and shot count
	_current_ammo -= 1
	_shot_count += 1
	_shot_timer = 0.0
	ammo_changed.emit(_current_ammo, max_ammo)


## Trigger screen shake based on shooting direction and current spread.
func _trigger_screen_shake(shoot_direction: Vector2) -> void:
	if screen_shake_intensity <= 0.0:
		return

	var screen_shake: Node = get_node_or_null("/root/ScreenShakeManager")
	if not screen_shake:
		return

	# Calculate shake intensity based on fire rate
	# Lower fire rate = larger shake per shot
	var shake_intensity: float
	if fire_rate > 0.0:
		shake_intensity = screen_shake_intensity / fire_rate * 10.0
	else:
		shake_intensity = screen_shake_intensity

	# Calculate spread ratio for recovery time interpolation
	var current_spread := _get_current_spread()
	var spread_ratio := 0.0
	if MAX_SPREAD > INITIAL_SPREAD:
		spread_ratio = clampf((current_spread - INITIAL_SPREAD) / (MAX_SPREAD - INITIAL_SPREAD), 0.0, 1.0)

	# Calculate recovery time based on spread ratio
	# At min spread -> slower recovery (min_recovery)
	# At max spread -> faster recovery (max_recovery)
	var recovery_time := lerpf(screen_shake_min_recovery, screen_shake_max_recovery, spread_ratio)
	# Clamp to minimum 50ms as per specification
	recovery_time = maxf(recovery_time, 0.05)

	# Trigger the shake via ScreenShakeManager
	screen_shake.add_shake(shoot_direction, shake_intensity, recovery_time)


## Play shell casing sound with a delay to simulate the casing hitting the ground.
func _play_delayed_shell_sound() -> void:
	await get_tree().create_timer(0.15).timeout
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_shell_rifle"):
		audio_manager.play_shell_rifle(global_position)


## Get current ammo count.
func get_current_ammo() -> int:
	return _current_ammo


## Get maximum ammo count.
func get_max_ammo() -> int:
	return max_ammo


## Handle simple reload input (just press R once).
## Reload takes reload_time seconds to complete.
func _handle_simple_reload_input() -> void:
	# Don't start reload if already reloading or at max ammo
	if _is_reloading_simple or _current_ammo >= max_ammo:
		return

	if Input.is_action_just_pressed("reload"):
		_is_reloading_simple = true
		_reload_timer = 0.0
		# Play full reload sound for simple mode
		var audio_manager: Node = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.has_method("play_reload_full"):
			audio_manager.play_reload_full(global_position)
		reload_sequence_progress.emit(1, 1)
		# Notify enemies that reload has started
		reload_started.emit()


## Complete the simple reload.
func _complete_simple_reload() -> void:
	_current_ammo = max_ammo
	_is_reloading_simple = false
	_reload_timer = 0.0
	ammo_changed.emit(_current_ammo, max_ammo)
	reload_completed.emit()
	# Emit reload completion sound for in-game sound propagation
	# This alerts enemies that player is no longer vulnerable and they should become cautious
	var sound_propagation: Node = get_node_or_null("/root/SoundPropagation")
	if sound_propagation and sound_propagation.has_method("emit_player_reload_complete"):
		sound_propagation.emit_player_reload_complete(global_position, self)


## Handle reload sequence input (R-F-R).
## Player must press R, then F, then R again to complete reload.
## Reload happens instantly once sequence is completed.
func _handle_sequence_reload_input() -> void:
	# Don't process reload if already at max ammo
	if _current_ammo >= max_ammo:
		_reload_sequence_step = 0
		_is_reloading_sequence = false
		return

	var audio_manager: Node = get_node_or_null("/root/AudioManager")

	match _reload_sequence_step:
		0:
			# Waiting for first R press
			if Input.is_action_just_pressed("reload"):
				_reload_sequence_step = 1
				_is_reloading_sequence = true
				# Play magazine out sound
				if audio_manager and audio_manager.has_method("play_reload_mag_out"):
					audio_manager.play_reload_mag_out(global_position)
				reload_sequence_progress.emit(1, 3)
				# Notify enemies that reload has started
				reload_started.emit()
		1:
			# Waiting for F press
			if Input.is_action_just_pressed("reload_step"):
				_reload_sequence_step = 2
				# Play magazine in sound
				if audio_manager and audio_manager.has_method("play_reload_mag_in"):
					audio_manager.play_reload_mag_in(global_position)
				reload_sequence_progress.emit(2, 3)
			elif Input.is_action_just_pressed("reload"):
				# R pressed again - restart sequence with mag out sound
				_reload_sequence_step = 1
				if audio_manager and audio_manager.has_method("play_reload_mag_out"):
					audio_manager.play_reload_mag_out(global_position)
				reload_sequence_progress.emit(1, 3)
		2:
			# Waiting for final R press
			if Input.is_action_just_pressed("reload"):
				# Play bolt cycling sound and complete reload
				if audio_manager and audio_manager.has_method("play_m16_bolt"):
					audio_manager.play_m16_bolt(global_position)
				_complete_reload()
			elif Input.is_action_just_pressed("reload_step"):
				# Wrong key pressed, reset sequence
				_reload_sequence_step = 1
				if audio_manager and audio_manager.has_method("play_reload_mag_out"):
					audio_manager.play_reload_mag_out(global_position)
				reload_sequence_progress.emit(1, 3)


## Complete the reload - instantly refill ammo.
func _complete_reload() -> void:
	_current_ammo = max_ammo
	_reload_sequence_step = 0
	_is_reloading_sequence = false
	ammo_changed.emit(_current_ammo, max_ammo)
	reload_completed.emit()
	reload_sequence_progress.emit(3, 3)
	# Emit reload completion sound for in-game sound propagation
	# This alerts enemies that player is no longer vulnerable and they should become cautious
	var sound_propagation: Node = get_node_or_null("/root/SoundPropagation")
	if sound_propagation and sound_propagation.has_method("emit_player_reload_complete"):
		sound_propagation.emit_player_reload_complete(global_position, self)


## Check if player is currently reloading (either mode).
func is_reloading() -> bool:
	return _is_reloading_sequence or _is_reloading_simple


## Get current reload sequence step (0-2).
func get_reload_step() -> int:
	return _reload_sequence_step


## Cancel the reload (both modes) and reset.
func cancel_reload() -> void:
	_reload_sequence_step = 0
	_is_reloading_sequence = false
	_is_reloading_simple = false
	_reload_timer = 0.0


## Called when hit by a projectile.
func on_hit() -> void:
	# Call extended version with default values
	on_hit_with_info(Vector2.RIGHT, null)


## Called when hit by a projectile with extended hit information.
## @param hit_direction: Direction the bullet was traveling.
## @param caliber_data: Caliber resource for effect scaling.
func on_hit_with_info(hit_direction: Vector2, caliber_data: Resource) -> void:
	if not _is_alive:
		return

	hit.emit()

	# Show hit flash effect
	_show_hit_flash()

	# Apply damage
	_current_health -= 1
	health_changed.emit(_current_health, max_health)

	# Register damage with ScoreManager
	var score_manager: Node = get_node_or_null("/root/ScoreManager")
	if score_manager and score_manager.has_method("register_damage_taken"):
		score_manager.register_damage_taken(1)

	# Play appropriate hit sound and spawn visual effects
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	var impact_manager: Node = get_node_or_null("/root/ImpactEffectsManager")

	if _current_health <= 0:
		# Play lethal hit sound
		if audio_manager and audio_manager.has_method("play_hit_lethal"):
			audio_manager.play_hit_lethal(global_position)
		# Spawn blood splatter effect for lethal hit (with decal)
		if impact_manager and impact_manager.has_method("spawn_blood_effect"):
			impact_manager.spawn_blood_effect(global_position, hit_direction, caliber_data, true)
		_on_death()
	else:
		# Play non-lethal hit sound
		if audio_manager and audio_manager.has_method("play_hit_non_lethal"):
			audio_manager.play_hit_non_lethal(global_position)
		# Spawn blood effect for non-lethal hit (smaller, no decal)
		if impact_manager and impact_manager.has_method("spawn_blood_effect"):
			impact_manager.spawn_blood_effect(global_position, hit_direction, caliber_data, false)
		_update_health_visual()


## Shows a brief flash effect when hit.
func _show_hit_flash() -> void:
	if not _sprite:
		return

	_sprite.modulate = hit_flash_color

	await get_tree().create_timer(hit_flash_duration).timeout

	# Restore color based on current health (if still alive)
	if _is_alive:
		_update_health_visual()


## Updates the sprite color based on current health percentage.
func _update_health_visual() -> void:
	if not _sprite:
		return

	# Interpolate color based on health percentage
	var health_percent := _get_health_percent()
	_sprite.modulate = full_health_color.lerp(low_health_color, 1.0 - health_percent)


## Returns the current health as a percentage (0.0 to 1.0).
func _get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(_current_health) / float(max_health)


## Called when the player dies.
func _on_death() -> void:
	_is_alive = false
	died.emit()
	# Visual feedback - make sprite darker/transparent
	if _sprite:
		_sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)


## Get current health.
func get_current_health() -> int:
	return _current_health


## Get maximum health.
func get_max_health() -> int:
	return max_health


## Check if player is alive.
func is_alive() -> bool:
	return _is_alive


## Called when difficulty changes mid-game.
## Updates max ammo based on new difficulty setting.
func _on_difficulty_changed(_new_difficulty: int) -> void:
	var difficulty_manager: Node = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager:
		var new_max_ammo := difficulty_manager.get_max_ammo()
		# Only update if the max ammo changed
		if new_max_ammo != max_ammo:
			var old_max_ammo := max_ammo
			max_ammo = new_max_ammo
			# Scale current ammo proportionally, but cap at new max
			if old_max_ammo > 0:
				_current_ammo = mini(_current_ammo, max_ammo)
			else:
				_current_ammo = max_ammo
			ammo_changed.emit(_current_ammo, max_ammo)


# ============================================================================
# Grenade System
# ============================================================================


## Handle grenade input.
## Usage pattern:
## 1. Hold G to prepare grenade (starts timer)
## 2. Press and hold RMB to start drag
## 3. Release RMB to throw in drag direction with drag distance determining speed
func _handle_grenade_input() -> void:
	# Check if G key is pressed/held to prepare grenade
	if Input.is_action_pressed("grenade_prepare"):
		if not _is_preparing_grenade and _current_grenades > 0:
			_start_grenade_prepare()
	else:
		# G released without throwing - cancel preparation
		if _is_preparing_grenade and not _grenade_drag_active:
			_cancel_grenade_prepare()

	# If preparing, handle the drag throw mechanic
	if _is_preparing_grenade:
		# Start drag on RMB press
		if Input.is_action_just_pressed("grenade_throw"):
			_grenade_drag_start = get_global_mouse_position()
			_grenade_drag_active = true

		# Throw on RMB release (if drag was active)
		if Input.is_action_just_released("grenade_throw") and _grenade_drag_active:
			var drag_end := get_global_mouse_position()
			_throw_grenade(drag_end)


## Start preparing a grenade (G pressed).
func _start_grenade_prepare() -> void:
	if _current_grenades <= 0:
		return

	_is_preparing_grenade = true

	# Play preparation sound (pin pull)
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_grenade_prepare"):
		audio_manager.play_grenade_prepare(global_position)


## Cancel grenade preparation.
func _cancel_grenade_prepare() -> void:
	_is_preparing_grenade = false
	_grenade_drag_active = false
	_grenade_drag_start = Vector2.ZERO


## Throw the grenade based on drag direction and distance.
## @param drag_end: The position where the mouse drag ended.
func _throw_grenade(drag_end: Vector2) -> void:
	if grenade_scene == null or _current_grenades <= 0:
		_cancel_grenade_prepare()
		return

	# Calculate throw direction and distance
	var drag_vector := drag_end - _grenade_drag_start
	var drag_distance := drag_vector.length()

	# If drag is too short (dropped at feet), use minimum throw
	var min_drag_distance := 10.0
	if drag_distance < min_drag_distance:
		drag_distance = min_drag_distance
		drag_vector = Vector2(1, 0)  # Default direction if no drag

	# Clamp max drag distance to viewport length
	var viewport := get_viewport()
	var max_drag_distance := 1280.0  # Default viewport width
	if viewport:
		max_drag_distance = viewport.get_visible_rect().size.x
	drag_distance = minf(drag_distance, max_drag_distance)

	var throw_direction := drag_vector.normalized()

	# Create grenade instance
	var grenade: RigidBody2D = grenade_scene.instantiate()
	grenade.global_position = global_position

	# Activate the grenade timer (starts 4s countdown)
	if grenade.has_method("activate_timer"):
		grenade.activate_timer()

	# Set the throw velocity
	if grenade.has_method("throw_grenade"):
		grenade.throw_grenade(throw_direction, drag_distance)

	# Add grenade to scene
	get_tree().current_scene.add_child(grenade)

	# Update grenade count
	_current_grenades -= 1
	grenade_changed.emit(_current_grenades, max_grenades)
	grenade_thrown.emit()

	# Play throw sound
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_grenade_throw"):
		audio_manager.play_grenade_throw(global_position)

	# Reset preparation state
	_cancel_grenade_prepare()


## Get current grenade count.
func get_current_grenades() -> int:
	return _current_grenades


## Get maximum grenade count.
func get_max_grenades() -> int:
	return max_grenades


## Add grenades to inventory (e.g., from pickup).
func add_grenades(count: int) -> void:
	_current_grenades = mini(_current_grenades + count, max_grenades)
	grenade_changed.emit(_current_grenades, max_grenades)


## Check if player is preparing to throw a grenade.
func is_preparing_grenade() -> bool:
	return _is_preparing_grenade
