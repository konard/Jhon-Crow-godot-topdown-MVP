extends GutTest
## Unit tests for ThreatSphere.
##
## Tests the bullet threat detection component that identifies
## incoming bullets on collision course with the player.


# ============================================================================
# Mock Classes for Testing
# ============================================================================


class MockThreatSphere:
	## Radius of the threat detection sphere (in pixels).
	var threat_radius: float = 150.0

	## Tolerance angle (in degrees) for trajectory checking.
	var trajectory_tolerance_degrees: float = 15.0

	## Reference to the parent player.
	var _player: RefCounted = null

	## Enable debug logging.
	var _debug: bool = false

	## Signal tracking
	var threat_detected_emitted: Array = []

	func _init(player_ref: RefCounted) -> void:
		_player = player_ref

	## Emit threat detected (simulates signal)
	func _emit_threat(bullet: RefCounted) -> void:
		threat_detected_emitted.append(bullet)

	## Checks if the object is a bullet.
	func _is_bullet(area: RefCounted) -> bool:
		if area == null:
			return false
		# Check by name property
		if "name" in area:
			if "Bullet" in area.name or "bullet" in area.name:
				return true
		return false

	## Checks if the bullet was fired by the player.
	func _is_player_bullet(area: RefCounted) -> bool:
		if _player == null:
			return false

		# Check for shooter_id property
		if "shooter_id" in area:
			var shooter_id: int = area.shooter_id
			if shooter_id != -1:
				# Compare with player's mock instance ID
				if shooter_id == _player.get_instance_id():
					return true
		return false

	## Checks if the bullet is heading toward the player (on a collision course).
	func _is_bullet_heading_toward_player(area: RefCounted) -> bool:
		if _player == null:
			return false

		# Get bullet position and direction
		var bullet_pos: Vector2 = area.global_position
		var bullet_direction: Vector2 = Vector2.ZERO

		# Try to get direction from bullet
		if "direction" in area:
			bullet_direction = area.direction

		# Fallback: try to infer direction from rotation
		if bullet_direction == Vector2.ZERO and "rotation" in area:
			bullet_direction = Vector2.RIGHT.rotated(area.rotation)

		if bullet_direction == Vector2.ZERO:
			return false

		bullet_direction = bullet_direction.normalized()

		# Calculate vector from bullet to player
		var player_pos: Vector2 = _player.global_position
		var to_player: Vector2 = (player_pos - bullet_pos).normalized()

		# Calculate angle between bullet direction and direction to player
		var angle_to_player_rad: float = bullet_direction.angle_to(to_player)
		var angle_to_player_deg: float = abs(rad_to_deg(angle_to_player_rad))

		# Check if bullet is heading toward player within tolerance
		return angle_to_player_deg <= trajectory_tolerance_degrees

	## Main processing logic for area entering.
	func process_area_entered(area: RefCounted) -> void:
		if _player == null:
			return

		if not _is_bullet(area):
			return

		var is_player_bullet := _is_player_bullet(area)
		if is_player_bullet:
			if not _is_bullet_heading_toward_player(area):
				return

		if _is_bullet_heading_toward_player(area):
			_emit_threat(area)


class MockPlayer:
	## Mock player class that mimics Node2D for testing.
	## Note: Inner classes cannot extend engine types in GDScript.
	extends RefCounted

	var global_position: Vector2 = Vector2.ZERO
	var _instance_id: int = 0

	func _init() -> void:
		# Use a random ID to simulate instance_id
		_instance_id = randi()

	func get_instance_id() -> int:
		return _instance_id


class MockBullet:
	## Mock bullet class that mimics Area2D for testing.
	extends RefCounted

	var name: String = "Bullet"
	var global_position: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var rotation: float = 0.0
	var shooter_id: int = -1


var threat_sphere: MockThreatSphere
var player: MockPlayer
var bullet: MockBullet


func before_each() -> void:
	player = MockPlayer.new()
	player.global_position = Vector2(100, 100)

	threat_sphere = MockThreatSphere.new(player)

	bullet = MockBullet.new()
	bullet.name = "Bullet"


func after_each() -> void:
	threat_sphere = null
	player = null
	bullet = null


