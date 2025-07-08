extends Node2D
class_name InteractionComponent

const Compass = preload("res://systems/movement/compass.gd").Compass
const Direction = preload("res://systems/movement/compass.gd").Direction

signal interactable_changed(previous: Node, current: Node)
signal interacted(target: Node)

@export var interaction_distance: float = 12.0
@export var origin_offset: Vector2 = Vector2(0, -6)  # Matches the sprite Y shift
@export var facing_direction: Vector2 = Direction[Compass.S]
@export var show_debug_ray: bool = true
@export var ray_color: Color = Color(1, 0, 0.5, 0.5)
@export var ray_thickness: float = 1.0
@export var entity_size: Vector2 = Vector2(16, 16) # Can be overridden per entity

@onready var owner_node: Node2D = get_owner()

var current_interactable: Node = null

func _physics_process(_delta: float) -> void:
	global_position = owner_node.global_position

	var origin: Vector2 = global_position + origin_offset
	var target_pos: Vector2 = origin + (facing_direction * interaction_distance)

	var space_state := get_viewport().world_2d.direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, target_pos)
	query.exclude = [owner_node]
	query.collision_mask = 1 << 0

	var result := space_state.intersect_ray(query)
	var target: Node = null

	if result.has("collider") and result.collider.has_method("on_interact"):
		target = result.collider

	if target != current_interactable:
		var previous := current_interactable
		current_interactable = target
		emit_signal("interactable_changed", previous, current_interactable)

	if show_debug_ray:
		queue_redraw()

func _draw() -> void:
	if not show_debug_ray: return

	var origin: Vector2 = origin_offset
	var target: Vector2 = origin + (facing_direction * interaction_distance)

	draw_line(origin, target, ray_color, ray_thickness)

func set_facing_direction(direction: Vector2, distance: int) -> void:
	if direction == Vector2.ZERO: return
	
	facing_direction = direction
	interaction_distance = float(distance)
	queue_redraw()
