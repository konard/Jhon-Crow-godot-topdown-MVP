extends CanvasLayer
## Armory menu for viewing unlocked and locked weapons and selecting grenade type.
##
## Displays a grid of weapons showing which are unlocked (available) and
## which are locked (coming in future updates). Also allows selection of
## grenade type (Flashbang or Frag Grenade).
##
## Note: Changing grenade type or weapon will restart the current level.

## Signal emitted when the back button is pressed.
signal back_pressed

## Signal emitted when a weapon is selected.
signal weapon_selected(weapon_id: String)

## Dictionary of all weapons with their data.
## Keys: weapon_id, Values: dictionary with name, icon_path, unlocked status
const WEAPONS: Dictionary = {
	"m16": {
		"name": "M16",
		"icon_path": "res://assets/sprites/weapons/m16_rifle.png",
		"unlocked": true,
		"description": "Standard assault rifle"
	},
	"ak47": {
		"name": "???",
		"icon_path": "",
		"unlocked": false,
		"description": "Coming soon"
	},
	"shotgun": {
		"name": "Shotgun",
		"icon_path": "res://assets/sprites/weapons/shotgun_icon.png",
		"unlocked": true,
		"description": "Pump-action shotgun - 6-12 pellets per shot, 15° spread, no wall penetration. Press LMB to fire."
	},
	"smg": {
		"name": "???",
		"icon_path": "",
		"unlocked": false,
		"description": "Coming soon"
	},
	"sniper": {
		"name": "???",
		"icon_path": "",
		"unlocked": false,
		"description": "Coming soon"
	},
	"pistol": {
		"name": "???",
		"icon_path": "",
		"unlocked": false,
		"description": "Coming soon"
	}
}

## Reference to UI elements.
@onready var weapon_grid: GridContainer = $MenuContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/WeaponGrid
@onready var back_button: Button = $MenuContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton
@onready var status_label: Label = $MenuContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel

## Currently selected weapon slot (for visual highlighting).
var _selected_slot: PanelContainer = null

## Map of weapon slots by weapon ID.
var _weapon_slots: Dictionary = {}

## Reference to grenade manager.
var _grenade_manager: Node = null

## Dictionary to track grenade selection slots.
var _grenade_slots: Dictionary = {}


func _ready() -> void:
	# Connect button signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Get grenade manager reference
	_grenade_manager = get_node_or_null("/root/GrenadeManager")

	# Populate weapon grid
	_populate_weapon_grid()

	# Set process mode to allow input while paused
	process_mode = Node.PROCESS_MODE_ALWAYS


func _populate_weapon_grid() -> void:
	# Clear existing children and slot tracking
	for child in weapon_grid.get_children():
		child.queue_free()
	_weapon_slots.clear()
	_grenade_slots.clear()
	_selected_slot = null

	# Count unlocked items for status
	var unlocked_count: int = 0
	var total_count: int = WEAPONS.size()

	# Create a slot for each weapon
	for weapon_id in WEAPONS:
		var weapon_data: Dictionary = WEAPONS[weapon_id]
		var slot := _create_weapon_slot(weapon_id, weapon_data)
		weapon_grid.add_child(slot)
		_weapon_slots[weapon_id] = slot

		if weapon_data["unlocked"]:
			unlocked_count += 1

	# Add grenade selection slots if GrenadeManager is available
	if _grenade_manager:
		var grenade_types := _grenade_manager.get_all_grenade_types()
		for grenade_type in grenade_types:
			var grenade_data := _grenade_manager.get_grenade_data(grenade_type)
			var is_selected := _grenade_manager.is_selected(grenade_type)
			var slot := _create_grenade_slot(grenade_type, grenade_data, is_selected)
			if slot:
				weapon_grid.add_child(slot)
				_grenade_slots[grenade_type] = slot
				unlocked_count += 1
				total_count += 1

	# Update status label
	if status_label:
		status_label.text = "Unlocked: %d / %d" % [unlocked_count, total_count]

	# Highlight currently selected weapon from GameManager
	_highlight_selected_weapon()


func _create_weapon_slot(weapon_id: String, weapon_data: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = weapon_id + "_slot"
	slot.custom_minimum_size = Vector2(100, 100)

	# Store weapon_id in slot's metadata for click handling
	slot.set_meta("weapon_id", weapon_id)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)

	# Weapon icon or placeholder
	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(64, 64)
	vbox.add_child(icon_container)

	if weapon_data["unlocked"] and weapon_data["icon_path"] != "":
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(64, 64)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var texture: Texture2D = load(weapon_data["icon_path"])
		if texture:
			texture_rect.texture = texture

		icon_container.add_child(texture_rect)
	else:
		# Locked weapon - show lock icon (using text for now)
		var lock_label := Label.new()
		lock_label.text = "🔒"
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 32)
		icon_container.add_child(lock_label)

	# Weapon name
	var name_label := Label.new()
	name_label.text = weapon_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if not weapon_data["unlocked"]:
		name_label.modulate = Color(0.5, 0.5, 0.5)

	vbox.add_child(name_label)

	# Add tooltip
	slot.tooltip_text = weapon_data["description"]

	# Make unlocked weapons clickable
	if weapon_data["unlocked"]:
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(slot, weapon_id))
		# Change cursor on hover for clickable slots
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return slot


