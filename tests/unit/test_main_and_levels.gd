extends GutTest
## Unit tests for Main and Level scripts.
##
## Tests the main game script and level-specific functionality.


# ============================================================================
# Mock Main Script for Testing
# ============================================================================


class MockMain:
	## Whether the main script is loaded.
	var _is_loaded: bool = false

	## The message that would be printed.
	var _load_message: String = ""

	func _ready() -> void:
		_is_loaded = true
		_load_message = "Godot Top-Down Template loaded successfully!"

	func is_loaded() -> bool:
		return _is_loaded

	func get_load_message() -> String:
		return _load_message


# ============================================================================
# Mock Building Level for Testing
# ============================================================================


class MockBuildingLevel:
	## Current difficulty level.
	var difficulty: int = 0

	## Number of enemies spawned.
	var enemies_spawned: int = 0

	## Whether the level is completed.
	var is_completed: bool = false

	## Player reference.
	var player: Node2D = null

	## Enemy spawn positions.
	var enemy_spawn_points: Array = []

	## Initialize the level.
	func initialize() -> void:
		enemies_spawned = 0
		is_completed = false

	## Spawn enemies based on difficulty.
	func spawn_enemies() -> int:
		var base_count := 5
		var difficulty_bonus := difficulty * 2
		enemies_spawned = base_count + difficulty_bonus
		return enemies_spawned

	## Mark level as completed.
	func complete_level() -> void:
		is_completed = true

	## Check if all enemies are defeated.
	func check_victory_condition() -> bool:
		return enemies_spawned == 0


# ============================================================================
# Mock Test Tier for Testing
# ============================================================================


class MockTestTier:
	## Current tier number.
	var tier_number: int = 1

	## Maximum tier.
	const MAX_TIER: int = 5

	## Score for current tier.
	var tier_score: int = 0

	## Whether tier is passed.
	var tier_passed: bool = false

	## Get tier name.
	func get_tier_name() -> String:
		return "Tier %d" % tier_number

	## Check if can advance to next tier.
	func can_advance() -> bool:
		return tier_passed and tier_number < MAX_TIER

	## Advance to next tier.
	func advance_tier() -> bool:
		if not can_advance():
			return false
		tier_number += 1
		tier_passed = false
		tier_score = 0
		return true

	## Mark tier as passed.
	func pass_tier(score: int) -> void:
		tier_passed = true
		tier_score = score

	## Reset to tier 1.
	func reset() -> void:
		tier_number = 1
		tier_passed = false
		tier_score = 0


var main: MockMain
var building_level: MockBuildingLevel
var test_tier: MockTestTier


func before_each() -> void:
	main = MockMain.new()
	building_level = MockBuildingLevel.new()
	test_tier = MockTestTier.new()


func after_each() -> void:
	main = null
	building_level = null
	test_tier = null


# ============================================================================
# Main Script Tests
# ============================================================================


func test_main_not_loaded_initially() -> void:
	assert_false(main.is_loaded(),
		"Main should not be loaded before _ready")


func test_main_ready_sets_loaded() -> void:
	main._ready()

	assert_true(main.is_loaded(),
		"Main should be loaded after _ready")


func test_main_load_message() -> void:
	main._ready()

	assert_eq(main.get_load_message(), "Godot Top-Down Template loaded successfully!",
		"Load message should be correct")


# ============================================================================
# Building Level Tests
# ============================================================================


func test_building_level_default_difficulty() -> void:
	assert_eq(building_level.difficulty, 0,
		"Default difficulty should be 0")


func test_building_level_initialize() -> void:
	building_level.enemies_spawned = 10
	building_level.is_completed = true
	building_level.initialize()

	assert_eq(building_level.enemies_spawned, 0,
		"Initialize should reset enemies")
	assert_false(building_level.is_completed,
		"Initialize should reset completion")


func test_building_level_spawn_enemies_base() -> void:
	building_level.difficulty = 0
	var count := building_level.spawn_enemies()

	assert_eq(count, 5,
		"Base difficulty should spawn 5 enemies")


func test_building_level_spawn_enemies_difficulty_scaling() -> void:
	building_level.difficulty = 3
	var count := building_level.spawn_enemies()

	assert_eq(count, 11,
		"Difficulty 3 should spawn 5 + 6 = 11 enemies")


func test_building_level_complete() -> void:
	building_level.complete_level()

	assert_true(building_level.is_completed,
		"Level should be marked as completed")


func test_building_level_victory_condition_false() -> void:
	building_level.enemies_spawned = 5

	assert_false(building_level.check_victory_condition(),
		"Should not be victorious with enemies remaining")


