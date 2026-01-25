extends GutTest
## Unit tests for visual effect scripts.
##
## Tests blood decal, bullet hole, casing, effect cleanup, and penetration hole.


# ============================================================================
# Mock Blood Decal for Testing
# ============================================================================


class MockBloodDecal:
	## Time in seconds before the decal starts fading.
	var fade_delay: float = 30.0

	## Time in seconds for the fade-out animation.
	var fade_duration: float = 5.0

	## Whether the decal should fade out over time.
	var auto_fade: bool = false

	## Initial alpha value.
	var _initial_alpha: float = 0.85

	## Modulate color (simulates Sprite2D).
	var modulate: Color = Color(1.0, 1.0, 1.0, 0.85)

	## Whether removed.
	var _removed: bool = false

	## Whether fade started.
	var _fade_started: bool = false

	func _ready() -> void:
		_initial_alpha = modulate.a
		if auto_fade:
			_fade_started = true

	func remove() -> void:
		_removed = true

	func fade_out_quick() -> void:
		_fade_started = true
		modulate.a = 0.0
		_removed = true


# ============================================================================
# Mock Effect Cleanup for Testing
# ============================================================================


class MockEffectCleanup:
	## Extra time after lifetime before cleanup.
	var cleanup_delay: float = 0.5

	## Lifetime of particles (from GPUParticles2D).
	var lifetime: float = 1.0

	## Whether freed.
	var _freed: bool = false

	## Total wait time before cleanup.
	func get_total_wait_time() -> float:
		return lifetime + cleanup_delay


# ============================================================================
# Mock Bullet Hole for Testing
# ============================================================================


class MockBulletHole:
	## Fade delay before bullet hole starts disappearing.
	var fade_delay: float = 60.0

	## Fade duration.
	var fade_duration: float = 10.0

	## Whether the hole should auto-fade.
	var auto_fade: bool = true

	## Modulate for fading.
	var modulate: Color = Color(1.0, 1.0, 1.0, 1.0)


# ============================================================================
# Mock Casing for Testing
# ============================================================================


class MockCasing:
	## Initial velocity of the casing.
	var initial_velocity: Vector2 = Vector2.ZERO

	## Gravity affecting the casing.
	var gravity: float = 980.0

	## Rotation speed.
	var rotation_speed: float = 10.0

	## Bounce factor when hitting ground.
	var bounce_factor: float = 0.3

	## Current velocity.
	var velocity: Vector2 = Vector2.ZERO

	## Position.
	var position: Vector2 = Vector2.ZERO

	## Rotation.
	var rotation: float = 0.0

	## Whether casing is resting.
	var _is_resting: bool = false

	## Ground level Y position.
	var _ground_y: float = 100.0

	func apply_gravity(delta: float) -> void:
		velocity.y += gravity * delta

	func apply_rotation(delta: float) -> void:
		rotation += rotation_speed * delta

	func update_position(delta: float) -> void:
		position += velocity * delta

	func check_ground() -> void:
		if position.y >= _ground_y:
			position.y = _ground_y
			velocity.y = -velocity.y * bounce_factor
			if abs(velocity.y) < 10.0:
				_is_resting = true
				velocity = Vector2.ZERO


# ============================================================================
# Mock Penetration Hole for Testing
# ============================================================================


class MockPenetrationHole:
	## Fade settings.
	var fade_delay: float = 45.0
	var fade_duration: float = 15.0
	var auto_fade: bool = true

	## Size of the hole based on caliber.
	var hole_size: float = 1.0

	## Normal direction the hole faces.
	var normal: Vector2 = Vector2.ZERO

	## Modulate for fading.
	var modulate: Color = Color(1.0, 1.0, 1.0, 1.0)


var blood_decal: MockBloodDecal
var effect_cleanup: MockEffectCleanup
var bullet_hole: MockBulletHole
var casing: MockCasing
var penetration_hole: MockPenetrationHole


func before_each() -> void:
	blood_decal = MockBloodDecal.new()
	effect_cleanup = MockEffectCleanup.new()
	bullet_hole = MockBulletHole.new()
	casing = MockCasing.new()
	penetration_hole = MockPenetrationHole.new()


func after_each() -> void:
	blood_decal = null
	effect_cleanup = null
	bullet_hole = null
	casing = null
	penetration_hole = null


# ============================================================================
# Blood Decal Tests
# ============================================================================


func test_blood_decal_default_fade_delay() -> void:
	assert_eq(blood_decal.fade_delay, 30.0,
		"Default fade delay should be 30 seconds")


func test_blood_decal_default_fade_duration() -> void:
	assert_eq(blood_decal.fade_duration, 5.0,
		"Default fade duration should be 5 seconds")


func test_blood_decal_auto_fade_disabled() -> void:
	assert_false(blood_decal.auto_fade,
		"Auto fade should be disabled by default")


