class_name Player extends Creature

# ==============================================================================
# PLAYER INPUT CONSTANTS
# ==============================================================================

const MovementInputDirection: Dictionary[StringName, Vector2] = {
	"move_n": Vector2.UP,
	"move_s": Vector2.DOWN,
	"move_e": Vector2.RIGHT,
	"move_w": Vector2.LEFT
}

# ==============================================================================
# PLAYER STATE VARIABLES
# ==============================================================================

## Track the last input direction to detect changes
var last_input_direction: Vector2 = Vector2.ZERO

## Buffer time to prevent state flicker between key presses
var input_buffer_time: float = 0.1
var input_buffer_timer: float = 0.0

## Whether input is currently enabled (based on game mode)
var input_enabled: bool = true

# ==============================================================================
# LIFECYCLE HOOKS
# ==============================================================================

func _ready() -> void:
	# Connect to movement controller signals
	movement_controller.movement_started.connect(_on_movement_started)
	movement_controller.movement_finished.connect(_on_movement_finished)
	movement_controller.state_changed.connect(_on_movement_state_changed)

	# Connect to game state changes
	GameState.mode_changed.connect(_on_game_mode_changed)

	# Set initial input state based on current game mode
	_update_input_state(GameState.current_mode)

func _process(delta: float) -> void:
	# Only handle input if it's enabled
	if input_enabled:
		_handle_movement_input(delta)

# ==============================================================================
# INPUT HANDLING
# ==============================================================================

func _handle_movement_input(delta: float) -> void:
	var input_direction = Vector2.ZERO

	# Get current input direction
	for action in MovementInputDirection.keys():
		if Input.is_action_pressed(action):
			input_direction = MovementInputDirection[action]
			animation_controller.animation_tree.set("parameters/Idle/blend_position", 
				input_direction)
			break  # Only process one direction at a time for cardinal movement

	# Handle input buffer timer
	if input_buffer_timer > 0.0:
		input_buffer_timer -= delta

	# Handle input changes
	if input_direction != last_input_direction:
		if input_direction == Vector2.ZERO:
			# Player stopped giving input - start buffer timer
			input_buffer_timer = input_buffer_time
		else:
			# Player started or changed direction
			input_buffer_timer = 0.0  # Clear buffer
			movement_controller.request_move(input_direction)
	elif (input_direction != Vector2.ZERO and 
		not movement_controller.is_moving()):
		# Continue moving in same direction, but only when not currently moving
		movement_controller.request_move(input_direction)
	
	# Check if buffer timer expired and we should stop movement
	if input_buffer_timer <= 0.0 and input_direction == Vector2.ZERO:
		if movement_controller.is_moving():
			movement_controller.request_stop()
		elif movement_controller.current_state != MovementController.MovementState.IDLE:
			# Ensure we go to idle when input stops and we're not moving
			movement_controller.request_stop()
	
	last_input_direction = input_direction

# ==============================================================================
# GAME STATE INTEGRATION
# ==============================================================================

## Responds to game mode changes and updates input behavior accordingly
func _on_game_mode_changed(from_mode: GameState.GameMode, 
	to_mode: GameState.GameMode) -> void:
	print("[Player] Game mode changed: %s -> %s" % [
		GameState.GameMode.keys()[from_mode], 
		GameState.GameMode.keys()[to_mode]
	])

	_update_input_state(to_mode)

## Updates input enabled state based on the current game mode
func _update_input_state(mode: GameState.GameMode) -> void:
	var previous_input_enabled = input_enabled
	
	match mode:
		GameState.GameMode.OVERWORLD:
			input_enabled = true

		GameState.GameMode.COMBAT:
			# In combat, input is managed by the combat system
			# Player can still move during their turn, but it's controlled differently
			input_enabled = false

		GameState.GameMode.DIALOGUE:
			# During dialogue, movement should be disabled
			input_enabled = false

		GameState.GameMode.MENU:
			# During menus, movement should be disabled
			input_enabled = false

		GameState.GameMode.CUTSCENE:
			# During cutscenes, all player input should be disabled
			input_enabled = false

		GameState.GameMode.TRANSITION:
			# During transitions, input should be disabled
			input_enabled = false

		GameState.GameMode.PAUSED:
			# When paused, input should be disabled
			input_enabled = false
	
	# If input was just disabled, stop any current movement
	if previous_input_enabled and not input_enabled:
		_stop_current_movement()
		print("[Player] Input disabled for mode: %s" % 
			GameState.GameMode.keys()[mode])
	elif not previous_input_enabled and input_enabled:
		print("[Player] Input enabled for mode: %s" % 
			GameState.GameMode.keys()[mode])

## Stops current movement when input is disabled
func _stop_current_movement() -> void:
	# Clear input buffers
	last_input_direction = Vector2.ZERO
	input_buffer_timer = 0.0

	# Stop any current movement
	if movement_controller.is_moving():
		movement_controller.request_stop()

# ==============================================================================
# PUBLIC FUNCTIONS FOR EXTERNAL SYSTEMS
# ==============================================================================

## Allows external systems (like combat) to temporarily override input
func set_input_override(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		_stop_current_movement()

## Gets the current input enabled state
func is_input_enabled() -> bool:
	return input_enabled

# ==============================================================================
# MOVEMENT CONTROLLER EVENT HANDLERS
# ==============================================================================

func _on_movement_started() -> void:
	print("[Player] Movement started")

func _on_movement_finished() -> void:
	print("[Player] Movement finished")

func _on_movement_state_changed(state: MovementController.MovementState):
	print("[Player] Movement state changed: ", state)
