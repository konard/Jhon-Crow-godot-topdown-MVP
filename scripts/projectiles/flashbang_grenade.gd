extends GrenadeBase
class_name FlashbangGrenade
## Flashbang (stun) grenade that blinds and stuns enemies.
##
## Effects on enemies within the blast radius:
## - Blindness: Enemies cannot see the player for 12 seconds
## - Stun: Enemies cannot move for 6 seconds
##
## Does not deal damage.
## Effect radius is approximately a small room from the "building" map (~200 pixels).

## Duration of blindness effect in seconds.
@export var blindness_duration: float = 12.0

## Duration of stun effect in seconds.
@export var stun_duration: float = 6.0

## Effect radius - doubled per user request.
## Now covers larger areas for better tactical usage.
@export var effect_radius: float = 400.0


func _ready() -> void:
	super._ready()
	# Flashbang uses default 4 second fuse


## Override to define the explosion effect.
func _on_explode() -> void:
	# Find all enemies within effect radius
	var enemies := _get_enemies_in_radius()

	for enemy in enemies:
		_apply_flashbang_effects(enemy)

	# Spawn visual flash effect
	_spawn_flash_effect()


## Get the effect radius for this grenade type.
func _get_effect_radius() -> float:
	return effect_radius


## Find all enemies within the effect radius.
func _get_enemies_in_radius() -> Array:
	var enemies_in_range: Array = []

	# Get all enemies in the scene
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy is Node2D and is_in_effect_radius(enemy.global_position):
			# Check line of sight (flashbang needs to be visible to affect)
			if _has_line_of_sight_to(enemy):
				enemies_in_range.append(enemy)

	return enemies_in_range


## Check if there's line of sight from grenade to target.
func _has_line_of_sight_to(target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		target.global_position
	)
	query.collision_mask = 4  # Only check against obstacles
	query.exclude = [self]

	var result := space_state.intersect_ray(query)

	# If no hit, we have line of sight
	return result.is_empty()


## Apply blindness and stun effects to an enemy.
func _apply_flashbang_effects(enemy: Node2D) -> void:
	# Use the status effects manager if available
	var status_manager: Node = get_node_or_null("/root/StatusEffectsManager")

	if status_manager:
		if status_manager.has_method("apply_blindness"):
			status_manager.apply_blindness(enemy, blindness_duration)
		if status_manager.has_method("apply_stun"):
			status_manager.apply_stun(enemy, stun_duration)
	else:
		# Fallback: apply effects directly to enemy if it supports them
		if enemy.has_method("apply_blindness"):
			enemy.apply_blindness(blindness_duration)
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(stun_duration)


## Spawn visual flash effect at explosion position.
func _spawn_flash_effect() -> void:
	var impact_manager: Node = get_node_or_null("/root/ImpactEffectsManager")

	if impact_manager and impact_manager.has_method("spawn_flashbang_effect"):
		impact_manager.spawn_flashbang_effect(global_position, effect_radius)
	else:
		# Fallback: create simple flash effect
		_create_simple_flash()


## Create a simple flash effect if no manager is available.
func _create_simple_flash() -> void:
	# Create a bright white flash that fades
	var flash := Sprite2D.new()
	flash.texture = _create_white_circle_texture(int(effect_radius))
	flash.global_position = global_position
	flash.modulate = Color(1.0, 1.0, 1.0, 0.8)
	flash.z_index = 100  # Draw on top

	get_tree().current_scene.add_child(flash)

	# Fade out the flash
	var tween := get_tree().create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


## Create a simple white circle texture for the flash effect.
func _create_white_circle_texture(radius: int) -> ImageTexture:
	var size := radius * 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius, radius)

	for x in range(size):
		for y in range(size):
			var pos := Vector2(x, y)
			var distance := pos.distance_to(center)
			if distance <= radius:
				# Fade from center
				var alpha := 1.0 - (distance / radius)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(image)
