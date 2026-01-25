extends GutTest
## Unit tests for ArmoryMenu.
##
## Tests the weapon/grenade selection menu logic.


# ============================================================================
# Mock ArmoryMenu for Testing
# ============================================================================


class MockArmoryMenu:
	## Dictionary of all weapons with their data.
	const WEAPONS: Dictionary = {
		"m16": {
			"name": "M16",
			"icon_path": "res://assets/sprites/weapons/m16_rifle.png",
			"unlocked": true,
			"description": "Standard assault rifle",
			"is_grenade": false
		},
		"flashbang": {
			"name": "Flashbang",
			"icon_path": "res://assets/sprites/weapons/flashbang.png",
			"unlocked": true,
			"description": "Stun grenade",
			"is_grenade": true,
			"grenade_type": 0
		},
		"frag_grenade": {
			"name": "Frag Grenade",
			"icon_path": "res://assets/sprites/weapons/frag_grenade.png",
			"unlocked": true,
			"description": "Offensive grenade",
			"is_grenade": true,
			"grenade_type": 1
		},
		"ak47": {
			"name": "???",
			"icon_path": "",
			"unlocked": false,
			"description": "Coming soon",
			"is_grenade": false
		},
		"shotgun": {
			"name": "Shotgun",
			"icon_path": "res://assets/sprites/weapons/shotgun_icon.png",
			"unlocked": true,
			"description": "Pump-action shotgun",
			"is_grenade": false
		}
	}

	## Currently selected weapon ID.
	var selected_weapon: String = "m16"

	## Currently selected grenade type.
	var selected_grenade_type: int = 0

	## Signal tracking.
	var back_pressed_emitted: int = 0
	var weapon_selected_emitted: Array = []
	var grenade_selected_emitted: Array = []

	## Count unlocked weapons.
	func count_unlocked_weapons() -> int:
		var count := 0
		for weapon_id in WEAPONS:
			if WEAPONS[weapon_id]["unlocked"]:
				count += 1
		return count

	## Get total weapon count.
	func count_total_weapons() -> int:
		return WEAPONS.size()

	## Check if weapon is unlocked.
	func is_weapon_unlocked(weapon_id: String) -> bool:
		if not weapon_id in WEAPONS:
			return false
		return WEAPONS[weapon_id]["unlocked"]

	## Check if weapon is a grenade.
	func is_grenade(weapon_id: String) -> bool:
		if not weapon_id in WEAPONS:
			return false
		return WEAPONS[weapon_id].get("is_grenade", false)

	## Get grenade type for a weapon ID.
	func get_grenade_type(weapon_id: String) -> int:
		if not weapon_id in WEAPONS:
			return -1
		return WEAPONS[weapon_id].get("grenade_type", -1)

	## Select a weapon.
	func select_weapon(weapon_id: String) -> bool:
		if not is_weapon_unlocked(weapon_id):
			return false

		if is_grenade(weapon_id):
			return false  # Use select_grenade for grenades

		if weapon_id == selected_weapon:
			return false  # Already selected

		selected_weapon = weapon_id
		weapon_selected_emitted.append(weapon_id)
		return true

	## Select a grenade.
	func select_grenade(weapon_id: String) -> bool:
		if not is_weapon_unlocked(weapon_id):
			return false

		if not is_grenade(weapon_id):
			return false  # Not a grenade

		var grenade_type := get_grenade_type(weapon_id)
		if grenade_type == selected_grenade_type:
			return false  # Already selected

		selected_grenade_type = grenade_type
		grenade_selected_emitted.append(weapon_id)
		return true

	## Handle back button press.
	func press_back() -> void:
		back_pressed_emitted += 1

	## Get status text.
	func get_status_text() -> String:
		return "Unlocked: %d / %d" % [count_unlocked_weapons(), count_total_weapons()]


var menu: MockArmoryMenu


func before_each() -> void:
	menu = MockArmoryMenu.new()


func after_each() -> void:
	menu = null


# ============================================================================
# Weapon Data Tests
# ============================================================================


func test_weapons_dictionary_exists() -> void:
	assert_true(menu.WEAPONS.size() > 0,
		"WEAPONS dictionary should have entries")


func test_m16_is_unlocked() -> void:
	assert_true(menu.is_weapon_unlocked("m16"),
		"M16 should be unlocked")


func test_ak47_is_locked() -> void:
	assert_false(menu.is_weapon_unlocked("ak47"),
		"AK47 should be locked")


func test_flashbang_is_grenade() -> void:
	assert_true(menu.is_grenade("flashbang"),
		"Flashbang should be a grenade")


func test_m16_is_not_grenade() -> void:
	assert_false(menu.is_grenade("m16"),
		"M16 should not be a grenade")


func test_unknown_weapon_not_unlocked() -> void:
	assert_false(menu.is_weapon_unlocked("unknown_weapon"),
		"Unknown weapon should not be unlocked")


func test_unknown_weapon_not_grenade() -> void:
	assert_false(menu.is_grenade("unknown_weapon"),
		"Unknown weapon should not be a grenade")


func test_flashbang_grenade_type() -> void:
	assert_eq(menu.get_grenade_type("flashbang"), 0,
		"Flashbang should have grenade_type 0")


func test_frag_grenade_grenade_type() -> void:
	assert_eq(menu.get_grenade_type("frag_grenade"), 1,
		"Frag grenade should have grenade_type 1")


func test_m16_no_grenade_type() -> void:
	assert_eq(menu.get_grenade_type("m16"), -1,
		"Non-grenade should have grenade_type -1")


# ============================================================================
# Weapon Count Tests
# ============================================================================


func test_count_unlocked_weapons() -> void:
	var count := menu.count_unlocked_weapons()

	# M16, Flashbang, Frag Grenade, Shotgun are unlocked (4)
	assert_eq(count, 4,
		"Should count correct number of unlocked weapons")


