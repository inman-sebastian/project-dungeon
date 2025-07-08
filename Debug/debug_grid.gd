extends Node2D
class_name DebugGrid

## The tilemap to render the debug grid for.
@export var tilemap: TileMapLayer

## The color of the debug grid lines.
@export var line_color: Color = Color(1, 1, 1, 0.2)

## The width of the debug grid lines.
@export var line_width: float = 0.5

## The Vector2i representing the size of each tile on the tilemap.
@onready var tile_size: Vector2i = tilemap.tile_set.tile_size

## The Vector2i representing the number of columns and rows in the tilemap.
## These values can be multiplied by the Vector2i values of the tile_size
## variable to determine the width and height of the tilemap node.
@onready var tilemap_size: Vector2i = tilemap.get_used_rect().size

## The Vector2i representing the origin point of the tilemap.
## This will be used to position the debug grid directly over the tilemap.
@onready var tilemap_origin: Vector2i = tilemap.get_used_rect().position

func _ready() -> void:
	global_position = tilemap.global_position
	queue_redraw()

func _process(_delta: float) -> void:
	if tilemap.get_used_rect().size != tilemap_size:
		tilemap_size = tilemap.get_used_rect().size
		queue_redraw()

func _draw() -> void:
	var start_x := tilemap_origin.x
	var start_y := tilemap_origin.y
	var end_x := start_x + tilemap_size.x
	var end_y := start_y + tilemap_size.y

	for x in range(start_x, end_x + 1):
		var x_pos := float(x * tile_size.x)
		draw_line(
			Vector2(x_pos, float(start_y * tile_size.y)),
			Vector2(x_pos, float(end_y * tile_size.y)),
			line_color,
			line_width
		)

	for y in range(start_y, end_y + 1):
		var y_pos := float(y * tile_size.y)
		draw_line(
			Vector2(float(start_x * tile_size.x), y_pos),
			Vector2(float(end_x * tile_size.x), y_pos),
			line_color,
			line_width
		)
