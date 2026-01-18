extends Node
## Autoload singleton for managing in-game sound propagation.
##
## This system handles the propagation of sounds that affect gameplay behavior,
## such as gunshots alerting enemies. It is separate from the AudioManager
## which handles actual audio playback.
##
## The system is designed to be extensible:
## - Add new sound types to the SoundType enum
## - Define propagation distances for each sound type
## - Listeners (enemies) register themselves to receive sound events
##
## Usage:
## - Call emit_sound() when a sound-producing action occurs (shooting, explosions, etc.)
## - Listeners call register_listener() to receive sound notifications
## - Listeners implement on_sound_heard(sound_type, position, source) to react

## Types of sounds that can propagate through the game world.
## Each type has different propagation characteristics.
enum SoundType {
	GUNSHOT,      ## Gunfire from weapons - loud, propagates far
	EXPLOSION,    ## Explosions - very loud, propagates very far
	FOOTSTEP,     ## Footsteps - quiet, short range (for future use)
	RELOAD,       ## Weapon reload - medium range (for future use)
	IMPACT        ## Bullet impacts - medium range (for future use)
}

## Source types for sounds - used to determine if listener should react.
enum SourceType {
	PLAYER,   ## Sound came from the player
	ENEMY,    ## Sound came from an enemy
	NEUTRAL   ## Sound came from environment or unknown source
}

## Propagation distances for each sound type (in pixels).
## These define how far a sound can travel before becoming inaudible.
const PROPAGATION_DISTANCES: Dictionary = {
	SoundType.GUNSHOT: 1500.0,
	SoundType.EXPLOSION: 2500.0,
	SoundType.FOOTSTEP: 200.0,
	SoundType.RELOAD: 400.0,
	SoundType.IMPACT: 600.0
}

## Registered sound listeners (typically enemies).
## Each listener must have an on_sound_heard(sound_type, position, source_type, source_node) method.
var _listeners: Array = []

## Whether debug logging is enabled.
var _debug_logging: bool = false


func _ready() -> void:
	# Try to sync with GameManager debug mode
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("is_debug_mode_enabled"):
		_debug_logging = game_manager.is_debug_mode_enabled()
		if game_manager.has_signal("debug_mode_toggled"):
			game_manager.debug_mode_toggled.connect(_on_debug_mode_toggled)


## Called when debug mode is toggled via GameManager.
func _on_debug_mode_toggled(enabled: bool) -> void:
	_debug_logging = enabled


## Register a listener to receive sound events.
## The listener must implement on_sound_heard(sound_type: SoundType, position: Vector2,
##                                            source_type: SourceType, source_node: Node2D) -> void
func register_listener(listener: Node2D) -> void:
	if listener and not _listeners.has(listener):
		_listeners.append(listener)
		_log_debug("Registered sound listener: %s" % listener.name)


## Unregister a listener from receiving sound events.
func unregister_listener(listener: Node2D) -> void:
	var idx := _listeners.find(listener)
	if idx >= 0:
		_listeners.remove_at(idx)
		_log_debug("Unregistered sound listener: %s" % listener.name)


## Emit a sound at a given position.
## All registered listeners within range will be notified.
##
## Parameters:
## - sound_type: The type of sound being emitted
## - position: World position where the sound originates
## - source_type: Whether the sound comes from player, enemy, or neutral source
## - source_node: The node that produced the sound (optional, can be null)
## - custom_range: Override the default propagation distance (optional, -1 uses default)
func emit_sound(sound_type: SoundType, position: Vector2, source_type: SourceType,
				source_node: Node2D = null, custom_range: float = -1.0) -> void:
	var propagation_distance := custom_range if custom_range > 0 else PROPAGATION_DISTANCES.get(sound_type, 1000.0)

	_log_debug("Sound emitted: type=%s, pos=%s, source=%s, range=%.0f" % [
		SoundType.keys()[sound_type],
		position,
		SourceType.keys()[source_type],
		propagation_distance
	])

	# Clean up invalid listeners (destroyed nodes)
	_listeners = _listeners.filter(func(l): return is_instance_valid(l))

	# Notify all listeners within range
	var listeners_notified := 0
	for listener in _listeners:
		if not is_instance_valid(listener):
			continue

		# Skip if listener is the source (can't hear your own sounds as external)
		if source_node and listener == source_node:
			continue

		# Check if listener is within propagation range
		var distance := listener.global_position.distance_to(position)
		if distance <= propagation_distance:
			# Notify the listener
			if listener.has_method("on_sound_heard"):
				listener.on_sound_heard(sound_type, position, source_type, source_node)
				listeners_notified += 1

	if listeners_notified > 0:
		_log_debug("Sound notified %d listeners" % listeners_notified)


## Convenience method to emit a gunshot sound from the player.
func emit_player_gunshot(position: Vector2, source_node: Node2D = null) -> void:
	emit_sound(SoundType.GUNSHOT, position, SourceType.PLAYER, source_node)


## Convenience method to emit a gunshot sound from an enemy.
func emit_enemy_gunshot(position: Vector2, source_node: Node2D = null) -> void:
	emit_sound(SoundType.GUNSHOT, position, SourceType.ENEMY, source_node)


## Get the propagation distance for a sound type.
func get_propagation_distance(sound_type: SoundType) -> float:
	return PROPAGATION_DISTANCES.get(sound_type, 1000.0)


## Get the number of registered listeners.
func get_listener_count() -> int:
	_listeners = _listeners.filter(func(l): return is_instance_valid(l))
	return _listeners.size()


## Log a debug message if debug logging is enabled.
func _log_debug(message: String) -> void:
	if _debug_logging:
		print("[SoundPropagation] " + message)
