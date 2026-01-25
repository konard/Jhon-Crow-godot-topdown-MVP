extends GutTest
## Unit tests for GrenadeTarget.
##
## Tests the training target that tracks grenade hits for player performance.


# ============================================================================
# Mock GrenadeTarget for Testing
# ============================================================================


class MockGrenadeTarget:
	## Whether this is a valid target (should be hit) or not.
	var is_valid_target: bool = true

	## Color configurations.
	var valid_target_color: Color = Color(0.9, 0.2, 0.2, 1.0)
	var invalid_target_color: Color = Color(0.2, 0.9, 0.2, 1.0)
	var hit_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
	var blind_color: Color = Color(1.0, 1.0, 0.5, 1.0)
	var stun_color: Color = Color(0.5, 0.5, 1.0, 1.0)

	## State tracking.
	var _is_blinded: bool = false
	var _is_stunned: bool = false

	## Current modulate color (simulates sprite).
	var current_color: Color = Color.WHITE

	## Signal tracking.
	var grenade_hit_emitted: Array = []
	var status_effect_emitted: Array = []

	func apply_blindness(duration: float) -> void:
		if _is_blinded:
			return

		_is_blinded = true
		status_effect_emitted.append({"type": "blindness", "duration": duration})
		grenade_hit_emitted.append(is_valid_target)

		# Apply visual (flash then blind color)
		current_color = hit_flash_color
		# In real code, this would be followed by blind_color after timer

	func apply_stun(duration: float) -> void:
		if _is_stunned:
			return

		_is_stunned = true
		status_effect_emitted.append({"type": "stun", "duration": duration})
		current_color = stun_color

	func get_visual_state_color() -> Color:
		if _is_stunned:
			return stun_color
		elif _is_blinded:
			return blind_color
		else:
			return valid_target_color if is_valid_target else invalid_target_color

	func reset_effects() -> void:
		_is_blinded = false
		_is_stunned = false
		current_color = get_visual_state_color()


var target: MockGrenadeTarget


func before_each() -> void:
	target = MockGrenadeTarget.new()


func after_each() -> void:
	target = null


# ============================================================================
# Default Property Tests
# ============================================================================


func test_default_is_valid_target() -> void:
	assert_true(target.is_valid_target,
		"Targets should be valid (enemies) by default")


func test_default_valid_target_color() -> void:
	assert_eq(target.valid_target_color, Color(0.9, 0.2, 0.2, 1.0),
		"Valid target color should be red")


func test_default_invalid_target_color() -> void:
	assert_eq(target.invalid_target_color, Color(0.2, 0.9, 0.2, 1.0),
		"Invalid target color should be green")


func test_default_hit_flash_color() -> void:
	assert_eq(target.hit_flash_color, Color(1.0, 1.0, 1.0, 1.0),
		"Hit flash color should be white")


func test_default_blind_color() -> void:
	assert_eq(target.blind_color, Color(1.0, 1.0, 0.5, 1.0),
		"Blind color should have yellow tint")


func test_default_stun_color() -> void:
	assert_eq(target.stun_color, Color(0.5, 0.5, 1.0, 1.0),
		"Stun color should have blue tint")


func test_default_not_blinded() -> void:
	assert_false(target._is_blinded,
		"Target should not be blinded initially")


func test_default_not_stunned() -> void:
	assert_false(target._is_stunned,
		"Target should not be stunned initially")


# ============================================================================
# Apply Blindness Tests
# ============================================================================


func test_apply_blindness_sets_flag() -> void:
	target.apply_blindness(12.0)

	assert_true(target._is_blinded,
		"Blindness should set the blinded flag")


func test_apply_blindness_emits_status_effect() -> void:
	target.apply_blindness(12.0)

	assert_eq(target.status_effect_emitted.size(), 1,
		"Should emit status_effect signal")
	assert_eq(target.status_effect_emitted[0]["type"], "blindness",
		"Effect type should be blindness")
	assert_eq(target.status_effect_emitted[0]["duration"], 12.0,
		"Effect duration should match")


func test_apply_blindness_emits_grenade_hit() -> void:
	target.apply_blindness(12.0)

	assert_eq(target.grenade_hit_emitted.size(), 1,
		"Should emit grenade_hit signal")
	assert_true(target.grenade_hit_emitted[0],
		"Should emit with is_valid_target true")


func test_apply_blindness_invalid_target() -> void:
	target.is_valid_target = false
	target.apply_blindness(12.0)

	assert_false(target.grenade_hit_emitted[0],
		"Should emit with is_valid_target false for invalid target")


func test_apply_blindness_flashes_hit_color() -> void:
	target.apply_blindness(12.0)

	assert_eq(target.current_color, target.hit_flash_color,
		"Should flash hit color when blinded")


func test_apply_blindness_no_duplicate() -> void:
	target.apply_blindness(12.0)
	target.apply_blindness(12.0)

	assert_eq(target.status_effect_emitted.size(), 1,
		"Should not apply blindness twice")
	assert_eq(target.grenade_hit_emitted.size(), 1,
		"Should not emit grenade_hit twice")


func test_apply_blindness_custom_duration() -> void:
	target.apply_blindness(5.0)

	assert_eq(target.status_effect_emitted[0]["duration"], 5.0,
		"Should use custom duration")


# ============================================================================
# Apply Stun Tests
# ============================================================================


func test_apply_stun_sets_flag() -> void:
	target.apply_stun(6.0)

	assert_true(target._is_stunned,
		"Stun should set the stunned flag")


