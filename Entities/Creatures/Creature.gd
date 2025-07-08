class_name Creature extends Entity

# ==============================================================================
# CREATURE SIGNALS
# ==============================================================================

## Signal fired when the creature learns a new understood language.
signal understood_language_learned(language: Language.Enum)

## Signal fired when the creature learns a new spoken language.
signal spoken_language_learned(language: Language.Enum)

# ==============================================================================
# CREATURE INTERNAL VARIABLES
# ==============================================================================

## Initialize the creature with a MovementController.
var movement_controller: MovementController

# ==============================================================================
# CREATURE EXPORTED VARIABLES
# ==============================================================================

@export_category("Creature Info")
## The name of the creature.
@export var display_name: String = ""
## The description of the creature.
@export_multiline var description: String = ""
## The portrait image of the creature.
@export var portrait_image: Texture2D = null

@export_category("Creature Details")
## The size of the creature.
@export var creature_size: CreatureSize.Enum = CreatureSize.Enum.Medium
## The type of the creature.
@export var creature_type: CreatureType.Enum = CreatureType.Enum.Humanoid

@export_category("Creature Movement")
## The default direction the creature should face when added to the scene.
@export var facing_direction: Direction.Enum = Direction.Enum.Down
## The base movement speed of the creature.
@export var movement_speed: float = 30.0

@export_category("Creature Communication")
## The languages the creature is able to understand.
@export var understood_languages: Array[Language.Enum] = [Language.Enum.Common]
## The languages the creature is able to speak.
@export var spoken_languages: Array[Language.Enum] = []

# ==============================================================================
# LIFECYCLE HOOKS
# ==============================================================================

# ==============================================================================
# PUBLIC FUNCTIONS
# ==============================================================================

## Sets the movement speed of the creature.
func set_movement_speed(speed: float) -> void:
	# Return early if the movement speed has not changed.
	if speed == self.movement_speed: return
	self.movement_speed = speed

## Teaches the creature how to understand a new language.
## Understood languages determine what languages the creature
## can read and understand in conversations with other creatures.
func learn_understood_language(language: Language.Enum) -> void:
	# Return early if the creature already understands the language.
	if language in self.understood_languages: return
	
	self.understood_languages.append(language)
	emit_signal("understood_language_learned", language)

## Teaches the creature how to speak a new language.
## Spoken languages determine what languages the creature
## can speak with in conversations with other creatures.
func learn_spoken_language(language: Language.Enum) -> void:
	# Return early if the creature already speaks the language.
	if language in self.spoken_languages: return
	
	self.spoken_languages.append(language)
	emit_signal("spoken_language_learned", language)
	
# ==============================================================================
# PRIVATE FUNCTIONS
# ==============================================================================
