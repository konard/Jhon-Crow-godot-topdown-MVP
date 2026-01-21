extends Node2D
## Individual blood particle/droplet that moves with physics and spawns decals.
##
## Used by the blood effects system to create realistic blood that:
## - Travels in the direction of the bullet hit
## - Collides with walls and stops
## - Spawns blood decals/puddles where it lands
##
## This provides more realism than GPU particles alone since it can
## interact with the physics world.

## Blood particle speed range (pixels per second).
@export var min_speed: float = 200.0
@export var max_speed: float = 500.0

## Gravity applied to the particle (pixels per second squared).
@export var gravity: float = 400.0

## How much the particle slows down per second (0-1, 0 = no damping).
@export var damping: float = 0.95

## Maximum lifetime in seconds before auto-destruction.
@export var max_lifetime: float = 2.0

## Collision layer mask for wall detection.
@export_flags_2d_physics var collision_mask: int = 1

## Current velocity of the particle.
var velocity: Vector2 = Vector2.ZERO

## Reference to the visual sprite.
var _sprite: Sprite2D = null

## Time alive tracker.
var _time_alive: float = 0.0

## Has this particle already landed (spawned decal)?
var _has_landed: bool = false

## Enable/disable debug logging.
var _debug: bool = false


func _ready() -> void:
	# Create a simple visual representation (small red circle)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"

	# Create a simple gradient texture for the blood droplet
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.8, 0.1, 0.05, 1.0),  # Dark red center
		Color(0.7, 0.05, 0.02, 0.9),
		Color(0.5, 0.02, 0.02, 0.0)   # Transparent edge
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 8
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)

	_sprite.texture = texture
	add_child(_sprite)

	# Random size variation
	var size_scale := randf_range(0.5, 1.5)
	_sprite.scale = Vector2(size_scale, size_scale)


func _physics_process(delta: float) -> void:
	if _has_landed:
		return

	# Apply gravity
	velocity.y += gravity * delta

	# Apply damping
	velocity *= pow(damping, delta)

	# Calculate movement
	var movement := velocity * delta

	# Check for wall collision before moving
	if _check_wall_collision(movement):
		_on_wall_hit()
		return

	# Move the particle
	global_position += movement

	# Update lifetime
	_time_alive += delta
	if _time_alive >= max_lifetime:
		_on_timeout()


## Checks if movement will collide with a wall.
## @param movement: The movement vector to check.
## @return: True if collision detected, false otherwise.
func _check_wall_collision(movement: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return false

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + movement
	)
	query.collision_mask = collision_mask

	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		# Move to collision point
		global_position = result.position
		return true

	return false


## Called when the particle hits a wall.
func _on_wall_hit() -> void:
	if _has_landed:
		return
	_has_landed = true

	if _debug:
		print("[BloodParticle] Hit wall at ", global_position)

	# Spawn a blood decal at this location
	_spawn_decal()

	# Remove this particle
	queue_free()


## Called when particle times out without hitting anything.
func _on_timeout() -> void:
	if _has_landed:
		return
	_has_landed = true

	if _debug:
		print("[BloodParticle] Timeout at ", global_position)

	# Spawn a smaller decal where it ended (simulating floor landing)
	_spawn_decal(0.5)  # Smaller decal for timeout

	queue_free()


## Spawns a blood decal at the current position.
## @param size_multiplier: Scale multiplier for the decal size.
func _spawn_decal(size_multiplier: float = 1.0) -> void:
	var impact_manager: Node = get_node_or_null("/root/ImpactEffectsManager")
	if impact_manager == null:
		return

	# Use the manager's decal spawning if available
	if impact_manager.has_method("spawn_blood_decal_at"):
		impact_manager.spawn_blood_decal_at(global_position, size_multiplier)
	elif impact_manager.has_method("_spawn_blood_decal"):
		# Fallback to internal method (will use default direction)
		impact_manager._spawn_blood_decal(global_position, velocity.normalized(), size_multiplier)


## Initializes the particle with a direction and intensity.
## @param direction: Direction the blood should travel (normalized).
## @param intensity: Intensity multiplier (affects speed and size).
## @param spread_angle: Random spread angle in radians.
func initialize(direction: Vector2, intensity: float = 1.0, spread_angle: float = 0.5) -> void:
	# Add random spread to the direction
	var angle_deviation := randf_range(-spread_angle, spread_angle)
	var spread_direction := direction.rotated(angle_deviation)

	# Set velocity based on intensity
	var speed := randf_range(min_speed, max_speed) * intensity
	velocity = spread_direction * speed

	# Adjust size based on intensity
	if _sprite:
		var intensity_scale := clampf(intensity, 0.5, 2.0)
		_sprite.scale *= intensity_scale