func test_apply_stun_emits_status_effect() -> void:
	target.apply_stun(6.0)

	assert_eq(target.status_effect_emitted.size(), 1,
		"Should emit status_effect signal")
	assert_eq(target.status_effect_emitted[0]["type"], "stun",
		"Effect type should be stun")
	assert_eq(target.status_effect_emitted[0]["duration"], 6.0,
		"Effect duration should match")


func test_apply_stun_does_not_emit_grenade_hit() -> void:
	target.apply_stun(6.0)

	assert_eq(target.grenade_hit_emitted.size(), 0,
		"Stun should not emit grenade_hit (blindness does that)")


func test_apply_stun_sets_stun_color() -> void:
	target.apply_stun(6.0)

	assert_eq(target.current_color, target.stun_color,
		"Should show stun color when stunned")


func test_apply_stun_no_duplicate() -> void:
	target.apply_stun(6.0)
	target.apply_stun(6.0)

	assert_eq(target.status_effect_emitted.size(), 1,
		"Should not apply stun twice")


func test_apply_stun_custom_duration() -> void:
	target.apply_stun(3.0)

	assert_eq(target.status_effect_emitted[0]["duration"], 3.0,
		"Should use custom duration")


# ============================================================================
# Combined Effect Tests
# ============================================================================


func test_blindness_then_stun() -> void:
	target.apply_blindness(12.0)
	target.apply_stun(6.0)

	assert_true(target._is_blinded,
		"Should still be blinded")
	assert_true(target._is_stunned,
		"Should also be stunned")
	assert_eq(target.status_effect_emitted.size(), 2,
		"Should have both effects emitted")


func test_stun_overrides_blind_visual() -> void:
	target.apply_blindness(12.0)
	target.apply_stun(6.0)

	assert_eq(target.current_color, target.stun_color,
		"Stun color should override blind color")


func test_stun_then_blindness() -> void:
	target.apply_stun(6.0)
	target.apply_blindness(12.0)

	# Stun was applied first, so stun color should persist
	# But blindness still applies and emits grenade_hit
	assert_true(target._is_blinded)
	assert_true(target._is_stunned)
	assert_eq(target.grenade_hit_emitted.size(), 1,
		"Blindness should still emit grenade_hit")


# ============================================================================
# Visual State Tests
# ============================================================================


func test_visual_state_valid_target_default() -> void:
	var color := target.get_visual_state_color()

	assert_eq(color, target.valid_target_color,
		"Valid target should show red by default")


func test_visual_state_invalid_target_default() -> void:
	target.is_valid_target = false
	var color := target.get_visual_state_color()

	assert_eq(color, target.invalid_target_color,
		"Invalid target should show green by default")


func test_visual_state_blinded() -> void:
	target._is_blinded = true
	var color := target.get_visual_state_color()

	assert_eq(color, target.blind_color,
		"Blinded target should show blind color")


func test_visual_state_stunned() -> void:
	target._is_stunned = true
	var color := target.get_visual_state_color()

	assert_eq(color, target.stun_color,
		"Stunned target should show stun color")


func test_visual_state_stunned_overrides_blinded() -> void:
	target._is_blinded = true
	target._is_stunned = true
	var color := target.get_visual_state_color()

	assert_eq(color, target.stun_color,
		"Stun should override blind in visual state")


# ============================================================================
# Reset Tests
# ============================================================================


func test_reset_clears_blinded() -> void:
	target.apply_blindness(12.0)
	target.reset_effects()

	assert_false(target._is_blinded,
		"Reset should clear blinded state")


func test_reset_clears_stunned() -> void:
	target.apply_stun(6.0)
	target.reset_effects()

	assert_false(target._is_stunned,
		"Reset should clear stunned state")


func test_reset_restores_default_color() -> void:
	target.apply_blindness(12.0)
	target.apply_stun(6.0)
	target.reset_effects()

	assert_eq(target.current_color, target.valid_target_color,
		"Reset should restore default color")


func test_reset_invalid_target_restores_correct_color() -> void:
	target.is_valid_target = false
	target.apply_stun(6.0)
	target.reset_effects()

	assert_eq(target.current_color, target.invalid_target_color,
		"Reset should restore invalid target color")


# ============================================================================
# Edge Case Tests
# ============================================================================


func test_zero_duration_blindness() -> void:
	target.apply_blindness(0.0)

	assert_true(target._is_blinded,
		"Zero duration blindness should still apply")
	assert_eq(target.status_effect_emitted[0]["duration"], 0.0,
		"Duration should be zero")


func test_zero_duration_stun() -> void:
	target.apply_stun(0.0)

	assert_true(target._is_stunned,
		"Zero duration stun should still apply")


func test_very_long_duration() -> void:
	target.apply_blindness(3600.0)  # 1 hour
	target.apply_stun(1800.0)  # 30 minutes

	assert_eq(target.status_effect_emitted[0]["duration"], 3600.0,
		"Long blindness duration should work")
	assert_eq(target.status_effect_emitted[1]["duration"], 1800.0,
		"Long stun duration should work")


func test_rapid_apply_reset_cycle() -> void:
	for i in range(5):
		target.apply_blindness(12.0)
		target.apply_stun(6.0)
		target.reset_effects()

	assert_false(target._is_blinded,
		"Should end not blinded after cycle")
	assert_false(target._is_stunned,
		"Should end not stunned after cycle")


func test_change_target_type() -> void:
	target.is_valid_target = true
	target.apply_blindness(12.0)

	assert_true(target.grenade_hit_emitted[0],
		"Should emit true for valid target")

	target.reset_effects()
	target.is_valid_target = false
	target.apply_blindness(12.0)

	assert_false(target.grenade_hit_emitted[1],
		"Should emit false for invalid target")
