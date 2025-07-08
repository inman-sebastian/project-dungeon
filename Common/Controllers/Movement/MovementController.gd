# ============================================================================== 
# The MovementController handles the calculations and logic involved with moving
# creatures within the game world. Movement within the game is grid based and is
# dependent on the size of the tiles in the world grid.
# ============================================================================== 

class_name MovementController extends Controller

# ============================================================================== 
# ENUMS
# ==============================================================================

enum MovementState { LOCKED, IDLE, MOVING }

## Different movement modes based on game state
enum MovementMode {
	FREE,           # Unlimited movement (overworld exploration)
	TURN_BASED,     # Limited movement with turn constraints (combat)
	DISABLED        # No movement allowed (dialogue, menus, cutscenes)
}

# ============================================================================== 
# SIGNALS
# ==============================================================================

## Emitted when the movement state of the creature changes.
signal state_changed(state: MovementState)

## Emitted when the movement mode changes due to game state
signal movement_mode_changed(old_mode: MovementMode, new_mode: MovementMode)

## Emitted when the creature begins moving from one tile to another.
signal movement_started()

## Emitted when the creature finishes its current tile movement.
signal movement_finished()

# ============================================================================== 
# CONSTANTS
# ==============================================================================

## The size (in pixels) of each tile in the world grid.
## Used to determine distances and movement targets relative to grid alignment.
const TILE_SIZE: int = Global.WORLD_GRID_TILE_SIZE

## Cardinal directions only (no diagonal movement)
const CARDINAL_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,    # North
	Vector2.DOWN,  # South
	Vector2.LEFT,  # West
	Vector2.RIGHT  # East
]

# ============================================================================== 
# INTERNAL STATE
# ==============================================================================

## The parent Entity that contains this MovementController.
@onready var creature: Creature = get_entity_owner()

## The current movement state of the creature.
## The current state is used to determine how and when to move the creature.
## For example, if the creature is currently idle then begins movement, we first
## turn the creature to face the desired direction, check to see if it's able to
## move to the target tile, then move the creature to the target tile.
@export var current_state: MovementState = MovementState.IDLE:
	set(state): 
		if current_state != state:
			current_state = state
			state_changed.emit(state)
			if state == MovementState.IDLE:   movement_finished.emit()
			if state == MovementState.MOVING: movement_started.emit()

## Current movement mode based on game state
@export var current_mode: MovementMode = MovementMode.FREE:
	set(mode):
		if current_mode != mode:
			var old_mode = current_mode
			current_mode = mode
			movement_mode_changed.emit(old_mode, mode)
			_on_movement_mode_changed(old_mode, mode)

## The target position the creature is currently moving toward
var target_position: Vector2

## The starting position of the current movement
var start_position: Vector2

## The direction of current movement
var current_direction: Vector2 = Vector2.ZERO

## The direction the player wants to move next (for queuing direction changes)
var queued_direction: Vector2 = Vector2.ZERO

## Internal flag to track if we're in the middle of a grid movement
var is_grid_moving: bool = false

## Turn-based movement constraints (for combat mode)
var movement_points_remaining: int = 0
var max_movement_points: int = 6  # Default: 30 feet = 6 tiles in D&D 5e

# ============================================================================== 
# LIFECYCLE HOOKS
# ==============================================================================

func _ready() -> void:
	# Assign the movement controller to the creature.
	creature.movement_controller = self
	# Snap creature to grid on start
	snap_to_grid()
	
	# Connect to game state changes
	GameState.mode_changed.connect(_on_game_mode_changed)
	
	# Set initial movement mode based on current game state
	_update_movement_mode(GameState.current_mode)

func _physics_process(delta: float) -> void:
	# Return early if movement is disabled or locked
	if current_mode == MovementMode.DISABLED or current_state == MovementState.LOCKED:
		return
	
	# Handle grid-based movement
	if is_grid_moving:
		_process_grid_movement(delta)
	
	# Apply physics movement
	var has_collision = creature.move_and_slide()
	if has_collision:
		# Handle collision during grid movement
		if is_grid_moving:
			_handle_movement_collision()

# ============================================================================== 
# PUBLIC FUNCTIONS
# ==============================================================================

## Requests movement in a direction (can be queued if currently moving)
func request_move(direction: Vector2) -> void:
	# Check if movement is allowed in current mode
	if not _can_move_in_current_mode():
		return
		
	if current_state == MovementState.LOCKED:
		return
		
	var normalized_direction = _get_cardinal_direction(direction)
	if normalized_direction == Vector2.ZERO:
		return
	
	# Check turn-based movement constraints
	if current_mode == MovementMode.TURN_BASED and not _can_move_turn_based():
		return
	
	if not is_grid_moving:
		# Not moving - start immediately
		_try_start_movement(normalized_direction)
	else:
		# Currently moving - queue the direction change
		queued_direction = normalized_direction

