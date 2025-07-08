# ============================================================================== 
# The Controller base class provides a foundational interface for all controller
# nodes that are attached to game entities (e.g. creatures, players, NPCs, etc.).
# 
# Controllers are modular nodes responsible for handling specific domains of
# behavior, such as movement, input, animation, or interaction logic.
# 
# All controller nodes are expected to be children (direct or nested) of a
# scene that inherits from the Entity class. This ensures consistent structure
# and allows each controller to reliably locate and reference its owning entity.
# 
# This base class provides utility functions shared by all controller types,
# such as safe and type-checked access to their parent entity.
# ============================================================================== 

class_name Controller extends Node2D

# ============================================================================== 
# SIGNALS
# ==============================================================================

## Emitted when the controller connects to its owner entity.
## TODO: Incorporate this into the Controller class.
signal controller_connected()

# ============================================================================== 
# PUBLIC FUNCTIONS
# ==============================================================================

## Returns a reference to the Entity node that owns this controller.
##
## All controller nodes must be children (direct or nested) of a node that
## inherits from the Entity base class. This method locates the owning Entity
## by calling `get_owner()` on the scene root and asserting that it is a valid
## instance of Entity.
##
## If the owning node is not an Entity, the game will crash with a clear error.
##
## This function guarantees type safety when referencing the parent entity from
## any child controller, and should be used in `_ready()` to bind the controller
## to its parent logic.
func get_entity_owner() -> Entity:
	var root_node: Node = get_owner()
	assert(root_node is Entity, "Controller must be a child of an Entity node")
	return root_node as Entity
