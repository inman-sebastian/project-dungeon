extends TileMapLayer
class_name Stage

@export_category("Stage Details")
## The name of the stage.
@export var stage_name: String
## The size of each tile in the world grid.
@export var tile_size: int = 16

@export_category("TimeController Overrides")
@export var time_of_day_gradient: Gradient

func _ready() -> void:
	if self.tile_set:
		self.tile_set.tile_size = Vector2i(self.tile_size, self.tile_size)
		TimeController.current_day