## Requests to stop movement (will complete current tile movement first)
func request_stop() -> void:
	queued_direction = Vector2.ZERO
	if not is_grid_moving:
		# Not currently moving, go idle immediately
		current_state = MovementState.IDLE

## Snaps the creature to the nearest grid position
func snap_to_grid() -> void:
	var grid_pos = world_to_grid(creature.global_position)
	var target_world_pos = grid_to_world(grid_pos)
	creature.global_position = target_world_pos

## Converts world coordinates to grid coordinates
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		roundi((world_pos.x - Global.WORLD_GRID_TILE_CENTER_OFFSET) / TILE_SIZE),
		roundi((world_pos.y - Global.WORLD_GRID_TILE_CENTER_OFFSET) / TILE_SIZE)
	)

## Converts grid coordinates to world coordinates (centered on tile)
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * TILE_SIZE + Global.WORLD_GRID_TILE_CENTER_OFFSET,
		grid_pos.y * TILE_SIZE + Global.WORLD_GRID_TILE_CENTER_OFFSET
	)

## Gets the current grid position of the creature
func get_grid_position() -> Vector2i:
	return world_to_grid(creature.global_position)

## Checks if the creature can move in the given direction
func can_move(direction: Vector2) -> bool:
	if not _can_move_in_current_mode():
		return false
		
	if current_state == MovementState.LOCKED:
		return false
	
	var normalized_direction = _get_cardinal_direction(direction)
	if normalized_direction == Vector2.ZERO:
		return false
	
	# Check turn-based constraints
	if current_mode == MovementMode.TURN_BASED and not _can_move_turn_based():
		return false
	
	# If currently moving, can only queue a different direction
	if is_grid_moving:
		return normalized_direction != current_direction
	
	# Check if target position is valid
	var current_grid_pos = get_grid_position()
	var target_grid_pos = current_grid_pos + Vector2i(normalized_direction)
	
	return _is_valid_target_position(target_grid_pos)

## Checks if the creature is currently moving between tiles
func is_moving() -> bool:
	return is_grid_moving

## Forces immediate stop (use with caution - can break grid alignment)
func force_stop() -> void:
	creature.velocity = Vector2.ZERO
	is_grid_moving = false
	queued_direction = Vector2.ZERO
	current_state = MovementState.IDLE

# ==============================================================================
# TURN-BASED MOVEMENT FUNCTIONS (FOR COMBAT)
# ==============================================================================

## Sets the maximum movement points for turn-based mode
func set_max_movement_points(points: int) -> void:
	max_movement_points = points
	movement_points_remaining = points

## Resets movement points to maximum (call at start of turn)
func reset_movement_points() -> void:
	movement_points_remaining = max_movement_points

## Gets remaining movement points
func get_movement_points_remaining() -> int:
	return movement_points_remaining

## Gets maximum movement points
func get_max_movement_points() -> int:
	return max_movement_points

## Checks if creature can move in turn-based mode
func _can_move_turn_based() -> bool:
	return movement_points_remaining > 0

## Consumes a movement point when moving in turn-based mode
func _consume_movement_point() -> void:
	if current_mode == MovementMode.TURN_BASED:
		movement_points_remaining = max(0, movement_points_remaining - 1)

# ==============================================================================
# GAME STATE INTEGRATION
# ==============================================================================

## Responds to game mode changes and updates movement behavior
func _on_game_mode_changed(from_mode: GameState.GameMode, to_mode: GameState.GameMode) -> void:
	_update_movement_mode(to_mode)

## Updates movement mode based on game state
func _update_movement_mode(game_mode: GameState.GameMode) -> void:
	var new_mode: MovementMode
	
	match game_mode:
		GameState.GameMode.OVERWORLD:
			new_mode = MovementMode.FREE

		GameState.GameMode.COMBAT:
			new_mode = MovementMode.TURN_BASED
			# Reset movement points when entering combat
			reset_movement_points()

		GameState.GameMode.DIALOGUE, GameState.GameMode.MENU:
			new_mode = MovementMode.DISABLED 

		GameState.GameMode.CUTSCENE, GameState.GameMode.TRANSITION:
			new_mode = MovementMode.DISABLED

		GameState.GameMode.PAUSED:
			new_mode = MovementMode.DISABLED

		_:
			new_mode = MovementMode.FREE
	
	current_mode = new_mode

