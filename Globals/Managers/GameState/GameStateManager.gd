extends Node

# ==============================================================================
# GAME STATE MANAGER SINGLETON
# ==============================================================================
# Global game state management system for coordinating different game modes
# and their transitions. Provides a centralized, scene-agnostic approach to
# managing game flow and behavior changes.
#
# This singleton is autoloaded as "GameState" and accessible throughout the project.
# ==============================================================================

# ==============================================================================
# ENUMS
# ==============================================================================

## Different modes the game can be in, each with distinct behavior patterns
enum GameMode {
	OVERWORLD,      # Free exploration and movement
	COMBAT,         # Turn-based tactical combat
	DIALOGUE,       # NPC conversations and story interactions
	MENU,           # Game menus (inventory, character sheet, settings, etc.)
	CUTSCENE,       # Scripted sequences with limited/no player control
	TRANSITION,     # Loading or transitioning between major game states
	PAUSED          # Game paused (time stopped, input limited)
}

## Types of transitions between game modes
enum TransitionType {
	IMMEDIATE,      # Instant mode switch
	FADE,           # Visual fade transition
	CUSTOM          # Custom transition logic
}

# ==============================================================================
# SIGNALS
# ==============================================================================

## Emitted when the game mode changes
## Systems should connect to this to adjust their behavior
signal mode_changed(from_mode: GameMode, to_mode: GameMode)

## Emitted when a mode transition begins (before mode_changed)
signal mode_transition_started(from_mode: GameMode, to_mode: GameMode, 
	transition_type: TransitionType)

## Emitted when a mode transition completes (after mode_changed)
signal mode_transition_completed(new_mode: GameMode)

## Emitted when a mode change is requested but denied
signal mode_change_denied(requested_mode: GameMode, current_mode: GameMode, 
	reason: String)

# ==============================================================================
# STATE VARIABLES
# ==============================================================================

## The current active game mode
var current_mode: GameMode = GameMode.OVERWORLD:
	set(value):
		if value != current_mode:
			_change_mode(value)

## The previous game mode (for reference and potential rollback)
var previous_mode: GameMode = GameMode.OVERWORLD

## Stack of modes for nested states (e.g., menu opened during combat)
var mode_stack: Array[GameMode] = []

## Whether a transition is currently in progress
var transition_in_progress: bool = false

## Data associated with the current mode (flexible dictionary for mode-specific info)
var current_mode_data: Dictionary = {}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## Whether to log mode changes for debugging
@export var enable_logging: bool = true

## Whether to allow mode changes during transitions
@export var allow_transitions_during_transition: bool = false

## Default transition type for mode changes
@export var default_transition_type: TransitionType = TransitionType.IMMEDIATE

# ==============================================================================
# LIFECYCLE METHODS
# ==============================================================================

func _ready() -> void:
	_log("Game State Manager initialized - Starting in OVERWORLD mode")
	
	# Initialize with overworld mode
	previous_mode = GameMode.OVERWORLD
	current_mode = GameMode.OVERWORLD
	
	# Connect to our own signals for internal logging
	if enable_logging:
		mode_changed.connect(_on_mode_changed_log)
		mode_transition_started.connect(_on_transition_started_log)
		mode_transition_completed.connect(_on_transition_completed_log)

# ==============================================================================
# PUBLIC MODE MANAGEMENT FUNCTIONS
# ==============================================================================

## Requests a change to a new game mode
## Returns true if the change was accepted, false if denied
func request_mode_change(new_mode: GameMode, mode_data: Dictionary = {}, 
	transition_type: TransitionType = default_transition_type) -> bool:
	# Validate the mode change request
	if not _can_change_mode(new_mode):
		return false
	
	# Store mode data for the new mode
	current_mode_data = mode_data
	
	# Start the transition
	_start_transition(current_mode, new_mode, transition_type)
	
	return true

## Forces a mode change without validation (use with caution)
func force_mode_change(new_mode: GameMode, mode_data: Dictionary = {}) -> void:
	_log("Force changing mode from %s to %s" % [
		GameMode.keys()[current_mode], 
		GameMode.keys()[new_mode]
	])
	current_mode_data = mode_data
	_change_mode(new_mode)

## Pushes a new mode onto the stack (for nested states like menus)
## The current mode is preserved and can be returned to with pop_mode()
func push_mode(new_mode: GameMode, mode_data: Dictionary = {}) -> bool:
	if not _can_change_mode(new_mode):
		return false
	
	# Push current mode onto stack
	mode_stack.push_back(current_mode)
	_log("Pushed %s onto mode stack" % GameMode.keys()[current_mode])
	
	# Change to new mode
	current_mode_data = mode_data
	_change_mode(new_mode)
	
	return true

