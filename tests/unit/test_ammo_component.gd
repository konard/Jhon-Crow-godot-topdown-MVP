extends GutTest
## Unit tests for AmmoComponent.
##
## Tests the ammunition management system including magazine handling,
## reload mechanics, and ammo consumption.


# ============================================================================
# Mock AmmoComponent for Logic Tests
# ============================================================================


class MockAmmoComponent:
	## Magazine size (bullets per magazine).
	var magazine_size: int = 30

	## Total number of magazines the entity carries.
	var total_magazines: int = 5

	## Time to reload in seconds.
	var reload_time: float = 3.0

	## Current ammo in the magazine.
	var _current_ammo: int = 0

	## Reserve ammo (ammo in remaining magazines).
	var _reserve_ammo: int = 0

	## Whether currently reloading.
	var _is_reloading: bool = false

	## Timer for reload progress.
	var _reload_timer: float = 0.0

	## Signal tracking
	var ammo_changed_emitted: Array = []
	var reload_started_emitted: int = 0
	var reload_finished_emitted: int = 0
	var ammo_depleted_emitted: int = 0


	## Initialize ammunition.
	func initialize_ammo() -> void:
		_current_ammo = magazine_size
		# Reserve ammo is (total_magazines - 1) since one magazine is loaded
		_reserve_ammo = (total_magazines - 1) * magazine_size
		_is_reloading = false
		_reload_timer = 0.0


	## Process reload timer.
	func update_reload(delta: float) -> void:
		if not _is_reloading:
			return

		_reload_timer += delta
		if _reload_timer >= reload_time:
			_finish_reload()


	## Check if can shoot (has ammo and not reloading).
	func can_shoot() -> bool:
		return _current_ammo > 0 and not _is_reloading


	## Consume one round of ammo.
	## Returns true if successful, false if no ammo.
	func consume_ammo() -> bool:
		if _current_ammo <= 0:
			return false

		_current_ammo -= 1
		ammo_changed_emitted.append({"current": _current_ammo, "reserve": _reserve_ammo})

		# Auto-reload when magazine is empty
		if _current_ammo <= 0 and _reserve_ammo > 0:
			start_reload()
		elif _current_ammo <= 0 and _reserve_ammo <= 0:
			ammo_depleted_emitted += 1

		return true


	## Start reloading.
	func start_reload() -> void:
		if _is_reloading or _reserve_ammo <= 0 or _current_ammo >= magazine_size:
			return

		_is_reloading = true
		_reload_timer = 0.0
		reload_started_emitted += 1


	## Finish reloading.
	func _finish_reload() -> void:
		var ammo_needed := magazine_size - _current_ammo
		var ammo_to_load := mini(ammo_needed, _reserve_ammo)

		_current_ammo += ammo_to_load
		_reserve_ammo -= ammo_to_load
		_is_reloading = false
		_reload_timer = 0.0

		ammo_changed_emitted.append({"current": _current_ammo, "reserve": _reserve_ammo})
		reload_finished_emitted += 1


	## Reset ammo to full.
	func reset() -> void:
		initialize_ammo()


	## Get current ammo in magazine.
	func get_current_ammo() -> int:
		return _current_ammo


	## Get reserve ammo.
	func get_reserve_ammo() -> int:
		return _reserve_ammo


	## Get total ammo (current + reserve).
	func get_total_ammo() -> int:
		return _current_ammo + _reserve_ammo


	## Check if reloading.
	func is_reloading() -> bool:
		return _is_reloading


	## Check if has any ammo.
	func has_ammo() -> bool:
		return _current_ammo > 0 or _reserve_ammo > 0


var ammo: MockAmmoComponent


func before_each() -> void:
	ammo = MockAmmoComponent.new()


func after_each() -> void:
	ammo = null


# ============================================================================
# Initialization Tests
# ============================================================================


func test_default_magazine_size() -> void:
	assert_eq(ammo.magazine_size, 30,
		"Default magazine size should be 30")


func test_default_total_magazines() -> void:
	assert_eq(ammo.total_magazines, 5,
		"Default total magazines should be 5")


func test_default_reload_time() -> void:
	assert_eq(ammo.reload_time, 3.0,
		"Default reload time should be 3.0 seconds")


func test_initialize_ammo_sets_current() -> void:
	ammo.initialize_ammo()

	assert_eq(ammo.get_current_ammo(), 30,
		"Current ammo should be magazine size")


func test_initialize_ammo_sets_reserve() -> void:
	ammo.initialize_ammo()

	assert_eq(ammo.get_reserve_ammo(), 120,
		"Reserve ammo should be (total_magazines - 1) * magazine_size")


func test_initialize_ammo_not_reloading() -> void:
	ammo.initialize_ammo()

	assert_false(ammo.is_reloading(),
		"Should not be reloading after initialization")


func test_initialize_custom_magazine_size() -> void:
	ammo.magazine_size = 10
	ammo.total_magazines = 3
	ammo.initialize_ammo()

	assert_eq(ammo.get_current_ammo(), 10,
		"Current ammo should match custom magazine size")
	assert_eq(ammo.get_reserve_ammo(), 20,
		"Reserve should be 2 magazines worth")


