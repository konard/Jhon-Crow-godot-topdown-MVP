extends GutTest
## Unit tests for interactive shell casing functionality (Issue #341).
##
## Tests the casing kick detection, physics response, and sound
## playback with configurable thresholds and cooldowns.


# ============================================================================
# Mock Casing for Logic Tests
# ============================================================================


class MockCasing:
	## Lifetime in seconds before auto-destruction (0 = infinite).
	var lifetime: float = 0.0

	## Caliber data for determining casing appearance.
	var caliber_data: Resource = null

	## Whether the casing has landed on the ground.
	var _has_landed: bool = false

	## Timer for lifetime management.
	var _lifetime_timer: float = 0.0

	## Timer for automatic landing.
	var _auto_land_timer: float = 0.0

	## Time before casing automatically "lands".
	const AUTO_LAND_TIME: float = 2.0

	## Stored velocity before time freeze.
	var _frozen_linear_velocity: Vector2 = Vector2.ZERO
	var _frozen_angular_velocity: float = 0.0

	## Whether frozen in time.
	var _is_time_frozen: bool = false

	## Kick force multiplier.
	const KICK_FORCE_MULTIPLIER: float = 0.5

	## Minimum velocity to play kick sound.
	const KICK_SOUND_VELOCITY_THRESHOLD: float = 75.0

	## Cooldown between kick sounds.
	const KICK_SOUND_COOLDOWN: float = 0.1

	## Timer tracking sound cooldown.
	var _kick_sound_timer: float = 0.0

	## Cached caliber type.
	var _cached_caliber_type: String = "rifle"

	## Track current velocities (simulated physics).
	var linear_velocity: Vector2 = Vector2.ZERO
	var angular_velocity: float = 0.0

	## Track global position.
	var global_position: Vector2 = Vector2.ZERO

	## Track if sound was played.
	var sound_played: bool = false
	var sound_type_played: String = ""

	## Track impulses applied.
	var impulses_applied: Array[Vector2] = []

	## Track if queue_free was called.
	var queue_freed: bool = false


	func _ready() -> void:
		_cached_caliber_type = _determine_caliber_type()


	func _physics_process(delta: float) -> void:
		# Update kick sound cooldown timer
		if _kick_sound_timer > 0:
			_kick_sound_timer -= delta

		# If time is frozen, maintain frozen state
		if _is_time_frozen:
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0
			return

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

		# Once landed, stop all movement
		if _has_landed:
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0


	func _land() -> void:
		_has_landed = true


	func apply_central_impulse(impulse: Vector2) -> void:
		impulses_applied.append(impulse)
		# Simulate physics by adding to velocity
		linear_velocity += impulse


	func queue_free() -> void:
		queue_freed = true


	func _on_kick_detector_body_entered(body_velocity: Vector2, body_position: Vector2) -> void:
		# Simulate character body entering
		_apply_kick_simulation(body_velocity, body_position)


	func _apply_kick_simulation(character_velocity: Vector2, character_position: Vector2) -> void:
		# Don't kick if time is frozen
		if _is_time_frozen:
			return

		# Only kick if character is actually moving
		if character_velocity.length_squared() < 100.0:
			return

		# Re-enable movement if landed
		if _has_landed:
			_has_landed = false
			_auto_land_timer = 0.0

		# Calculate kick direction (away from character)
		var kick_direction = (global_position - character_position).normalized()

		# Calculate kick force based on character speed
		var kick_speed = character_velocity.length() * KICK_FORCE_MULTIPLIER

		# Create the kick force vector (without randomness for testing)
		var kick_force = kick_direction * kick_speed

		# Apply the impulse
		apply_central_impulse(kick_force)

		# Play kick sound if above velocity threshold and not in cooldown
		var resulting_velocity = linear_velocity.length()
		if resulting_velocity > KICK_SOUND_VELOCITY_THRESHOLD and _kick_sound_timer <= 0:
			_play_kick_sound()
			_kick_sound_timer = KICK_SOUND_COOLDOWN


	func _play_kick_sound() -> void:
		sound_played = true
		sound_type_played = _cached_caliber_type


	func _determine_caliber_type() -> String:
		if caliber_data == null:
			return "rifle"

		# Simplified check for testing
		var caliber_name = str(caliber_data)
		var name_lower = caliber_name.to_lower()
		if "buckshot" in name_lower or "shotgun" in name_lower:
			return "shotgun"
		elif "9x19" in name_lower or "9mm" in name_lower or "pistol" in name_lower:
			return "pistol"
		else:
			return "rifle"


	func freeze_time() -> void:
		if _is_time_frozen:
			return

		_frozen_linear_velocity = linear_velocity
		_frozen_angular_velocity = angular_velocity

		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0

		_is_time_frozen = true


	func unfreeze_time() -> void:
		if not _is_time_frozen:
			return

		linear_velocity = _frozen_linear_velocity
		angular_velocity = _frozen_angular_velocity

		_is_time_frozen = false
		_frozen_linear_velocity = Vector2.ZERO
		_frozen_angular_velocity = 0.0


