extends RigidBody2D
## Bullet casing that gets ejected from weapons and falls to the ground.
##
## Casings are spawned when weapons fire, ejected in the opposite direction
## of the shot with some randomness. They fall to the ground and remain there
## permanently as persistent environmental detail.

## Lifetime in seconds before auto-destruction (0 = infinite).
@export var lifetime: float = 0.0

## Whether the casing has landed on the ground.
var _has_landed: bool = false

## Timer for lifetime management.
var _lifetime_timer: float = 0.0

## Timer for automatic landing (since no floor in top-down game).
var _auto_land_timer: float = 0.0

## Time before casing automatically "lands" and stops moving.
const AUTO_LAND_TIME: float = 2.0


func _ready() -> void:
	# Connect to collision signals to detect landing
	body_entered.connect(_on_body_entered)

	# Set initial rotation to random for variety
	rotation = randf_range(0, 2 * PI)


func _physics_process(delta: float) -> void:
	# Handle lifetime if set
	if lifetime > 0:
		_lifetime_timer += delta
		if _lifetime_timer >= lifetime:
			queue_free()
			return

	# Auto-land after a few seconds if not landed yet
	if not _has_landed:
		_auto_land_timer += delta
		if _auto_land_timer >= AUTO_LAND_TIME:
			_land()

	# Once landed, stop all movement and rotation
	if _has_landed:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		# Disable physics processing to save performance
		set_physics_process(false)


## Makes the casing "land" by stopping all movement.
func _land() -> void:
	_has_landed = true


## Called when the casing collides with something (usually the ground).
func _on_body_entered(body: Node2D) -> void:
	# Only consider landing if we hit a static body (ground/walls)
	if body is StaticBody2D or body is TileMap:
		_land()