# ============================================================================
# Can Shoot Tests
# ============================================================================


func test_can_shoot_true_with_ammo() -> void:
	ammo.initialize_ammo()

	assert_true(ammo.can_shoot(),
		"Should be able to shoot with ammo")


func test_can_shoot_false_without_ammo() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0

	assert_false(ammo.can_shoot(),
		"Should not be able to shoot without ammo")


func test_can_shoot_false_while_reloading() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 15  # Partial magazine
	ammo.start_reload()

	assert_false(ammo.can_shoot(),
		"Should not be able to shoot while reloading")


# ============================================================================
# Consume Ammo Tests
# ============================================================================


func test_consume_ammo_reduces_current() -> void:
	ammo.initialize_ammo()
	ammo.consume_ammo()

	assert_eq(ammo.get_current_ammo(), 29,
		"Consuming ammo should reduce current by 1")


func test_consume_ammo_returns_true() -> void:
	ammo.initialize_ammo()
	var result := ammo.consume_ammo()

	assert_true(result,
		"Should return true when ammo consumed")


func test_consume_ammo_returns_false_when_empty() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	var result := ammo.consume_ammo()

	assert_false(result,
		"Should return false when no ammo")


func test_consume_ammo_emits_signal() -> void:
	ammo.initialize_ammo()
	ammo.consume_ammo()

	assert_eq(ammo.ammo_changed_emitted.size(), 1,
		"Should emit ammo_changed signal")
	assert_eq(ammo.ammo_changed_emitted[0]["current"], 29,
		"Signal should contain new current ammo")


func test_consume_ammo_triggers_auto_reload() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 1  # Last round
	ammo.consume_ammo()

	assert_true(ammo.is_reloading(),
		"Should auto-reload when magazine empty")
	assert_eq(ammo.reload_started_emitted, 1,
		"Should emit reload_started signal")


func test_consume_ammo_triggers_depleted_signal() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 1
	ammo._reserve_ammo = 0  # No reserve
	ammo.consume_ammo()

	assert_eq(ammo.ammo_depleted_emitted, 1,
		"Should emit ammo_depleted when all ammo used")


func test_consume_multiple_rounds() -> void:
	ammo.initialize_ammo()

	for i in range(5):
		ammo.consume_ammo()

	assert_eq(ammo.get_current_ammo(), 25,
		"Should have 25 rounds after consuming 5")


# ============================================================================
# Reload Tests
# ============================================================================


func test_start_reload_sets_reloading() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 15
	ammo.start_reload()

	assert_true(ammo.is_reloading(),
		"Should be reloading after start_reload")


func test_start_reload_emits_signal() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 15
	ammo.start_reload()

	assert_eq(ammo.reload_started_emitted, 1,
		"Should emit reload_started signal")


func test_start_reload_does_nothing_when_reloading() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 15
	ammo.start_reload()
	ammo.start_reload()  # Try again

	assert_eq(ammo.reload_started_emitted, 1,
		"Should not emit signal twice")


func test_start_reload_does_nothing_when_no_reserve() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 15
	ammo._reserve_ammo = 0
	ammo.start_reload()

	assert_false(ammo.is_reloading(),
		"Should not reload without reserve ammo")


func test_start_reload_does_nothing_when_full() -> void:
	ammo.initialize_ammo()  # Full magazine
	ammo.start_reload()

	assert_false(ammo.is_reloading(),
		"Should not reload with full magazine")


# ============================================================================
# Update Reload Tests
# ============================================================================


func test_update_reload_does_nothing_when_not_reloading() -> void:
	ammo.initialize_ammo()
	ammo.update_reload(1.0)

	assert_eq(ammo.reload_finished_emitted, 0,
		"Should not finish reload when not reloading")


func test_update_reload_increments_timer() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	ammo.start_reload()
	ammo.update_reload(1.0)

	assert_eq(ammo._reload_timer, 1.0,
		"Reload timer should increase")


func test_update_reload_finishes_at_reload_time() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	ammo.start_reload()
	ammo.update_reload(3.0)  # Full reload time

	assert_false(ammo.is_reloading(),
		"Should finish reloading after reload_time")


func test_update_reload_emits_finished_signal() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	ammo.start_reload()
	ammo.update_reload(3.0)

	assert_eq(ammo.reload_finished_emitted, 1,
		"Should emit reload_finished signal")


func test_update_reload_restores_ammo() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	var reserve_before := ammo.get_reserve_ammo()
	ammo.start_reload()
	ammo.update_reload(3.0)

	assert_eq(ammo.get_current_ammo(), 30,
		"Should restore full magazine")
	assert_eq(ammo.get_reserve_ammo(), reserve_before - 30,
		"Reserve should decrease by magazine size")


func test_update_reload_partial_reserve() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	ammo._reserve_ammo = 15  # Less than full magazine
	ammo.start_reload()
	ammo.update_reload(3.0)

	assert_eq(ammo.get_current_ammo(), 15,
		"Should load only available reserve")
	assert_eq(ammo.get_reserve_ammo(), 0,
		"Reserve should be depleted")