## Pops the most recent mode from the stack and returns to it
## Returns true if successful, false if stack is empty
func pop_mode() -> bool:
	if mode_stack.is_empty():
		_log("Cannot pop mode - stack is empty")
		return false
	
	# Get the previous mode from stack
	var previous_stacked_mode = mode_stack.pop_back()
	_log("Popped %s from mode stack" % GameMode.keys()[previous_stacked_mode])
	
	# Return to that mode
	current_mode_data = {}  # Clear mode data when popping
	_change_mode(previous_stacked_mode)
	
	return true

## Clears the entire mode stack (emergency reset)
func clear_mode_stack() -> void:
	_log("Clearing mode stack (had %d entries)" % mode_stack.size())
	mode_stack.clear()

# ==============================================================================
# QUERY FUNCTIONS
# ==============================================================================

## Checks if the game is currently in the specified mode
func is_in_mode(mode: GameMode) -> bool:
	return current_mode == mode

## Checks if the game was previously in the specified mode
func was_in_mode(mode: GameMode) -> bool:
	return previous_mode == mode

## Gets the current mode as a string (useful for UI/debugging)
func get_current_mode_string() -> String:
	return GameMode.keys()[current_mode]

## Gets the previous mode as a string
func get_previous_mode_string() -> String:
	return GameMode.keys()[previous_mode]

## Checks if a mode change is currently in progress
func is_transitioning() -> bool:
	return transition_in_progress

## Gets the current mode data dictionary
func get_mode_data() -> Dictionary:
	return current_mode_data

## Gets a specific piece of mode data by key
func get_mode_data_value(key: String, default_value = null):
	return current_mode_data.get(key, default_value)

## Sets a value in the current mode data
func set_mode_data_value(key: String, value) -> void:
	current_mode_data[key] = value

# ==============================================================================
# VALIDATION FUNCTIONS
# ==============================================================================

## Determines if a mode change is allowed based on current state
func _can_change_mode(new_mode: GameMode) -> bool:
	# Cannot change to the same mode
	if new_mode == current_mode:
		_deny_mode_change(new_mode, "Already in requested mode")
		return false
	
	# Check if transitions are allowed during transitions
	if transition_in_progress and not allow_transitions_during_transition:
		_deny_mode_change(new_mode, "Transition already in progress")
		return false
	
	# Add any game-specific validation rules here
	# For example, certain modes might not be allowed from certain other modes
	
	return true

## Handles and logs denied mode changes
func _deny_mode_change(requested_mode: GameMode, reason: String) -> void:
	_log("Mode change denied: %s -> %s (Reason: %s)" % [
		GameMode.keys()[current_mode],
		GameMode.keys()[requested_mode],
		reason
	])
	mode_change_denied.emit(requested_mode, current_mode, reason)

# ==============================================================================
# TRANSITION SYSTEM
# ==============================================================================

## Starts a mode transition
func _start_transition(from_mode: GameMode, to_mode: GameMode, 
	transition_type: TransitionType) -> void:
	transition_in_progress = true
	mode_transition_started.emit(from_mode, to_mode, transition_type)
	
	# Handle different transition types
	match transition_type:
		TransitionType.IMMEDIATE:
			_change_mode(to_mode)
		TransitionType.FADE:
			# For now, treat fade as immediate - can be enhanced later
			_change_mode(to_mode)
		TransitionType.CUSTOM:
			# Custom transitions would be handled by external systems
			# They should call _complete_transition() when done
			pass

## Completes a transition (called internally or by external transition systems)
func _complete_transition(new_mode: GameMode) -> void:
	transition_in_progress = false
	mode_transition_completed.emit(new_mode)

## Internal method to actually change the mode
func _change_mode(new_mode: GameMode) -> void:
	var old_mode = current_mode
	previous_mode = current_mode
	current_mode = new_mode
	
	# Emit the mode change signal
	mode_changed.emit(old_mode, new_mode)
	
	# Complete transition if one was in progress
	if transition_in_progress:
		_complete_transition(new_mode)

# ==============================================================================
# LOGGING AND DEBUGGING
# ==============================================================================

## Internal logging function
func _log(message: String) -> void:
	if enable_logging:
		print("[GameState] %s" % message)

## Log mode changes
func _on_mode_changed_log(from_mode: GameMode, to_mode: GameMode) -> void:
	_log("Mode changed: %s -> %s" % [
		GameMode.keys()[from_mode], 
		GameMode.keys()[to_mode]
	])

## Log transition starts
func _on_transition_started_log(from_mode: GameMode, to_mode: GameMode, 
	transition_type: TransitionType) -> void:
	_log("Transition started: %s -> %s (%s)" % [
		GameMode.keys()[from_mode], 
		GameMode.keys()[to_mode], 
		TransitionType.keys()[transition_type]
	])

## Log transition completions
func _on_transition_completed_log(new_mode: GameMode) -> void:
	_log("Transition completed - now in %s mode" % 
		GameMode.keys()[new_mode])
