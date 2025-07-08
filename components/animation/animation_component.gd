extends Node
class_name AnimationComponent

const Compass = preload("res://systems/movement/compass.gd").Compass

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var movement_component: MovementComponent = %MovementComponent

func _process(_delta: float) -> void:
	var facing: Compass = movement_component.facing_direction
	var velocity: Vector2 = movement_component.velocity
	var is_moving: bool = velocity.length_squared() > 0.0
	var is_sprinting: bool = movement_component.is_sprinting

	var anim_prefix: String = "walk"
	if is_moving and is_sprinting:
		anim_prefix = "sprint"

	var new_anim: String = ""

	if is_moving:
		match facing:
			Compass.N:
				new_anim = anim_prefix + "_north"
				sprite.scale.x = 1.0
			Compass.S:
				new_anim = anim_prefix + "_south"
				sprite.scale.x = 1.0
			Compass.E:
				new_anim = anim_prefix + "_sides"
				sprite.scale.x = 1.0
			Compass.W:
				new_anim = anim_prefix + "_sides"
				sprite.scale.x = -1.0
	else:
		match sprite.animation:
			"walk_north", "sprint_north":
				new_anim = "idle_north"
			"walk_south", "sprint_south":
				new_anim = "idle_south"
			"walk_sides", "sprint_sides":
				new_anim = "idle_sides"
			_:
				return  # Already idle or animation nonstandard

	# Only update animation if it actually changed
	if sprite.animation != new_anim:
		sprite.animation = new_anim
		sprite.play()

	# Pixel snapping
	sprite.position = sprite.position.round()
