extends Node
## Autoload singleton for managing impact visual effects.
##
## Spawns particle effects when bullets hit different surfaces:
## - Wall/obstacle hits: Dust particles scatter in different directions
## - Lethal hits on enemies/players: Blood splatter effect
## - Non-lethal hits (armor): Spark particles
##
## Effect intensity scales based on weapon caliber.

## Preloaded particle effect scenes.
var _dust_effect_scene: PackedScene = null
var _blood_effect_scene: PackedScene = null
var _sparks_effect_scene: PackedScene = null

## Default effect scale for calibers without explicit setting.
const DEFAULT_EFFECT_SCALE: float = 1.0

## Minimum effect scale (prevents invisible effects).
const MIN_EFFECT_SCALE: float = 0.3

## Maximum effect scale (prevents overwhelming effects).
const MAX_EFFECT_SCALE: float = 2.0


func _ready() -> void:
	_preload_effect_scenes()


## Preloads all particle effect scenes for efficient instantiation.
func _preload_effect_scenes() -> void:
	# Load effect scenes if they exist
	var dust_path := "res://scenes/effects/DustEffect.tscn"
	var blood_path := "res://scenes/effects/BloodEffect.tscn"
	var sparks_path := "res://scenes/effects/SparksEffect.tscn"

	if ResourceLoader.exists(dust_path):
		_dust_effect_scene = load(dust_path)
	else:
		push_warning("ImpactEffectsManager: DustEffect scene not found at " + dust_path)

	if ResourceLoader.exists(blood_path):
		_blood_effect_scene = load(blood_path)
	else:
		push_warning("ImpactEffectsManager: BloodEffect scene not found at " + blood_path)

	if ResourceLoader.exists(sparks_path):
		_sparks_effect_scene = load(sparks_path)
	else:
		push_warning("ImpactEffectsManager: SparksEffect scene not found at " + sparks_path)


## Spawns a dust effect at the given position when a bullet hits a wall.
## @param position: World position where the bullet hit the wall.
## @param surface_normal: Normal vector of the surface (particles scatter away from it).
## @param caliber_data: Optional caliber data for effect scaling.
func spawn_dust_effect(position: Vector2, surface_normal: Vector2, caliber_data: Resource = null) -> void:
	if _dust_effect_scene == null:
		return

	var effect := _dust_effect_scene.instantiate() as GPUParticles2D
	if effect == null:
		return

	effect.global_position = position

	# Rotate effect to face away from surface (in the direction of the normal)
	effect.rotation = surface_normal.angle()

	# Scale effect based on caliber
	var scale := _get_effect_scale(caliber_data)
	effect.amount_ratio = scale
	effect.scale = Vector2(scale, scale)

	# Add to scene tree
	_add_effect_to_scene(effect)

	# Start emitting
	effect.emitting = true


## Spawns a blood splatter effect at the given position for lethal hits.
## @param position: World position where the lethal hit occurred.
## @param hit_direction: Direction the bullet was traveling (blood splatters opposite).
## @param caliber_data: Optional caliber data for effect scaling.
func spawn_blood_effect(position: Vector2, hit_direction: Vector2, caliber_data: Resource = null) -> void:
	if _blood_effect_scene == null:
		return

	var effect := _blood_effect_scene.instantiate() as GPUParticles2D
	if effect == null:
		return

	effect.global_position = position

	# Blood splatters in the direction the bullet was traveling
	effect.rotation = hit_direction.angle()

	# Scale effect based on caliber (larger calibers = more blood)
	var scale := _get_effect_scale(caliber_data)
	effect.amount_ratio = scale
	effect.scale = Vector2(scale, scale)

	# Add to scene tree
	_add_effect_to_scene(effect)

	# Start emitting
	effect.emitting = true


## Spawns a spark effect at the given position for non-lethal (armor) hits.
## @param position: World position where the non-lethal hit occurred.
## @param hit_direction: Direction the bullet was traveling.
## @param caliber_data: Optional caliber data for effect scaling.
func spawn_sparks_effect(position: Vector2, hit_direction: Vector2, caliber_data: Resource = null) -> void:
	if _sparks_effect_scene == null:
		return

	var effect := _sparks_effect_scene.instantiate() as GPUParticles2D
	if effect == null:
		return

	effect.global_position = position

	# Sparks scatter in direction opposite to bullet travel (reflection)
	effect.rotation = (-hit_direction).angle()

	# Scale effect based on caliber
	var scale := _get_effect_scale(caliber_data)
	# Sparks are generally smaller, so reduce scale slightly
	scale *= 0.7
	effect.amount_ratio = scale
	effect.scale = Vector2(scale, scale)

	# Add to scene tree
	_add_effect_to_scene(effect)

	# Start emitting
	effect.emitting = true


## Gets the effect scale from caliber data, or returns default if not available.
## @param caliber_data: Caliber resource that may contain effect_scale property.
## @return: Effect scale factor clamped between MIN and MAX values.
func _get_effect_scale(caliber_data: Resource) -> float:
	var scale := DEFAULT_EFFECT_SCALE

	if caliber_data and "effect_scale" in caliber_data:
		scale = caliber_data.effect_scale

	return clampf(scale, MIN_EFFECT_SCALE, MAX_EFFECT_SCALE)


## Adds an effect node to the current scene tree.
## Effect will be added as a child of the current scene.
func _add_effect_to_scene(effect: Node2D) -> void:
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(effect)
	else:
		# Fallback: add to self (autoload node)
		add_child(effect)