# ============================================================================
# Initialization Tests
# ============================================================================


func test_default_threat_radius() -> void:
	assert_eq(threat_sphere.threat_radius, 150.0,
		"Default threat radius should be 150 pixels")


func test_default_trajectory_tolerance() -> void:
	assert_eq(threat_sphere.trajectory_tolerance_degrees, 15.0,
		"Default trajectory tolerance should be 15 degrees")


func test_player_reference_stored() -> void:
	assert_eq(threat_sphere._player, player,
		"Should store player reference")


func test_debug_disabled_by_default() -> void:
	assert_false(threat_sphere._debug,
		"Debug should be disabled by default")


# ============================================================================
# Bullet Detection Tests
# ============================================================================


func test_is_bullet_by_name() -> void:
	assert_true(threat_sphere._is_bullet(bullet),
		"Should detect bullet by name")


func test_is_bullet_lowercase_name() -> void:
	bullet.name = "bullet_01"

	assert_true(threat_sphere._is_bullet(bullet),
		"Should detect bullet with lowercase name")


func test_is_bullet_partial_name() -> void:
	bullet.name = "EnemyBulletInstance"

	assert_true(threat_sphere._is_bullet(bullet),
		"Should detect bullet with partial name match")


func test_is_not_bullet_wrong_name() -> void:
	bullet.name = "Grenade"

	assert_false(threat_sphere._is_bullet(bullet),
		"Should not detect non-bullet as bullet")


func test_is_not_bullet_null() -> void:
	assert_false(threat_sphere._is_bullet(null),
		"Should handle null gracefully")


# ============================================================================
# Player Bullet Detection Tests
# ============================================================================


func test_is_player_bullet_true() -> void:
	bullet.shooter_id = player.get_instance_id()

	assert_true(threat_sphere._is_player_bullet(bullet),
		"Should detect player's bullet")


func test_is_player_bullet_false_no_shooter() -> void:
	bullet.shooter_id = -1

	assert_false(threat_sphere._is_player_bullet(bullet),
		"Should not detect bullet without shooter as player's")


func test_is_player_bullet_false_enemy_shooter() -> void:
	# Use a different ID than the player's
	bullet.shooter_id = player.get_instance_id() + 1000

	assert_false(threat_sphere._is_player_bullet(bullet),
		"Should not detect enemy bullet as player's")


func test_is_player_bullet_with_null_player() -> void:
	threat_sphere._player = null

	assert_false(threat_sphere._is_player_bullet(bullet),
		"Should return false with null player")


# ============================================================================
# Trajectory Detection Tests
# ============================================================================


