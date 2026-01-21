extends RigidBody2D
class_name GrenadeBase
## Abstract base class for all grenades.
##
## Handles common grenade mechanics:
## - Timer-based detonation (4 seconds)
## - Physics-based throwing with drag distance/direction determining velocity
## - Explosion sound audible at 2 viewport distance
## - Max throw distance = viewport length
## - Min throw distance = at player feet (short drag)
##
## Subclasses should override:
## - _on_explode(): Define explosion effects
## - _get_effect_radius(): Define effect area

## Time until explosion in seconds (starts when timer is activated).
@export var fuse_time: float = 4.0

## Maximum throw speed in pixels per second.
## This corresponds to max drag distance creating viewport-length throw.
@export var max_throw_speed: float = 1280.0

## Minimum throw speed for a minimal drag.
@export var min_throw_speed: float = 50.0

## Drag multiplier to convert drag distance to throw speed.
## Calibrated so viewport-length drag = viewport-length throw.
@export var drag_to_speed_multiplier: float = 4.0

## Friction/damping applied to slow the grenade.
@export var ground_friction: float = 300.0

## Sound range multiplier (2 = audible at 2 viewport distance).
@export var sound_range_multiplier: float = 2.0

## Whether the grenade timer has been activated.
var _timer_active: bool = false

## Time remaining until explosion.
var _time_remaining: float = 0.0

## Whether the grenade has exploded.
var _has_exploded: bool = false

## Reference to the sprite for visual feedback.
@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

## Blink timer for visual feedback when about to explode.
var _blink_timer: float = 0.0

## Blink interval - gets faster as explosion approaches.
var _blink_interval: float = 0.5

## Signal emitted when the grenade explodes.
signal exploded(position: Vector2, grenade: GrenadeBase)


func _ready() -> void:
	# Set up collision
	collision_layer = 32  # Layer 6 (custom for grenades)
	collision_mask = 4 | 2 | 1  # obstacles, enemies, player

	# Set up physics
	gravity_scale = 0.0  # Top-down, no gravity
	linear_damp = 2.0  # Natural slowdown

	# Connect to body entered for bounce effects
	body_entered.connect(_on_body_entered)

	FileLogger.info("[GrenadeBase] Grenade created at %s" % str(global_position))


func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	# Apply ground friction to slow down
	if linear_velocity.length() > 0:
		var friction_force := linear_velocity.normalized() * ground_friction * delta
		if friction_force.length() > linear_velocity.length():
			linear_velocity = Vector2.ZERO
		else:
			linear_velocity -= friction_force

	# Update timer if active
	if _timer_active:
		_time_remaining -= delta
		_update_blink_effect(delta)

		if _time_remaining <= 0:
			_explode()


## Activate the grenade timer. Call this when the player starts the throwing motion.
func activate_timer() -> void:
	if _timer_active:
		FileLogger.info("[GrenadeBase] Timer already active")
		return
	_timer_active = true
	_time_remaining = fuse_time
	FileLogger.info("[GrenadeBase] Timer activated! %.1f seconds until explosion" % fuse_time)


## Throw the grenade in a direction with speed based on drag distance.
## @param direction: Normalized direction to throw.
## @param drag_distance: Distance of the drag in pixels.
func throw_grenade(direction: Vector2, drag_distance: float) -> void:
	# Calculate throw speed based on drag distance
	var throw_speed := clampf(
		drag_distance * drag_to_speed_multiplier,
		min_throw_speed,
		max_throw_speed
	)

	# Set velocity
	linear_velocity = direction.normalized() * throw_speed

	# Rotate to face direction
	rotation = direction.angle()

	FileLogger.info("[GrenadeBase] Thrown! Direction: %s, Speed: %.1f" % [str(direction), throw_speed])


## Get the explosion effect radius. Override in subclasses.
func _get_effect_radius() -> float:
	# Default: small room size (~200 pixels, roughly 1/6 of viewport width)
	return 200.0


## Called when the grenade explodes. Override in subclasses for specific effects.
func _on_explode() -> void:
	# Base implementation does nothing - subclasses define explosion behavior
	pass


## Internal explosion handling.
func _explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true

	FileLogger.info("[GrenadeBase] EXPLODED at %s!" % str(global_position))

	# Play explosion sound
	_play_explosion_sound()

	# Call subclass explosion effect
	_on_explode()

	# Emit signal
	exploded.emit(global_position, self)

	# Destroy grenade after a short delay for effects
	await get_tree().create_timer(0.1).timeout
	queue_free()


## Play explosion sound audible at 2 viewport distance.
func _play_explosion_sound() -> void:
	var sound_propagation: Node = get_node_or_null("/root/SoundPropagation")
	if sound_propagation and sound_propagation.has_method("emit_sound"):
		# Calculate sound range (2 viewport diagonals)
		var viewport := get_viewport()
		var viewport_diagonal := 1469.0  # Default 1280x720 diagonal
		if viewport:
			var size := viewport.get_visible_rect().size
			viewport_diagonal = sqrt(size.x * size.x + size.y * size.y)

		var sound_range := viewport_diagonal * sound_range_multiplier
		# 1 = EXPLOSION type, 2 = NEUTRAL source
		sound_propagation.emit_sound(1, global_position, 2, self, sound_range)


## Update visual blink effect as explosion approaches.
func _update_blink_effect(delta: float) -> void:
	if not _sprite:
		return

	# Blink faster as time decreases
	if _time_remaining < 1.0:
		_blink_interval = 0.05
	elif _time_remaining < 2.0:
		_blink_interval = 0.15
	elif _time_remaining < 3.0:
		_blink_interval = 0.3
	else:
		_blink_interval = 0.5

	_blink_timer += delta
	if _blink_timer >= _blink_interval:
		_blink_timer = 0.0
		# Toggle visibility or color
		if _sprite.modulate.r > 0.9:
			_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Red tint
		else:
			_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal


## Handle collision with bodies (bounce off walls).
func _on_body_entered(body: Node) -> void:
	# Play bounce sound if hitting a wall
	if body is StaticBody2D or body is TileMap:
		var audio_manager: Node = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.has_method("play_grenade_bounce"):
			audio_manager.play_grenade_bounce(global_position)


## Check if a position is within the grenade's effect radius.
func is_in_effect_radius(pos: Vector2) -> bool:
	return global_position.distance_to(pos) <= _get_effect_radius()


## Get the remaining time until explosion.
func get_time_remaining() -> float:
	return _time_remaining


## Check if the timer is active.
func is_timer_active() -> bool:
	return _timer_active


## Check if the grenade has exploded.
func has_exploded() -> bool:
	return _has_exploded