var casing: MockCasing


func before_each() -> void:
	casing = MockCasing.new()
	casing._ready()


func after_each() -> void:
	casing = null


# ============================================================================
# Default Configuration Tests
# ============================================================================


func test_casing_default_auto_land_time() -> void:
	assert_eq(casing.AUTO_LAND_TIME, 2.0,
		"Casing should auto-land after 2 seconds")


func test_casing_default_kick_force_multiplier() -> void:
	assert_eq(casing.KICK_FORCE_MULTIPLIER, 0.5,
		"Kick force multiplier should be 0.5 (50%)")


func test_casing_default_sound_velocity_threshold() -> void:
	assert_eq(casing.KICK_SOUND_VELOCITY_THRESHOLD, 75.0,
		"Sound should play at velocities > 75 pixels/sec")


func test_casing_default_sound_cooldown() -> void:
	assert_eq(casing.KICK_SOUND_COOLDOWN, 0.1,
		"Sound cooldown should be 0.1 seconds")


func test_casing_default_caliber_type_is_rifle() -> void:
	assert_eq(casing._cached_caliber_type, "rifle",
		"Default caliber type should be 'rifle'")


func test_casing_starts_not_landed() -> void:
	assert_false(casing._has_landed,
		"Casing should start in flight (not landed)")


func test_casing_starts_not_frozen() -> void:
	assert_false(casing._is_time_frozen,
		"Casing should start unfrozen")


# ============================================================================
# Auto-Landing Tests
# ============================================================================


func test_casing_lands_after_auto_land_time() -> void:
	# Simulate enough time passing
	casing._physics_process(2.5)

	assert_true(casing._has_landed,
		"Casing should land after AUTO_LAND_TIME")


func test_casing_does_not_land_before_auto_land_time() -> void:
	casing._physics_process(1.5)

	assert_false(casing._has_landed,
		"Casing should not land before AUTO_LAND_TIME")


func test_landed_casing_stops_moving() -> void:
	casing.linear_velocity = Vector2(100, 100)
	casing._has_landed = true

	casing._physics_process(0.1)

	assert_eq(casing.linear_velocity, Vector2.ZERO,
		"Landed casing should have zero velocity")


# ============================================================================
# Kick Detection Tests
# ============================================================================


func test_kick_applies_impulse_when_character_moving() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(200, 0)  # Moving right
	var character_position = Vector2(90, 100)  # To the left of casing

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_eq(casing.impulses_applied.size(), 1,
		"One impulse should be applied")


