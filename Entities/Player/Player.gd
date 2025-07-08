class_name Player extends Creature

const MovementInputDirection: Dictionary[StringName, Vector2] = {
	"move_n": Vector2.UP,
	"move_s": Vector2.DOWN,
	"move_e": Vector2.RIGHT,
	"move_w": Vector2.LEFT
}

## Track the last input direction to detect changes
var last_input_direction: Vector2 = Vector2.ZERO

## Buffer time to prevent state flicker between key presses
var input_buffer_time: float = 0.1
var input_buffer_timer: float = 0.0

func _ready() -> void:
	movement_controller.movement_started.connect(_on_movement_started)
	movement_controller.movement_finished.connect(_on_movement_finished)
	movement_controller.state_changed.connect(_on_movement_state_changed)

func _process(delta: float) -> void:
	_handle_movement_input(delta)

func _handle_movement_input(delta: float) -> void:
	var input_direction = Vector2.ZERO

	# Get current input direction
	for action in MovementInputDirection.keys():
		if Input.is_action_pressed(action):
			input_direction = MovementInputDirection[action]
			animation_controller.animation_tree.set("parameters/Idle/blend_position", input_direction)
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
	elif input_direction != Vector2.ZERO and not movement_controller.is_moving():
		# Continue moving in same direction, but only when not currently moving
		movement_controller.request_move(input_direction)
	
	# Check if buffer timer expired and we should stop movement
	if input_buffer_timer <= 0.0 and input_direction == Vector2.ZERO:
		if movement_controller.is_moving():
			movement_controller.request_stop()
		elif movement_controller.current_state != MovementController.MovementState.Idle:
			# Ensure we go to idle when input stops and we're not moving
			movement_controller.request_stop()
	
	last_input_direction = input_direction

func _on_movement_started() -> void:
	print("movement started")

func _on_movement_finished() -> void:
	print("movement finished")

func _on_movement_state_changed(state: MovementController.MovementState):
	print("state changed: ", state)
