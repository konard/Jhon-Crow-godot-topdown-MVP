extends Area2D
## Permanent penetration hole that creates a gap in wall collision.
##
## This creates an actual hole in the wall that allows:
## - Bullets to pass through without triggering new penetration
## - Vision/raycasts to pass through
## - Enemies to see and shoot through
##
## The hole is permanent and does not fade over time.
## Similar to Red Faction Guerrilla or Teardown destruction (without physics).

## Collision layers this hole affects (default: obstacles layer 3)
const OBSTACLE_LAYER: int = 4  # Layer 3 in Godot is value 4 (2^2)

## The collision shape of this hole.
var _collision_shape: CollisionShape2D = null

## Direction the bullet was traveling (for trail orientation).
var bullet_direction: Vector2 = Vector2.RIGHT

## Width of the bullet trail (based on caliber).
var trail_width: float = 4.0

## Length of the trail (based on penetration distance traveled).
var trail_length: float = 8.0


func _ready() -> void:
	# Configure area to be a hole that disables wall collision for bullets
	# Bullets should pass through this area without hitting walls
	collision_layer = 0  # Don't collide with anything
	collision_mask = OBSTACLE_LAYER  # Detect obstacles to create hole effect

	# Monitoring must be true for bullets to detect this area
	monitoring = true
	monitorable = true

	_create_collision_shape()
	_create_visual()


## Creates the collision shape for the hole.
func _create_collision_shape() -> void:
	_collision_shape = CollisionShape2D.new()

	# Create a rectangle shape for the bullet trail
	var rect_shape := RectangleShape2D.new()
	# Width is the bullet diameter, length is the penetration distance
	rect_shape.size = Vector2(trail_length, trail_width)

	_collision_shape.shape = rect_shape
	add_child(_collision_shape)

	# Rotate to match bullet direction
	rotation = bullet_direction.angle()


## Creates a simple visual representation of the hole.
func _create_visual() -> void:
	# Create a dark line/rectangle to show the bullet path through the wall
	var line := Line2D.new()
	line.width = trail_width
	line.default_color = Color(0.02, 0.02, 0.02, 0.95)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

	# Line goes from entry to exit (local coordinates)
	line.add_point(Vector2(-trail_length / 2.0, 0))
	line.add_point(Vector2(trail_length / 2.0, 0))

	# Don't rotate line since parent is already rotated
	line.rotation = -rotation  # Counter-rotate to stay horizontal in local space

	add_child(line)


## Configures the hole with bullet information.
## @param direction: Direction the bullet was traveling.
## @param width: Width of the hole (based on caliber).
## @param length: Length of the hole (penetration distance).
func configure(direction: Vector2, width: float, length: float) -> void:
	bullet_direction = direction.normalized()
	trail_width = maxf(width, 2.0)  # Minimum width of 2 pixels
	trail_length = maxf(length, 4.0)  # Minimum length of 4 pixels

	# Update shape if already created
	if _collision_shape and _collision_shape.shape:
		var rect := _collision_shape.shape as RectangleShape2D
		if rect:
			rect.size = Vector2(trail_length, trail_width)

	rotation = bullet_direction.angle()


## Sets the position to the center of the bullet path.
## @param entry_point: Where the bullet entered the wall.
## @param exit_point: Where the bullet exited the wall.
func set_from_entry_exit(entry_point: Vector2, exit_point: Vector2) -> void:
	# Position at center of entry and exit
	global_position = (entry_point + exit_point) / 2.0

	# Calculate direction and length
	var path := exit_point - entry_point
	trail_length = path.length()
	bullet_direction = path.normalized() if trail_length > 0 else Vector2.RIGHT

	configure(bullet_direction, trail_width, trail_length)
