extends GutTest
## Unit tests for SoundPropagation autoload.
##
## Tests the sound propagation system including:
## - Listener registration and unregistration
## - Sound emission with different types and sources
## - Distance-based propagation
## - Callback invocation on listeners


## Mock listener class for testing sound reception.
class MockListener extends Node2D:
	var sounds_heard: Array = []
	var last_sound_type: int = -1
	var last_sound_position: Vector2 = Vector2.ZERO
	var last_source_type: int = -1
	var last_source_node: Node2D = null

	func on_sound_heard(sound_type: int, position: Vector2, source_type: int, source_node: Node2D) -> void:
		sounds_heard.append({
			"type": sound_type,
			"position": position,
			"source_type": source_type,
			"source_node": source_node
		})
		last_sound_type = sound_type
		last_sound_position = position
		last_source_type = source_type
		last_source_node = source_node

	func get_sound_count() -> int:
		return sounds_heard.size()

	func clear_sounds() -> void:
		sounds_heard.clear()
		last_sound_type = -1
		last_sound_position = Vector2.ZERO
		last_source_type = -1
		last_source_node = null


var _sound_propagation: Node


func before_each() -> void:
	# Create a fresh SoundPropagation instance for each test
	_sound_propagation = load("res://scripts/autoload/sound_propagation.gd").new()
	add_child(_sound_propagation)


func after_each() -> void:
	if is_instance_valid(_sound_propagation):
		_sound_propagation.queue_free()
	_sound_propagation = null


func test_register_listener() -> void:
	var listener := MockListener.new()
	add_child(listener)

	_sound_propagation.register_listener(listener)

	assert_eq(_sound_propagation.get_listener_count(), 1, "Should have 1 registered listener")

	listener.queue_free()


func test_register_same_listener_twice() -> void:
	var listener := MockListener.new()
	add_child(listener)

	_sound_propagation.register_listener(listener)
	_sound_propagation.register_listener(listener)

	assert_eq(_sound_propagation.get_listener_count(), 1, "Should not duplicate listener registration")

	listener.queue_free()


func test_unregister_listener() -> void:
	var listener := MockListener.new()
	add_child(listener)

	_sound_propagation.register_listener(listener)
	assert_eq(_sound_propagation.get_listener_count(), 1, "Should have 1 registered listener")

	_sound_propagation.unregister_listener(listener)
	assert_eq(_sound_propagation.get_listener_count(), 0, "Should have 0 listeners after unregistration")

	listener.queue_free()


func test_emit_sound_notifies_listener_in_range() -> void:
	var listener := MockListener.new()
	listener.global_position = Vector2(100, 0)
	add_child(listener)

	_sound_propagation.register_listener(listener)

	# Emit a gunshot at origin (listener is 100 pixels away, well within 1500 range)
	_sound_propagation.emit_sound(0, Vector2.ZERO, 0, null)  # GUNSHOT from PLAYER

	assert_eq(listener.get_sound_count(), 1, "Listener should receive 1 sound")
	assert_eq(listener.last_sound_type, 0, "Sound type should be GUNSHOT (0)")
	assert_eq(listener.last_sound_position, Vector2.ZERO, "Sound position should be at origin")
	assert_eq(listener.last_source_type, 0, "Source type should be PLAYER (0)")

	listener.queue_free()


func test_emit_sound_does_not_notify_listener_out_of_range() -> void:
	var listener := MockListener.new()
	listener.global_position = Vector2(2000, 0)  # Beyond 1500 pixel gunshot range
	add_child(listener)

	_sound_propagation.register_listener(listener)

	_sound_propagation.emit_sound(0, Vector2.ZERO, 0, null)  # GUNSHOT from PLAYER

	assert_eq(listener.get_sound_count(), 0, "Listener out of range should not receive sound")

	listener.queue_free()


func test_emit_sound_with_custom_range() -> void:
	var listener := MockListener.new()
	listener.global_position = Vector2(500, 0)
	add_child(listener)

	_sound_propagation.register_listener(listener)

	# Emit with short custom range (200 pixels) - listener is at 500
	_sound_propagation.emit_sound(0, Vector2.ZERO, 0, null, 200.0)

	assert_eq(listener.get_sound_count(), 0, "Listener should not receive sound with short custom range")

	# Emit with long custom range (600 pixels) - listener is at 500
	_sound_propagation.emit_sound(0, Vector2.ZERO, 0, null, 600.0)

	assert_eq(listener.get_sound_count(), 1, "Listener should receive sound with sufficient custom range")

	listener.queue_free()


