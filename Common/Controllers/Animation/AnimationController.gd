# ==============================================================================
# The AnimationController handles animation playback for entities in the world.
# It acts as an abstraction layer over AnimationPlayer and Sprite2D, allowing
# centralized control of animations and visual effects on the entity.
# ==============================================================================
class_name AnimationController
extends Controller

# ==============================================================================
# SIGNALS
# ==============================================================================

## Emitted when an animation starts playing.
signal animation_started(animation_name: StringName)

## Emitted when an animation finishes playing.
signal animation_finished(animation_name: StringName)

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

## Reference to the entity that this AnimationController is attached to.
@onready var entity: Entity = get_entity_owner()

## Reference to the AnimationPlayer node responsible for playing animations.
@onready var animation_player: AnimationPlayer = entity.get_node("Animations/AnimationPlayer")

## Reference to the AnimationTree node responsible for handling animation states.
@onready var animation_tree: AnimationTree = entity.get_node("Animations/AnimationTree")

## Reference to the Sprite2D node used to render the entity’s visual appearance.
@onready var sprite: Sprite2D = entity.get_node("Animations/Sprite")

# ==============================================================================
# LIFECYCLE HOOKS
# ==============================================================================

func _ready() -> void:
	# Register self with the entity if desired (optional).
	entity.animation_controller = self

	# Connect animation signals to forward them through this controller.
	animation_player.animation_started.connect(_on_animation_started)
	animation_player.animation_finished.connect(_on_animation_finished)

# ==============================================================================
# PUBLIC FUNCTIONS
# ==============================================================================

## Plays the specified animation if it exists.
## Optionally restarts the animation if it's already playing.
func play(animation_name: StringName, force_restart: bool = false) -> void:
	if not animation_player.has_animation(animation_name):
		push_warning("Tried to play non-existent animation: %s" % animation_name)
		return

	if animation_player.current_animation == animation_name and not force_restart:
		return

	animation_player.play(animation_name)

## Stops the currently playing animation.
func stop() -> void:
	animation_player.stop()

## Returns the name of the currently playing animation.
func get_current_animation() -> StringName:
	return animation_player.current_animation

## Checks whether the AnimationPlayer is currently playing any animation.
func is_playing() -> bool:
	return animation_player.is_playing()

## Flips the sprite horizontally.
func set_flip_h(flipped: bool) -> void:
	sprite.flip_h = flipped

## Flips the sprite vertically.
func set_flip_v(flipped: bool) -> void:
	sprite.flip_v = flipped

# ==============================================================================
# PRIVATE FUNCTIONS
# ==============================================================================

## Internal handler for when an animation starts.
func _on_animation_started(name: StringName) -> void:
	animation_started.emit(name)

## Internal handler for when an animation finishes.
func _on_animation_finished(name: StringName) -> void:
	animation_finished.emit(name)