func _create_grenade_slot(grenade_type: int, grenade_data: Dictionary, is_selected: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	# Use sanitized name for node (no spaces allowed in Godot node names)
	var grenade_name: String = grenade_data.get("name", "grenade")
	slot.name = grenade_name.replace(" ", "_") + "_slot"
	slot.custom_minimum_size = Vector2(100, 120)

	# Store grenade_type in slot's metadata
	slot.set_meta("grenade_type", grenade_type)
	slot.set_meta("is_grenade", true)

	# Add style based on selection state
	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.3, 0.5, 0.3, 0.8)  # Green highlight for selected
		style.border_color = Color(0.4, 0.8, 0.4, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)

	# Grenade icon
	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(64, 64)
	vbox.add_child(icon_container)

	var icon_path: String = grenade_data.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(64, 64)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var texture: Texture2D = load(icon_path)
		if texture:
			texture_rect.texture = texture

		icon_container.add_child(texture_rect)
	else:
		# Fallback icon
		var fallback_label := Label.new()
		fallback_label.text = "💣"
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.add_theme_font_size_override("font_size", 32)
		icon_container.add_child(fallback_label)

	# Grenade name
	var name_label := Label.new()
	name_label.text = grenade_data.get("name", "Grenade")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Add tooltip
	slot.tooltip_text = grenade_data.get("description", "")

	# Make clickable for selection
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.gui_input.connect(_on_grenade_slot_gui_input.bind(slot, grenade_type))
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return slot


## Handle click on weapon slot.
func _on_slot_gui_input(event: InputEvent, slot: PanelContainer, weapon_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_weapon(weapon_id)
		# Play click sound via AudioManager
		var audio_manager = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.has_method("play_ui_click"):
			audio_manager.play_ui_click()


## Handle click on grenade slot.
func _on_grenade_slot_gui_input(event: InputEvent, slot: PanelContainer, grenade_type: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_grenade(grenade_type)
		# Play click sound via AudioManager
		var audio_manager = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.has_method("play_ui_click"):
			audio_manager.play_ui_click()


## Select a weapon and update GameManager.
func _select_weapon(weapon_id: String) -> void:
	# Update selection in GameManager
	if GameManager:
		GameManager.set_selected_weapon(weapon_id)

	# Emit signal for external listeners
	weapon_selected.emit(weapon_id)

	# Update visual highlighting
	_highlight_selected_weapon()


## Select a grenade type and update GrenadeManager.
func _select_grenade(grenade_type: int) -> void:
	if _grenade_manager == null:
		return

	# Check if this grenade is already selected
	if _grenade_manager.is_selected(grenade_type):
		return

	# Set the new grenade type (this will restart the level)
	_grenade_manager.set_grenade_type(grenade_type, true)


## Highlight the currently selected weapon slot.
func _highlight_selected_weapon() -> void:
	var current_weapon_id: String = "m16"  # Default
	if GameManager:
		current_weapon_id = GameManager.get_selected_weapon()

	# Reset all weapon slots to default style
	for wid in _weapon_slots:
		var slot: PanelContainer = _weapon_slots[wid]
		# Create default style (transparent/subtle background)
		var default_style := StyleBoxFlat.new()
		default_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		default_style.corner_radius_top_left = 4
		default_style.corner_radius_top_right = 4
		default_style.corner_radius_bottom_left = 4
		default_style.corner_radius_bottom_right = 4
		slot.add_theme_stylebox_override("panel", default_style)

	# Highlight selected weapon slot
	if current_weapon_id in _weapon_slots:
		var selected_slot: PanelContainer = _weapon_slots[current_weapon_id]
		var selected_style := StyleBoxFlat.new()
		selected_style.bg_color = Color(0.3, 0.5, 0.3, 0.8)  # Green highlight
		selected_style.border_color = Color(0.4, 0.8, 0.4, 1.0)
		selected_style.border_width_left = 2
		selected_style.border_width_right = 2
		selected_style.border_width_top = 2
		selected_style.border_width_bottom = 2
		selected_style.corner_radius_top_left = 4
		selected_style.corner_radius_top_right = 4
		selected_style.corner_radius_bottom_left = 4
		selected_style.corner_radius_bottom_right = 4
		selected_slot.add_theme_stylebox_override("panel", selected_style)
		_selected_slot = selected_slot


func _on_back_pressed() -> void:
	back_pressed.emit()