func test_blood_decal_initial_alpha() -> void:
	assert_eq(blood_decal._initial_alpha, 0.85,
		"Initial alpha should be 0.85")


func test_blood_decal_remove() -> void:
	blood_decal.remove()

	assert_true(blood_decal._removed,
		"Remove should mark decal as removed")


func test_blood_decal_fade_out_quick() -> void:
	blood_decal.fade_out_quick()

	assert_eq(blood_decal.modulate.a, 0.0,
		"Quick fade should set alpha to 0")
	assert_true(blood_decal._removed,
		"Quick fade should remove decal")


func test_blood_decal_ready_stores_alpha() -> void:
	blood_decal.modulate.a = 0.5
	blood_decal._ready()

	assert_eq(blood_decal._initial_alpha, 0.5,
		"Ready should store initial alpha")


func test_blood_decal_ready_starts_fade_if_auto() -> void:
	blood_decal.auto_fade = true
	blood_decal._ready()

	assert_true(blood_decal._fade_started,
		"Ready should start fade if auto_fade enabled")


# ============================================================================
# Effect Cleanup Tests
# ============================================================================


func test_effect_cleanup_default_delay() -> void:
	assert_eq(effect_cleanup.cleanup_delay, 0.5,
		"Default cleanup delay should be 0.5 seconds")


func test_effect_cleanup_default_lifetime() -> void:
	assert_eq(effect_cleanup.lifetime, 1.0,
		"Default lifetime should be 1.0 seconds")


func test_effect_cleanup_total_wait_time() -> void:
	assert_eq(effect_cleanup.get_total_wait_time(), 1.5,
		"Total wait should be lifetime + cleanup_delay")


func test_effect_cleanup_custom_values() -> void:
	effect_cleanup.cleanup_delay = 1.0
	effect_cleanup.lifetime = 2.0

	assert_eq(effect_cleanup.get_total_wait_time(), 3.0,
		"Custom values should affect total wait")


func test_effect_cleanup_zero_delay() -> void:
	effect_cleanup.cleanup_delay = 0.0

	assert_eq(effect_cleanup.get_total_wait_time(), 1.0,
		"Zero delay should work")


# ============================================================================
# Bullet Hole Tests
# ============================================================================


func test_bullet_hole_default_fade_delay() -> void:
	assert_eq(bullet_hole.fade_delay, 60.0,
		"Default fade delay should be 60 seconds")


func test_bullet_hole_default_fade_duration() -> void:
	assert_eq(bullet_hole.fade_duration, 10.0,
		"Default fade duration should be 10 seconds")


func test_bullet_hole_auto_fade_enabled() -> void:
	assert_true(bullet_hole.auto_fade,
		"Auto fade should be enabled by default")


func test_bullet_hole_initial_modulate() -> void:
	assert_eq(bullet_hole.modulate.a, 1.0,
		"Initial alpha should be 1.0")


func test_bullet_hole_longer_than_blood() -> void:
	assert_true(bullet_hole.fade_delay > blood_decal.fade_delay,
		"Bullet holes should persist longer than blood decals")


# ============================================================================
# Casing Tests
# ============================================================================


func test_casing_default_gravity() -> void:
	assert_eq(casing.gravity, 980.0,
		"Default gravity should be ~9.8m/s² (980 pixels)")


func test_casing_default_rotation_speed() -> void:
	assert_eq(casing.rotation_speed, 10.0,
		"Default rotation speed should be 10 rad/s")


func test_casing_default_bounce_factor() -> void:
	assert_eq(casing.bounce_factor, 0.3,
		"Default bounce factor should be 0.3")


func test_casing_apply_gravity() -> void:
	casing.velocity = Vector2.ZERO
	casing.apply_gravity(1.0)

	assert_eq(casing.velocity.y, 980.0,
		"Gravity should increase Y velocity")


func test_casing_apply_gravity_accumulates() -> void:
	casing.velocity = Vector2.ZERO
	casing.apply_gravity(0.5)
	casing.apply_gravity(0.5)

	assert_eq(casing.velocity.y, 980.0,
		"Gravity should accumulate over time")


func test_casing_apply_rotation() -> void:
	casing.rotation = 0.0
	casing.apply_rotation(1.0)

	assert_eq(casing.rotation, 10.0,
		"Rotation should increase by rotation_speed * delta")


func test_casing_update_position() -> void:
	casing.position = Vector2(0, 0)
	casing.velocity = Vector2(100, 50)
	casing.update_position(1.0)

	assert_eq(casing.position, Vector2(100, 50),
		"Position should update by velocity * delta")


func test_casing_check_ground_bounce() -> void:
	casing.position = Vector2(0, 110)  # Below ground
	casing.velocity = Vector2(50, 100)
	casing._ground_y = 100.0

	casing.check_ground()

	assert_eq(casing.position.y, 100.0,
		"Position should be clamped to ground")
	assert_almost_eq(casing.velocity.y, -30.0, 0.1,
		"Velocity should bounce with factor")


