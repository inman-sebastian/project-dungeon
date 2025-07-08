# ============================================================================== 
# The MovementController handles the calculations and logic involved with moving
# creatures within the game world. Movement within the game is grid based and is
# dependent on the size of the tiles in the world grid.
# ============================================================================== 

class_name MovementController extends Controller

# ============================================================================== 
# ENUMS
# ==============================================================================

enum MovementState { Locked, Idle, Moving }

# ============================================================================== 
# SIGNALS
# ==============================================================================

## Emitted when the movement state of the creature changes.
signal state_changed(state: MovementState)

## Emitted when the creature begins moving from one tile to another.
signal movement_started()

## Emitted when the creature finishes its current tile movement.
signal movement_finished()

# ## Emitted when the creature's movement is interrupted.
# ## This can happen if the target tile is already occupied by another entity.
# signal movement_interrupted()

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
var current_state: MovementState = MovementState.Idle:
	set(state): 
		if current_state != state:
			current_state = state
			state_changed.emit(state)
			if state == MovementState.Idle:   movement_finished.emit()
			if state == MovementState.Moving: movement_started.emit()

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

# ============================================================================== 
# LIFECYCLE HOOKS
# ==============================================================================

func _ready() -> void:
	# Assign the movement controller to the creature.
	creature.movement_controller = self
	# Snap creature to grid on start
	snap_to_grid()

func _physics_process(delta: float) -> void:
	# Return early if creature movement is locked.
	if current_state == MovementState.Locked: return
	
	# Handle grid-based movement
	if is_grid_moving:
		_process_grid_movement(delta)
	
	# Apply physics movement
	var has_collision = creature.move_and_slide()
	if has_collision:
		print("has_collision")
		# Handle collision during grid movement
		if is_grid_moving:
			_handle_movement_collision()

# ============================================================================== 
# PUBLIC FUNCTIONS
# ==============================================================================

## Requests movement in a direction (can be queued if currently moving)
func request_move(direction: Vector2) -> void:
	if current_state == MovementState.Locked:
		return
		
	var normalized_direction = _get_cardinal_direction(direction)
	if normalized_direction == Vector2.ZERO:
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
		current_state = MovementState.Idle

## Snaps the creature to the nearest grid position
func snap_to_grid() -> void:
	var grid_pos = world_to_grid(creature.global_position)
	var target_world_pos = grid_to_world(grid_pos)
	creature.global_position = target_world_pos

## Converts world coordinates to grid coordinates
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		roundi(world_pos.x / TILE_SIZE),
		roundi(world_pos.y / TILE_SIZE)
	)

## Converts grid coordinates to world coordinates
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * TILE_SIZE,
		grid_pos.y * TILE_SIZE
	)

## Gets the current grid position of the creature
func get_grid_position() -> Vector2i:
	return world_to_grid(creature.global_position)

## Checks if the creature can move in the given direction
func can_move(direction: Vector2) -> bool:
	if current_state == MovementState.Locked:
		return false
	
	var normalized_direction = _get_cardinal_direction(direction)
	if normalized_direction == Vector2.ZERO:
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
	current_state = MovementState.Idle

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
	
	# Set movement state to Moving when we start any grid movement
	if current_state == MovementState.Idle:
		current_state = MovementState.Moving

## Processes grid-based movement during physics update
func _process_grid_movement(delta: float) -> void:
	if not is_grid_moving:
		return
	
	# Safety check for movement speed
	if creature.movement_speed <= 0.0:
		print("Warning: movement_speed is zero or negative, stopping movement")
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
			# Start next movement immediately
			_try_start_movement(next_direction)
		# Note: Don't change state here - let external logic handle when to go idle
	else:
		# Continue movement toward target
		var direction_to_target = (target_position - creature.global_position).normalized()
		creature.velocity = direction_to_target * creature.movement_speed

## Internal function to try starting movement in a direction
func _try_start_movement(direction: Vector2) -> void:
	if current_state == MovementState.Locked:
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
	current_state = MovementState.Idle
	print("Movement interrupted by collision, snapped to grid")

## Validates if a target grid position is valid for movement
func _is_valid_target_position(grid_pos: Vector2i) -> bool:
	# Add your validation logic here, such as:
	# - Bounds checking
	# - Collision detection with other entities
	# - Wall/obstacle checking
	# - etc.
	
	# For now, just return true (you'll need to implement your specific logic)
	return true