func test_count_total_weapons() -> void:
	var count := menu.count_total_weapons()

	assert_eq(count, 5,
		"Should count total weapons correctly")


func test_status_text() -> void:
	var status := menu.get_status_text()

	assert_eq(status, "Unlocked: 4 / 5",
		"Status text should show unlocked/total")


# ============================================================================
# Weapon Selection Tests
# ============================================================================


func test_select_weapon_success() -> void:
	var result := menu.select_weapon("shotgun")

	assert_true(result,
		"Should successfully select unlocked weapon")
	assert_eq(menu.selected_weapon, "shotgun",
		"Selected weapon should be updated")


func test_select_weapon_emits_signal() -> void:
	menu.select_weapon("shotgun")

	assert_eq(menu.weapon_selected_emitted.size(), 1,
		"Should emit weapon_selected signal")
	assert_eq(menu.weapon_selected_emitted[0], "shotgun",
		"Signal should contain weapon ID")


func test_select_same_weapon_no_signal() -> void:
	menu.selected_weapon = "m16"
	var result := menu.select_weapon("m16")

	assert_false(result,
		"Should return false for same weapon")
	assert_eq(menu.weapon_selected_emitted.size(), 0,
		"Should not emit signal for same weapon")


func test_select_locked_weapon() -> void:
	var result := menu.select_weapon("ak47")

	assert_false(result,
		"Should not select locked weapon")
	assert_eq(menu.selected_weapon, "m16",
		"Selected weapon should remain unchanged")


func test_select_grenade_as_weapon() -> void:
	var result := menu.select_weapon("flashbang")

	assert_false(result,
		"Should not select grenade via select_weapon")


# ============================================================================
# Grenade Selection Tests
# ============================================================================


func test_select_grenade_success() -> void:
	menu.selected_grenade_type = 0  # Flashbang
	var result := menu.select_grenade("frag_grenade")

	assert_true(result,
		"Should successfully select different grenade")
	assert_eq(menu.selected_grenade_type, 1,
		"Selected grenade type should be updated")


func test_select_grenade_emits_signal() -> void:
	menu.selected_grenade_type = 0
	menu.select_grenade("frag_grenade")

	assert_eq(menu.grenade_selected_emitted.size(), 1,
		"Should emit grenade selection signal")
	assert_eq(menu.grenade_selected_emitted[0], "frag_grenade",
		"Signal should contain grenade ID")


func test_select_same_grenade_no_signal() -> void:
	menu.selected_grenade_type = 0
	var result := menu.select_grenade("flashbang")

	assert_false(result,
		"Should return false for same grenade")
	assert_eq(menu.grenade_selected_emitted.size(), 0,
		"Should not emit signal for same grenade")


func test_select_weapon_as_grenade() -> void:
	var result := menu.select_grenade("m16")

	assert_false(result,
		"Should not select weapon via select_grenade")


# ============================================================================
# Back Button Tests
# ============================================================================


func test_back_button_emits_signal() -> void:
	menu.press_back()

	assert_eq(menu.back_pressed_emitted, 1,
		"Should emit back_pressed signal")


func test_multiple_back_presses() -> void:
	menu.press_back()
	menu.press_back()
	menu.press_back()

	assert_eq(menu.back_pressed_emitted, 3,
		"Should emit signal for each press")


# ============================================================================
# Sequential Selection Tests
# ============================================================================


func test_switch_weapons() -> void:
	menu.select_weapon("shotgun")
	menu.select_weapon("m16")

	assert_eq(menu.selected_weapon, "m16",
		"Should switch back to m16")
	assert_eq(menu.weapon_selected_emitted.size(), 2,
		"Should emit signal for each switch")


func test_switch_grenades() -> void:
	menu.selected_grenade_type = 0
	menu.select_grenade("frag_grenade")
	menu.select_grenade("flashbang")

	assert_eq(menu.selected_grenade_type, 0,
		"Should switch back to flashbang")
	assert_eq(menu.grenade_selected_emitted.size(), 2,
		"Should emit signal for each switch")


func test_select_weapon_and_grenade() -> void:
	menu.select_weapon("shotgun")
	menu.select_grenade("frag_grenade")

	assert_eq(menu.selected_weapon, "shotgun",
		"Weapon should be updated")
	assert_eq(menu.selected_grenade_type, 1,
		"Grenade should be updated")


# ============================================================================
# Edge Case Tests
# ============================================================================


func test_empty_weapon_id() -> void:
	var result := menu.select_weapon("")

	assert_false(result,
		"Empty weapon ID should fail")


func test_null_like_weapon_id() -> void:
	var result := menu.is_weapon_unlocked("null")

	assert_false(result,
		"String 'null' should not match any weapon")


func test_case_sensitivity() -> void:
	var lower := menu.is_weapon_unlocked("m16")
	var upper := menu.is_weapon_unlocked("M16")

	assert_true(lower,
		"Lowercase should work")
	assert_false(upper,
		"Uppercase should not work (case sensitive)")


func test_all_unlocked_weapons_selectable() -> void:
	var unlocked_non_grenades := ["m16", "shotgun"]

	for weapon_id in unlocked_non_grenades:
		menu.selected_weapon = ""  # Reset
		var result := menu.select_weapon(weapon_id)
		assert_true(result,
			"Should be able to select %s" % weapon_id)


func test_all_grenades_selectable() -> void:
	var grenades := ["flashbang", "frag_grenade"]

	for i in range(grenades.size()):
		# Start with opposite grenade selected
		menu.selected_grenade_type = 1 if i == 0 else 0
		var result := menu.select_grenade(grenades[i])
		assert_true(result,
			"Should be able to select %s" % grenades[i])