func test_update_reload_partial_magazine() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 20  # Partial magazine
	var reserve_before := ammo.get_reserve_ammo()
	ammo.start_reload()
	ammo.update_reload(3.0)

	assert_eq(ammo.get_current_ammo(), 30,
		"Should top up magazine")
	assert_eq(ammo.get_reserve_ammo(), reserve_before - 10,
		"Reserve should decrease by amount loaded")


func test_update_reload_gradual_progress() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	ammo.start_reload()

	# Simulate 60fps for 2 seconds
	for i in range(120):
		ammo.update_reload(1.0 / 60.0)

	assert_true(ammo.is_reloading(),
		"Should still be reloading after 2 seconds")

	# Continue for 1.1 more seconds to account for floating-point precision
	for i in range(66):
		ammo.update_reload(1.0 / 60.0)

	assert_false(ammo.is_reloading(),
		"Should finish reloading after 3+ seconds")


# ============================================================================
# Reset Tests
# ============================================================================


func test_reset_restores_full_ammo() -> void:
	ammo.initialize_ammo()
	for i in range(50):
		if ammo.can_shoot():
			ammo.consume_ammo()
		ammo.update_reload(0.1)

	ammo.reset()

	assert_eq(ammo.get_current_ammo(), 30,
		"Reset should restore current ammo")
	assert_eq(ammo.get_reserve_ammo(), 120,
		"Reset should restore reserve ammo")


func test_reset_clears_reloading() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	ammo.start_reload()
	ammo.reset()

	assert_false(ammo.is_reloading(),
		"Reset should clear reloading state")


# ============================================================================
# Getter Tests
# ============================================================================


func test_get_current_ammo() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 15

	assert_eq(ammo.get_current_ammo(), 15,
		"get_current_ammo should return current value")


func test_get_reserve_ammo() -> void:
	ammo.initialize_ammo()
	ammo._reserve_ammo = 60

	assert_eq(ammo.get_reserve_ammo(), 60,
		"get_reserve_ammo should return reserve value")


func test_get_total_ammo() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 15
	ammo._reserve_ammo = 60

	assert_eq(ammo.get_total_ammo(), 75,
		"get_total_ammo should return sum of current and reserve")


func test_is_reloading() -> void:
	ammo.initialize_ammo()
	ammo._current_ammo = 15

	assert_false(ammo.is_reloading(),
		"is_reloading should return false initially")

	ammo.start_reload()

	assert_true(ammo.is_reloading(),
		"is_reloading should return true after start_reload")


func test_has_ammo_with_current() -> void:
	ammo._current_ammo = 5
	ammo._reserve_ammo = 0

	assert_true(ammo.has_ammo(),
		"has_ammo should return true with current ammo")


func test_has_ammo_with_reserve() -> void:
	ammo._current_ammo = 0
	ammo._reserve_ammo = 30

	assert_true(ammo.has_ammo(),
		"has_ammo should return true with reserve ammo")


func test_has_ammo_false_when_empty() -> void:
	ammo._current_ammo = 0
	ammo._reserve_ammo = 0

	assert_false(ammo.has_ammo(),
		"has_ammo should return false when all ammo depleted")


# ============================================================================
# Edge Case Tests
# ============================================================================


func test_single_shot_weapon() -> void:
	ammo.magazine_size = 1
	ammo.total_magazines = 3
	ammo.initialize_ammo()

	assert_eq(ammo.get_current_ammo(), 1,
		"Single shot weapon should have 1 round")
	assert_eq(ammo.get_reserve_ammo(), 2,
		"Single shot weapon should have 2 reserve")

	ammo.consume_ammo()

	assert_true(ammo.is_reloading(),
		"Should auto-reload after single shot")


func test_no_reserve_magazines() -> void:
	ammo.magazine_size = 30
	ammo.total_magazines = 1
	ammo.initialize_ammo()

	assert_eq(ammo.get_reserve_ammo(), 0,
		"Should have no reserve with 1 magazine")


func test_large_magazine() -> void:
	ammo.magazine_size = 100
	ammo.total_magazines = 10
	ammo.initialize_ammo()

	assert_eq(ammo.get_current_ammo(), 100,
		"Large magazine should work correctly")
	assert_eq(ammo.get_reserve_ammo(), 900,
		"Reserve should scale with magazine count")


func test_fast_reload() -> void:
	ammo.reload_time = 0.1
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	ammo.start_reload()
	ammo.update_reload(0.1)

	assert_false(ammo.is_reloading(),
		"Fast reload should complete quickly")


func test_slow_reload() -> void:
	ammo.reload_time = 10.0
	ammo.initialize_ammo()
	ammo._current_ammo = 0
	ammo.start_reload()
	ammo.update_reload(5.0)

	assert_true(ammo.is_reloading(),
		"Slow reload should still be in progress at half time")

	ammo.update_reload(5.0)

	assert_false(ammo.is_reloading(),
		"Slow reload should complete after full time")
