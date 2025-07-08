extends Resource
class_name GameStateTransition

# ==============================================================================
# TRANSITION DATA RESOURCE
# ==============================================================================
# Data structure for storing information about mode transitions.
# Can be used to pass context and configuration for complex transitions
# between different game modes.
# ==============================================================================

# ==============================================================================
# BASIC TRANSITION INFORMATION
# ==============================================================================

## The game mode we're transitioning from
@export var from_mode: GameState.GameMode

## The game mode we're transitioning to  
@export var to_mode: GameState.GameMode

## The type of transition to perform
@export var transition_type := GameState.TransitionType.IMMEDIATE

## Duration of the transition in seconds (for timed transitions)
@export var duration: float = 0.5

# ==============================================================================
# TRANSITION CONFIGURATION
# ==============================================================================

## Whether to preserve entity positions during the transition (useful for combat)
@export var preserve_positions: bool = false

## Whether to preserve camera position/target during transition
@export var preserve_camera: bool = false

## Whether to pause time progression during the transition
@export var pause_time: bool = false

## Whether to disable input during the transition
@export var disable_input: bool = false

# ==============================================================================
# TRANSITION DATA PAYLOAD
# ==============================================================================

## Flexible dictionary for passing mode-specific data during transitions
## Examples:
## - Combat: enemy data, encounter type, initiative modifiers
## - Dialogue: NPC reference, conversation tree, mood
## - Menu: which menu to open, previous context
@export var transition_data: Dictionary = {}

## Optional scene path if the transition requires a scene change
@export var scene_path: String = ""

## Optional callback function name to call after transition completes
@export var completion_callback: String = ""

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

## Creates a basic transition data for immediate mode changes
static func create_immediate(
	to_mode: GameState.GameMode, 
	data: Dictionary = {}
) -> GameStateTransition:
	var transition = GameStateTransition.new()
	transition.to_mode = to_mode
	transition.transition_type = GameState.TransitionType.IMMEDIATE
	transition.transition_data = data
	return transition

## Creates a fade transition data
static func create_fade(
	to_mode: GameState.GameMode, 
	fade_duration: float = 0.5, 
	data: Dictionary = {}
) -> GameStateTransition:
	var transition = GameStateTransition.new()
	transition.to_mode = to_mode
	transition.transition_type = GameState.TransitionType.FADE
	transition.duration = fade_duration
	transition.transition_data = data
	return transition

## Creates a combat transition that preserves positions
static func create_combat_transition(
	enemy_data: Dictionary = {}
) -> GameStateTransition:
	var transition = GameStateTransition.new()
	transition.to_mode = GameState.GameMode.COMBAT
	transition.transition_type = GameState.TransitionType.IMMEDIATE
	transition.preserve_positions = true
	transition.preserve_camera = false  # Camera will switch to turn-based mode
	transition.pause_time = true
	transition.transition_data = enemy_data
	return transition

## Creates a menu transition that can return to the previous mode
static func create_menu_transition(
	menu_type: String = "main"
) -> GameStateTransition:
	var transition = GameStateTransition.new()
	transition.to_mode = GameState.GameMode.MENU
	transition.transition_type = GameState.TransitionType.IMMEDIATE
	transition.preserve_positions = true
	transition.preserve_camera = true
	transition.transition_data = {"menu_type": menu_type}
	return transition

## Gets a value from the transition data dictionary
func get_data_value(key: String, default_value = null):
	return transition_data.get(key, default_value)

## Sets a value in the transition data dictionary
func set_data_value(key: String, value) -> void:
	transition_data[key] = value

## Checks if the transition data contains a specific key
func has_data_key(key: String) -> bool:
	return transition_data.has(key)

## Returns a human-readable description of the transition
func get_description() -> String:
	return "Transition: %s -> %s (%s)" % [
		GameState.GameMode.keys()[from_mode] if from_mode != null else "Unknown",
		GameState.GameMode.keys()[to_mode] if to_mode != null else "Unknown", 
		GameState.TransitionType.keys()[transition_type] if transition_type != null else "Unknown"
	]