func test_kick_no_impulse_when_character_stationary() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(0, 0)  # Not moving
	var character_position = Vector2(90, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_eq(casing.impulses_applied.size(), 0,
		"No impulse should be applied when character is stationary")


func test_kick_no_impulse_when_character_barely_moving() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(5, 5)  # Moving very slowly (<10 px/s threshold)
	var character_position = Vector2(90, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_eq(casing.impulses_applied.size(), 0,
		"No impulse should be applied when character is barely moving")


func test_kick_direction_away_from_character() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(200, 0)  # Doesn't matter for direction test
	var character_position = Vector2(50, 100)  # Character to the left

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	# Impulse should push casing to the right (positive X)
	assert_gt(casing.impulses_applied[0].x, 0,
		"Kick should push casing away from character (positive X)")


func test_kick_force_proportional_to_character_speed() -> void:
	casing.global_position = Vector2(100, 100)
	var character_position = Vector2(0, 100)  # Character to the left

	# First kick with slower speed
	var slow_velocity = Vector2(100, 0)
	casing._on_kick_detector_body_entered(slow_velocity, character_position)
	var slow_impulse = casing.impulses_applied[0]

	# Reset for second test
	casing.impulses_applied.clear()
	casing.linear_velocity = Vector2.ZERO

	# Second kick with faster speed
	var fast_velocity = Vector2(200, 0)
	casing._on_kick_detector_body_entered(fast_velocity, character_position)
	var fast_impulse = casing.impulses_applied[0]

	assert_gt(fast_impulse.length(), slow_impulse.length(),
		"Faster character should apply stronger kick")


func test_kick_re_enables_landed_casing() -> void:
	casing._has_landed = true
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(200, 0)
	var character_position = Vector2(90, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_false(casing._has_landed,
		"Kicking a landed casing should re-enable movement")


func test_kick_resets_auto_land_timer() -> void:
	casing._has_landed = true
	casing._auto_land_timer = 1.5  # Partially elapsed
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(200, 0)
	var character_position = Vector2(90, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_eq(casing._auto_land_timer, 0.0,
		"Kicking should reset the auto-land timer")


# ============================================================================
# Sound Playback Tests
# ============================================================================


func test_kick_plays_sound_when_velocity_above_threshold() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(300, 0)  # Fast enough to exceed threshold
	var character_position = Vector2(0, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_true(casing.sound_played,
		"Sound should play when velocity exceeds threshold")


func test_kick_no_sound_when_velocity_below_threshold() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(50, 0)  # Not fast enough
	var character_position = Vector2(95, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	# Velocity of casing is 50 * 0.5 = 25, which is below threshold (75)
	assert_false(casing.sound_played,
		"Sound should not play when velocity is below threshold")


func test_kick_sound_cooldown_prevents_rapid_sounds() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(300, 0)
	var character_position = Vector2(0, 100)

	# First kick - should play sound
	casing._on_kick_detector_body_entered(character_velocity, character_position)
	assert_true(casing.sound_played)

	# Reset tracking
	casing.sound_played = false
	casing.impulses_applied.clear()
	casing.linear_velocity = Vector2.ZERO

	# Immediate second kick - should not play sound (cooldown)
	casing._on_kick_detector_body_entered(character_velocity, character_position)
	assert_false(casing.sound_played,
		"Sound should not play during cooldown")


func test_kick_sound_plays_after_cooldown_expires() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(300, 0)
	var character_position = Vector2(0, 100)

	# First kick
	casing._on_kick_detector_body_entered(character_velocity, character_position)

	# Wait for cooldown
	casing._physics_process(0.2)

	# Reset tracking
	casing.sound_played = false
	casing.impulses_applied.clear()
	casing.linear_velocity = Vector2.ZERO

	# Second kick after cooldown
	casing._on_kick_detector_body_entered(character_velocity, character_position)
	assert_true(casing.sound_played,
		"Sound should play after cooldown expires")


func test_default_sound_type_is_rifle() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(300, 0)
	var character_position = Vector2(0, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_eq(casing.sound_type_played, "rifle",
		"Default sound type should be rifle")


# ============================================================================
# Time Freeze Tests
# ============================================================================


func test_kick_no_effect_when_frozen() -> void:
	casing.freeze_time()
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(300, 0)
	var character_position = Vector2(0, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_eq(casing.impulses_applied.size(), 0,
		"Kick should have no effect when frozen")


func test_freeze_time_stores_velocities() -> void:
	casing.linear_velocity = Vector2(50, 30)
	casing.angular_velocity = 5.0

	casing.freeze_time()

	assert_eq(casing._frozen_linear_velocity, Vector2(50, 30),
		"Frozen linear velocity should be stored")
	assert_eq(casing._frozen_angular_velocity, 5.0,
		"Frozen angular velocity should be stored")


func test_freeze_time_stops_movement() -> void:
	casing.linear_velocity = Vector2(50, 30)
	casing.angular_velocity = 5.0

	casing.freeze_time()

	assert_eq(casing.linear_velocity, Vector2.ZERO,
		"Linear velocity should be zero when frozen")
	assert_eq(casing.angular_velocity, 0.0,
		"Angular velocity should be zero when frozen")


func test_unfreeze_time_restores_velocities() -> void:
	casing.linear_velocity = Vector2(50, 30)
	casing.angular_velocity = 5.0

	casing.freeze_time()
	casing.unfreeze_time()

	assert_eq(casing.linear_velocity, Vector2(50, 30),
		"Linear velocity should be restored after unfreeze")
	assert_eq(casing.angular_velocity, 5.0,
		"Angular velocity should be restored after unfreeze")


func test_frozen_casing_maintains_zero_velocity_in_physics_process() -> void:
	casing.linear_velocity = Vector2(50, 30)
	casing.freeze_time()

	# Try to set velocity externally
	casing.linear_velocity = Vector2(100, 100)

	# Physics process should reset it
	casing._physics_process(0.1)

	assert_eq(casing.linear_velocity, Vector2.ZERO,
		"Frozen casing should maintain zero velocity in physics process")


# ============================================================================
# Lifetime Tests
# ============================================================================


func test_casing_destroyed_after_lifetime() -> void:
	casing.lifetime = 1.0

	casing._physics_process(1.5)

	assert_true(casing.queue_freed,
		"Casing should be destroyed after lifetime expires")


func test_casing_not_destroyed_before_lifetime() -> void:
	casing.lifetime = 2.0

	casing._physics_process(1.0)

	assert_false(casing.queue_freed,
		"Casing should not be destroyed before lifetime expires")


func test_infinite_lifetime_with_zero() -> void:
	casing.lifetime = 0.0

	casing._physics_process(100.0)

	assert_false(casing.queue_freed,
		"Casing with lifetime 0 should persist indefinitely")


# ============================================================================
# Edge Case Tests
# ============================================================================


func test_kick_with_very_fast_character() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(1000, 0)  # Very fast
	var character_position = Vector2(0, 100)

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	# Kick force = 1000 * 0.5 = 500
	assert_almost_eq(casing.impulses_applied[0].length(), 500.0, 1.0,
		"Kick force should scale with very fast character")


func test_kick_with_diagonal_movement() -> void:
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(200, 200)  # Diagonal movement
	var character_position = Vector2(50, 50)  # Diagonal position

	casing._on_kick_detector_body_entered(character_velocity, character_position)

	assert_eq(casing.impulses_applied.size(), 1,
		"Diagonal movement should still trigger kick")


func test_multiple_kicks_accumulate() -> void:
	casing.global_position = Vector2(100, 100)
	casing._kick_sound_timer = 0.0  # Reset cooldown for each test

	var character_velocity = Vector2(300, 0)
	var character_position = Vector2(0, 100)

	# First kick
	casing._on_kick_detector_body_entered(character_velocity, character_position)
	var first_velocity = casing.linear_velocity.length()

	# Reset cooldown for sound test purposes
	casing._kick_sound_timer = 0.0

	# Second kick from different direction
	character_position = Vector2(100, 0)  # Now from above
	casing._on_kick_detector_body_entered(character_velocity, character_position)
	var second_velocity = casing.linear_velocity.length()

	assert_eq(casing.impulses_applied.size(), 2,
		"Multiple kicks should apply multiple impulses")


func test_kicked_casing_eventually_lands_again() -> void:
	casing._has_landed = true
	casing.global_position = Vector2(100, 100)
	var character_velocity = Vector2(200, 0)
	var character_position = Vector2(90, 100)

	# Kick the casing
	casing._on_kick_detector_body_entered(character_velocity, character_position)
	assert_false(casing._has_landed)

	# Wait for auto-land
	casing._physics_process(3.0)

	assert_true(casing._has_landed,
		"Kicked casing should eventually land again")