## Handles movement mode changes
func _on_movement_mode_changed(old_mode: MovementMode, new_mode: MovementMode) -> void:
	# Stop current movement when switching to disabled mode
	if new_mode == MovementMode.DISABLED:
		force_stop()
	
	# Handle mode-specific setup
	match new_mode:
		MovementMode.TURN_BASED:
			# Set up turn-based movement (movement points based on creature stats)
			var creature_speed = creature.movement_speed
			var movement_tiles = int(creature_speed / 5)  # D&D 5e: 5 feet per tile
			set_max_movement_points(movement_tiles)
			
		MovementMode.FREE:
			# No restrictions for free movement
			pass
			
		MovementMode.DISABLED:
			# Movement is completely disabled
			pass

## Checks if movement is allowed in the current mode
func _can_move_in_current_mode() -> bool:
	return current_mode != MovementMode.DISABLED

# ============================================================================== 
# PRIVATE FUNCTIONS
# ==============================================================================

## Constrains input direction to cardinal directions only
func _get_cardinal_direction(input_direction: Vector2) -> Vector2:
	if input_direction.length() < 0.1:
		return Vector2.ZERO
	
	# Find the closest cardinal direction
	var best_direction = Vector2.ZERO
	var best_dot = -1.0
	
	for cardinal_dir in CARDINAL_DIRECTIONS:
		var dot = input_direction.normalized().dot(cardinal_dir)
		if dot > best_dot:
			best_dot = dot
			best_direction = cardinal_dir
	
	# Only return direction if it's reasonably close to cardinal
	if best_dot > 0.7:  # Roughly 45 degrees tolerance
		return best_direction
	
	return Vector2.ZERO

## Starts movement toward a target grid position
func _start_grid_movement(direction: Vector2) -> void:
	current_direction = direction
	start_position = creature.global_position
	target_position = start_position + (direction * TILE_SIZE)
	is_grid_moving = true
	
	# Consume movement point for turn-based mode
	_consume_movement_point()
	
	# Set movement state to MOVING when we start any grid movement
	if current_state == MovementState.IDLE:
		current_state = MovementState.MOVING

## Processes grid-based movement during physics update
func _process_grid_movement(delta: float) -> void:
	if not is_grid_moving:
		return
	
	# Check if movement should be stopped due to state/mode changes
	if current_state == MovementState.LOCKED or current_mode == MovementMode.DISABLED:
		force_stop()
		return
	
	# Safety check for movement speed
	if creature.movement_speed <= 0.0:
		force_stop()
		return
	
	# Calculate movement progress based on actual distance covered
	var distance_to_target = creature.global_position.distance_to(target_position)
	
	# Check if we've reached the target (with small tolerance)
	if distance_to_target <= 1.0:  # 1 pixel tolerance
		# Movement complete - snap to exact target position
		creature.velocity = Vector2.ZERO
		is_grid_moving = false
		
		# Force exact positioning to maintain grid alignment
		creature.global_position = target_position
		
		# Check if we have a queued direction change
		if queued_direction != Vector2.ZERO:
			var next_direction = queued_direction
			queued_direction = Vector2.ZERO
			# Start next movement immediately if allowed
			if (_can_move_in_current_mode() and 
				(current_mode != MovementMode.TURN_BASED or _can_move_turn_based())):
				_try_start_movement(next_direction)
	else:
		# Continue movement toward target
		var direction_to_target = (target_position - creature.global_position).normalized()
		creature.velocity = direction_to_target * creature.movement_speed

## Internal function to try starting movement in a direction
func _try_start_movement(direction: Vector2) -> void:
	if (current_state == MovementState.LOCKED or 
		not _can_move_in_current_mode()):
		return
	
	# Calculate target grid position
	var current_grid_pos = world_to_grid(creature.global_position)
	var target_grid_pos = current_grid_pos + Vector2i(direction)
	
	# Check if target position is valid
	if not _is_valid_target_position(target_grid_pos):
		return
	
	# Start movement
	_start_grid_movement(direction)

## Handles collision during movement (snaps to grid and stops)
func _handle_movement_collision() -> void:
	# If we hit something during movement, stop and snap to nearest grid position
	creature.velocity = Vector2.ZERO
	is_grid_moving = false
	queued_direction = Vector2.ZERO
	snap_to_grid()
	current_state = MovementState.IDLE

## Validates if a target grid position is valid for movement
func _is_valid_target_position(grid_pos: Vector2i) -> bool:
	# Add your validation logic here, such as:
	# - Bounds checking
	# - Collision detection with other entities
	# - Wall/obstacle checking
	# - etc.
	
	# For now, just return true (you'll need to implement your specific logic)
	return true
