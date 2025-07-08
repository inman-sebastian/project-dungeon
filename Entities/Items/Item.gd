extends Resource
class_name Item

@export_category("Item Details")
@export var name: String = ""
@export_multiline var description: String = ""
@export var tags: Array[String] = []

@export_category("Item Stacks")
@export var weight: float = 0.0
@export var max_stack_size: int = 1

var amount: int = 1

func is_stackable() -> bool:
	return max_stack_size > 1