func test_emit_sound_skips_source_node() -> void:
	var source := MockListener.new()
	source.global_position = Vector2(0, 0)
	add_child(source)

	var listener := MockListener.new()
	listener.global_position = Vector2(100, 0)
	add_child(listener)

	_sound_propagation.register_listener(source)
	_sound_propagation.register_listener(listener)

	# Emit sound from source - source should NOT hear its own sound
	_sound_propagation.emit_sound(0, Vector2.ZERO, 0, source)

	assert_eq(source.get_sound_count(), 0, "Source should not receive its own sound")
	assert_eq(listener.get_sound_count(), 1, "Other listener should receive sound")

	source.queue_free()
	listener.queue_free()


func test_emit_player_gunshot_convenience_method() -> void:
	var listener := MockListener.new()
	listener.global_position = Vector2(100, 0)
	add_child(listener)

	_sound_propagation.register_listener(listener)

	_sound_propagation.emit_player_gunshot(Vector2(50, 50), null)

	assert_eq(listener.get_sound_count(), 1, "Listener should receive player gunshot")
	assert_eq(listener.last_sound_type, 0, "Sound type should be GUNSHOT (0)")
	assert_eq(listener.last_sound_position, Vector2(50, 50), "Sound position should match")
	assert_eq(listener.last_source_type, 0, "Source type should be PLAYER (0)")

	listener.queue_free()


func test_emit_enemy_gunshot_convenience_method() -> void:
	var listener := MockListener.new()
	listener.global_position = Vector2(100, 0)
	add_child(listener)

	_sound_propagation.register_listener(listener)

	_sound_propagation.emit_enemy_gunshot(Vector2(25, 25), null)

	assert_eq(listener.get_sound_count(), 1, "Listener should receive enemy gunshot")
	assert_eq(listener.last_sound_type, 0, "Sound type should be GUNSHOT (0)")
	assert_eq(listener.last_sound_position, Vector2(25, 25), "Sound position should match")
	assert_eq(listener.last_source_type, 1, "Source type should be ENEMY (1)")

	listener.queue_free()


func test_multiple_listeners_receive_sound() -> void:
	var listener1 := MockListener.new()
	listener1.global_position = Vector2(100, 0)
	add_child(listener1)

	var listener2 := MockListener.new()
	listener2.global_position = Vector2(0, 100)
	add_child(listener2)

	var listener3 := MockListener.new()
	listener3.global_position = Vector2(-100, 0)
	add_child(listener3)

	_sound_propagation.register_listener(listener1)
	_sound_propagation.register_listener(listener2)
	_sound_propagation.register_listener(listener3)

	_sound_propagation.emit_sound(0, Vector2.ZERO, 0, null)

	assert_eq(listener1.get_sound_count(), 1, "Listener 1 should receive sound")
	assert_eq(listener2.get_sound_count(), 1, "Listener 2 should receive sound")
	assert_eq(listener3.get_sound_count(), 1, "Listener 3 should receive sound")

	listener1.queue_free()
	listener2.queue_free()
	listener3.queue_free()


func test_get_propagation_distance_for_known_types() -> void:
	# GUNSHOT = 0
	assert_eq(_sound_propagation.get_propagation_distance(0), 1500.0, "Gunshot should have 1500 range")
	# EXPLOSION = 1
	assert_eq(_sound_propagation.get_propagation_distance(1), 2500.0, "Explosion should have 2500 range")
	# FOOTSTEP = 2
	assert_eq(_sound_propagation.get_propagation_distance(2), 200.0, "Footstep should have 200 range")
	# RELOAD = 3
	assert_eq(_sound_propagation.get_propagation_distance(3), 400.0, "Reload should have 400 range")
	# IMPACT = 4
	assert_eq(_sound_propagation.get_propagation_distance(4), 600.0, "Impact should have 600 range")


func test_get_propagation_distance_for_unknown_type_returns_default() -> void:
	# Unknown type should return default of 1000
	assert_eq(_sound_propagation.get_propagation_distance(999), 1000.0, "Unknown type should return 1000 default")


func test_destroyed_listener_is_cleaned_up() -> void:
	var listener := MockListener.new()
	listener.global_position = Vector2(100, 0)
	add_child(listener)

	_sound_propagation.register_listener(listener)
	assert_eq(_sound_propagation.get_listener_count(), 1, "Should have 1 registered listener")

	# Destroy the listener
	listener.queue_free()
	await get_tree().process_frame

	# Emit a sound - this should trigger cleanup of invalid listeners
	_sound_propagation.emit_sound(0, Vector2.ZERO, 0, null)

	assert_eq(_sound_propagation.get_listener_count(), 0, "Destroyed listener should be cleaned up")


func test_null_listener_is_not_registered() -> void:
	_sound_propagation.register_listener(null)

	assert_eq(_sound_propagation.get_listener_count(), 0, "Null listener should not be registered")
