extends Node

## Test script to verify GameManager signal connections work properly.
## This tests the grenade_debug_logging_toggled signal specifically.

func _ready() -> void:
	print("=== Signal Connection Test ===")

	# Wait a frame to ensure autoloads are ready
	await get_tree().process_frame

	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		print("ERROR: GameManager not found!")
		return

	print("GameManager found: ", game_manager)
	print("Has signal 'grenade_debug_logging_toggled':", game_manager.has_signal("grenade_debug_logging_toggled"))
	print("Has method 'toggle_grenade_debug_logging':", game_manager.has_method("toggle_grenade_debug_logging"))
	print("Has method 'is_grenade_debug_logging_enabled':", game_manager.has_method("is_grenade_debug_logging_enabled"))

	# Connect to the signal
	if game_manager.has_signal("grenade_debug_logging_toggled"):
		game_manager.grenade_debug_logging_toggled.connect(_on_test_signal_received)
		print("Signal connected successfully")

	# Test the current state
	if game_manager.has_method("is_grenade_debug_logging_enabled"):
		var current_state = game_manager.is_grenade_debug_logging_enabled()
		print("Current grenade debug state:", current_state)

	# Wait a moment
	await get_tree().create_timer(0.5).timeout

	# Toggle the debug mode
	print("\n=== Testing signal emission ===")
	if game_manager.has_method("toggle_grenade_debug_logging"):
		print("Calling toggle_grenade_debug_logging()...")
		game_manager.toggle_grenade_debug_logging()

		await get_tree().create_timer(0.1).timeout

		print("Calling toggle_grenade_debug_logging() again...")
		game_manager.toggle_grenade_debug_logging()

	await get_tree().create_timer(0.5).timeout
	print("\n=== Test Complete ===")
	get_tree().quit()

func _on_test_signal_received(enabled: bool) -> void:
	print("!!! SIGNAL RECEIVED !!! enabled=", enabled)
