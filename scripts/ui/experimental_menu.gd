extends CanvasLayer
## Experimental settings menu.
##
## Contains experimental features that are disabled by default.
## These features may affect gameplay balance and are provided for testing.

## Signal emitted when the back button is pressed.
signal back_pressed

## Reference to UI elements.
@onready var fov_checkbox: CheckButton = $MenuContainer/PanelContainer/MarginContainer/VBoxContainer/FovCheckbox
@onready var back_button: Button = $MenuContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton
@onready var status_label: Label = $MenuContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	# Connect button signals
	fov_checkbox.toggled.connect(_on_fov_toggled)
	back_button.pressed.connect(_on_back_pressed)

	# Update checkbox state based on current setting
	_update_checkbox_states()

	# Set process mode to allow input while paused
	process_mode = Node.PROCESS_MODE_ALWAYS


func _update_checkbox_states() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return

	# Get current FOV enabled state
	var fov_enabled: bool = game_manager.get("experimental_fov_enabled")
	if fov_enabled == null:
		fov_enabled = false

	fov_checkbox.button_pressed = fov_enabled
	_update_status_label(fov_enabled)


func _update_status_label(fov_enabled: bool) -> void:
	if fov_enabled:
		status_label.text = "Enemy FOV: Enabled - Enemies have limited field of view"
	else:
		status_label.text = "Enemy FOV: Disabled - Enemies see in all directions"


func _on_fov_toggled(enabled: bool) -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("set_experimental_fov_enabled"):
		game_manager.set_experimental_fov_enabled(enabled)
	_update_status_label(enabled)


func _on_back_pressed() -> void:
	back_pressed.emit()