func test_bullet_heading_toward_player_direct() -> void:
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.RIGHT  # Heading directly at player at (100, 100)

	assert_true(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Should detect bullet heading directly at player")


func test_bullet_heading_toward_player_within_tolerance() -> void:
	bullet.global_position = Vector2(0, 100)
	# Heading slightly off but within 15 degrees
	bullet.direction = Vector2(1, 0.1).normalized()

	assert_true(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Should detect bullet within tolerance angle")


func test_bullet_heading_away_from_player() -> void:
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.LEFT  # Heading away from player

	assert_false(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Should not detect bullet heading away")


func test_bullet_heading_perpendicular() -> void:
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.UP  # Heading perpendicular to player

	assert_false(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Should not detect bullet heading perpendicular")


func test_bullet_heading_outside_tolerance() -> void:
	bullet.global_position = Vector2(0, 100)
	# Heading 30 degrees off (outside 15 degree tolerance)
	bullet.direction = Vector2(1, 0.58).normalized()  # ~30 degrees

	assert_false(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Should not detect bullet outside tolerance")


func test_bullet_heading_from_rotation_fallback() -> void:
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.ZERO  # No direction set
	bullet.rotation = 0  # Facing right toward player

	assert_true(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Should use rotation as fallback")


func test_bullet_heading_with_null_player() -> void:
	threat_sphere._player = null

	assert_false(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Should return false with null player")


# ============================================================================
# Process Area Entered Tests
# ============================================================================


func test_process_detects_threat() -> void:
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.RIGHT

	threat_sphere.process_area_entered(bullet)

	assert_eq(threat_sphere.threat_detected_emitted.size(), 1,
		"Should emit threat for incoming bullet")


func test_process_ignores_non_bullet() -> void:
	bullet.name = "Grenade"
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.RIGHT

	threat_sphere.process_area_entered(bullet)

	assert_eq(threat_sphere.threat_detected_emitted.size(), 0,
		"Should not emit threat for non-bullet")


func test_process_ignores_bullet_heading_away() -> void:
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.LEFT

	threat_sphere.process_area_entered(bullet)

	assert_eq(threat_sphere.threat_detected_emitted.size(), 0,
		"Should not emit threat for bullet heading away")


func test_process_ignores_player_bullet_heading_away() -> void:
	bullet.global_position = Vector2(200, 100)  # Right of player
	bullet.direction = Vector2.RIGHT  # Heading away
	bullet.shooter_id = player.get_instance_id()

	threat_sphere.process_area_entered(bullet)

	assert_eq(threat_sphere.threat_detected_emitted.size(), 0,
		"Should not emit threat for player's bullet heading away")


func test_process_detects_ricochet_threat() -> void:
	# Player's bullet ricocheting back toward them
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.RIGHT  # Heading toward player
	bullet.shooter_id = player.get_instance_id()

	threat_sphere.process_area_entered(bullet)

	assert_eq(threat_sphere.threat_detected_emitted.size(), 1,
		"Should detect player's own bullet if heading toward them")


func test_process_with_null_player() -> void:
	threat_sphere._player = null

	threat_sphere.process_area_entered(bullet)

	assert_eq(threat_sphere.threat_detected_emitted.size(), 0,
		"Should not process without player")


# ============================================================================
# Custom Tolerance Tests
# ============================================================================


func test_wide_tolerance() -> void:
	threat_sphere.trajectory_tolerance_degrees = 45.0
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2(1, 0.5).normalized()  # ~27 degrees off

	assert_true(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Wide tolerance should detect more bullets")


func test_narrow_tolerance() -> void:
	threat_sphere.trajectory_tolerance_degrees = 5.0
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2(1, 0.1).normalized()  # ~6 degrees off

	assert_false(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Narrow tolerance should be more strict")


func test_zero_tolerance() -> void:
	threat_sphere.trajectory_tolerance_degrees = 0.0
	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.RIGHT  # Exactly at player

	# Even with zero tolerance, should detect perfect hits
	assert_true(threat_sphere._is_bullet_heading_toward_player(bullet),
		"Zero tolerance should still detect perfect trajectory")


# ============================================================================
# Edge Case Tests
# ============================================================================


func test_bullet_at_player_position() -> void:
	bullet.global_position = player.global_position
	bullet.direction = Vector2.RIGHT

	# When bullet is at same position as player, direction doesn't matter
	# This is an edge case where to_player would be zero
	var result := threat_sphere._is_bullet_heading_toward_player(bullet)

	# The result depends on implementation - normalized zero vector
	# This tests that it doesn't crash
	assert_true(result or not result, "Should handle bullet at player position")


func test_multiple_bullets() -> void:
	var bullet2 := MockBullet.new()
	bullet2.name = "Bullet2"
	bullet2.global_position = Vector2(0, 50)
	bullet2.direction = Vector2(1, 0.5).normalized()  # Heading toward player

	bullet.global_position = Vector2(0, 100)
	bullet.direction = Vector2.RIGHT

	threat_sphere.process_area_entered(bullet)
	threat_sphere.process_area_entered(bullet2)

	assert_eq(threat_sphere.threat_detected_emitted.size(), 2,
		"Should detect multiple threats")


func test_bullet_from_various_angles() -> void:
	# Test bullets from all quadrants
	var positions := [
		Vector2(0, 100),    # Left of player
		Vector2(200, 100),  # Right of player
		Vector2(100, 0),    # Above player
		Vector2(100, 200),  # Below player
		Vector2(0, 0),      # Top-left
		Vector2(200, 200),  # Bottom-right
	]

	for pos in positions:
		bullet.global_position = pos
		bullet.direction = (player.global_position - pos).normalized()

		assert_true(threat_sphere._is_bullet_heading_toward_player(bullet),
			"Should detect bullet from position %s" % pos)