func test_building_level_victory_condition_true() -> void:
	building_level.enemies_spawned = 0

	assert_true(building_level.check_victory_condition(),
		"Should be victorious with no enemies")


# ============================================================================
# Test Tier Tests
# ============================================================================


func test_test_tier_default_number() -> void:
	assert_eq(test_tier.tier_number, 1,
		"Should start at tier 1")


func test_test_tier_max_tier() -> void:
	assert_eq(MockTestTier.MAX_TIER, 5,
		"Max tier should be 5")


func test_test_tier_get_name() -> void:
	assert_eq(test_tier.get_tier_name(), "Tier 1",
		"Tier name should be formatted correctly")


func test_test_tier_name_updates() -> void:
	test_tier.tier_number = 3
	assert_eq(test_tier.get_tier_name(), "Tier 3",
		"Tier name should reflect current tier")


func test_test_tier_cannot_advance_unpassed() -> void:
	assert_false(test_tier.can_advance(),
		"Should not advance unpassed tier")


func test_test_tier_can_advance_passed() -> void:
	test_tier.pass_tier(100)

	assert_true(test_tier.can_advance(),
		"Should be able to advance after passing")


func test_test_tier_cannot_advance_at_max() -> void:
	test_tier.tier_number = 5
	test_tier.pass_tier(100)

	assert_false(test_tier.can_advance(),
		"Should not advance beyond max tier")


func test_test_tier_advance_success() -> void:
	test_tier.pass_tier(100)
	var result := test_tier.advance_tier()

	assert_true(result,
		"Advance should succeed")
	assert_eq(test_tier.tier_number, 2,
		"Should be at tier 2")
	assert_false(test_tier.tier_passed,
		"New tier should not be passed")
	assert_eq(test_tier.tier_score, 0,
		"New tier should have 0 score")


func test_test_tier_advance_failure() -> void:
	var result := test_tier.advance_tier()

	assert_false(result,
		"Advance should fail without passing")
	assert_eq(test_tier.tier_number, 1,
		"Should remain at tier 1")


func test_test_tier_pass_sets_score() -> void:
	test_tier.pass_tier(500)

	assert_true(test_tier.tier_passed,
		"Tier should be passed")
	assert_eq(test_tier.tier_score, 500,
		"Score should be recorded")


func test_test_tier_reset() -> void:
	test_tier.tier_number = 4
	test_tier.tier_passed = true
	test_tier.tier_score = 1000
	test_tier.reset()

	assert_eq(test_tier.tier_number, 1,
		"Reset should return to tier 1")
	assert_false(test_tier.tier_passed,
		"Reset should clear passed state")
	assert_eq(test_tier.tier_score, 0,
		"Reset should clear score")


# ============================================================================
# Full Progression Tests
# ============================================================================


func test_complete_tier_progression() -> void:
	# Progress through all tiers
	for i in range(4):
		test_tier.pass_tier(100 * (i + 1))
		test_tier.advance_tier()

	assert_eq(test_tier.tier_number, 5,
		"Should reach tier 5 after 4 advances")


func test_tier_progression_with_failure() -> void:
	test_tier.pass_tier(100)
	test_tier.advance_tier()
	# Fail tier 2 (don't pass it)
	test_tier.advance_tier()  # Should fail

	assert_eq(test_tier.tier_number, 2,
		"Should remain at tier 2 after failed advance")


func test_building_level_full_cycle() -> void:
	building_level.initialize()
	building_level.difficulty = 2

	var enemies := building_level.spawn_enemies()
	assert_eq(enemies, 9, "Should spawn 9 enemies at difficulty 2")

	# Simulate defeating all enemies
	building_level.enemies_spawned = 0

	assert_true(building_level.check_victory_condition(),
		"Victory condition should be met")

	building_level.complete_level()
	assert_true(building_level.is_completed,
		"Level should be completed")


# ============================================================================
# Edge Case Tests
# ============================================================================


func test_negative_difficulty() -> void:
	building_level.difficulty = -1
	var count := building_level.spawn_enemies()

	# 5 + (-1 * 2) = 3
	assert_eq(count, 3,
		"Negative difficulty should reduce enemy count")


func test_very_high_difficulty() -> void:
	building_level.difficulty = 100
	var count := building_level.spawn_enemies()

	assert_eq(count, 205,
		"High difficulty should spawn many enemies")


func test_zero_score_pass() -> void:
	test_tier.pass_tier(0)

	assert_true(test_tier.tier_passed,
		"Should be able to pass with 0 score")


func test_negative_score() -> void:
	test_tier.pass_tier(-100)

	assert_eq(test_tier.tier_score, -100,
		"Negative score should be recorded")