func test_casing_stops_when_slow() -> void:
	casing.position = Vector2(0, 100)
	casing.velocity = Vector2(0, 5)  # Very slow
	casing._ground_y = 100.0

	casing.check_ground()

	assert_true(casing._is_resting,
		"Casing should rest when velocity is very low")
	assert_eq(casing.velocity, Vector2.ZERO,
		"Velocity should be zero when resting")


func test_casing_full_physics_simulation() -> void:
	casing.position = Vector2(0, 0)
	casing.velocity = Vector2(200, -100)  # Ejected up and right
	casing._ground_y = 100.0

	# Simulate 0.5 seconds at 60fps
	for i in range(30):
		casing.apply_gravity(1.0/60.0)
		casing.apply_rotation(1.0/60.0)
		casing.update_position(1.0/60.0)
		casing.check_ground()

	assert_true(casing.position.x > 0,
		"Casing should move right")
	assert_true(casing.rotation > 0,
		"Casing should rotate")


# ============================================================================
# Penetration Hole Tests
# ============================================================================


func test_penetration_hole_default_fade_delay() -> void:
	assert_eq(penetration_hole.fade_delay, 45.0,
		"Default fade delay should be 45 seconds")


func test_penetration_hole_default_fade_duration() -> void:
	assert_eq(penetration_hole.fade_duration, 15.0,
		"Default fade duration should be 15 seconds")


func test_penetration_hole_auto_fade() -> void:
	assert_true(penetration_hole.auto_fade,
		"Auto fade should be enabled by default")


func test_penetration_hole_default_size() -> void:
	assert_eq(penetration_hole.hole_size, 1.0,
		"Default hole size should be 1.0")


func test_penetration_hole_default_normal() -> void:
	assert_eq(penetration_hole.normal, Vector2.ZERO,
		"Default normal should be zero")


func test_penetration_hole_custom_size() -> void:
	penetration_hole.hole_size = 2.0

	assert_eq(penetration_hole.hole_size, 2.0,
		"Custom hole size should work")


func test_penetration_hole_set_normal() -> void:
	penetration_hole.normal = Vector2.RIGHT

	assert_eq(penetration_hole.normal, Vector2.RIGHT,
		"Normal should be settable")


# ============================================================================
# Cross-Effect Comparison Tests
# ============================================================================


func test_fade_delay_ordering() -> void:
	# Blood decals fade first, then penetration holes, then bullet holes
	assert_true(blood_decal.fade_delay < penetration_hole.fade_delay,
		"Blood should fade before penetration holes")
	assert_true(penetration_hole.fade_delay < bullet_hole.fade_delay,
		"Penetration holes should fade before bullet holes")


func test_fade_duration_ordering() -> void:
	# Blood fades fastest, bullet holes slowest
	assert_true(blood_decal.fade_duration < bullet_hole.fade_duration,
		"Blood should fade faster than bullet holes")


func test_all_effects_have_fade_properties() -> void:
	# All effects should have consistent fade configuration
	assert_true("fade_delay" in blood_decal,
		"Blood decal should have fade_delay")
	assert_true("fade_duration" in blood_decal,
		"Blood decal should have fade_duration")
	assert_true("fade_delay" in bullet_hole,
		"Bullet hole should have fade_delay")
	assert_true("fade_duration" in bullet_hole,
		"Bullet hole should have fade_duration")
	assert_true("fade_delay" in penetration_hole,
		"Penetration hole should have fade_delay")
	assert_true("fade_duration" in penetration_hole,
		"Penetration hole should have fade_duration")


# ============================================================================
# Edge Case Tests
# ============================================================================


func test_zero_fade_values() -> void:
	blood_decal.fade_delay = 0.0
	blood_decal.fade_duration = 0.0

	assert_eq(blood_decal.fade_delay, 0.0,
		"Zero fade delay should be valid")
	assert_eq(blood_decal.fade_duration, 0.0,
		"Zero fade duration should be valid")


func test_very_long_fade() -> void:
	bullet_hole.fade_delay = 3600.0  # 1 hour
	bullet_hole.fade_duration = 60.0  # 1 minute

	assert_eq(bullet_hole.fade_delay, 3600.0,
		"Very long fade delay should be valid")


func test_casing_negative_velocity() -> void:
	casing.velocity = Vector2(-100, -200)
	casing.update_position(1.0)

	assert_eq(casing.position, Vector2(-100, -200),
		"Negative velocity should work")


func test_casing_zero_bounce() -> void:
	casing.bounce_factor = 0.0
	casing.position = Vector2(0, 110)
	casing.velocity = Vector2(0, 100)
	casing._ground_y = 100.0

	casing.check_ground()

	assert_eq(casing.velocity.y, 0.0,
		"Zero bounce should stop immediately")
