extends Resource
class_name RollResult

# ==============================================================================
# ROLL RESULT DATA STRUCTURE
# ==============================================================================
# This class contains comprehensive information about a dice roll result,
# including the raw dice values, modifiers applied, success/failure status,
# and detailed breakdown information for logging and UI display.
# ==============================================================================

# ==============================================================================
# BASIC ROLL INFORMATION
# ==============================================================================

## The type of roll that was performed (attack, save, etc.)
@export var roll_type: Dice.RollType = Dice.RollType.CUSTOM

## The final calculated result (total of all dice + modifiers)
@export var total: int = 0

## The modifier applied to the roll (positive or negative)
@export var modifier: int = 0

## The advantage/disadvantage state used for this roll
@export var advantage_state: Dice.AdvantageState = Dice.AdvantageState.NORMAL

## When this roll was made (for debugging and logging)
@export var timestamp: float = 0.0

# ==============================================================================
# DICE ROLL DETAILS
# ==============================================================================

## All individual dice results that contributed to the total
## For advantage/disadvantage, includes both d20 results
@export var dice_rolled: Array = []

## Number of sides on each die rolled
@export var die_sides: int = 20

## Number of dice rolled (usually 1 for d20 rolls, multiple for damage)
@export var die_count: int = 1

## For percentile dice (d100): the tens component (0, 10, 20, ..., 90)
@export var percentile_tens: int = -1

## For percentile dice (d100): the ones component (0, 1, 2, ..., 9)  
@export var percentile_ones: int = -1

# ==============================================================================
# SUCCESS/FAILURE INFORMATION
# ==============================================================================

## The target number this roll was compared against (DC, AC, etc.)
## -1 means no target was set (like damage rolls)
@export var target_number: int = -1

## Whether this roll met or exceeded the target number
@export var success: bool = false

## Whether this roll was a critical success (natural 20 for d20 rolls)
@export var critical_success: bool = false

## Whether this roll was a critical failure (natural 1 for d20 rolls)
@export var critical_failure: bool = false

# ==============================================================================
# DETAILED BREAKDOWN INFORMATION
# ==============================================================================

## Human-readable description of what was rolled
@export var description: String = ""

## Detailed breakdown showing dice + modifiers for logging
@export var breakdown: String = ""

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

## Returns the raw dice result before any modifiers were applied
func get_raw_dice_total() -> int:
	return total - modifier

## Returns the highest individual die rolled (useful for advantage/crits)
func get_highest_die() -> int:
	if dice_rolled.is_empty():
		return 0
	return dice_rolled.max()

## Returns the lowest individual die rolled (useful for disadvantage)
func get_lowest_die() -> int:
	if dice_rolled.is_empty():
		return 0
	return dice_rolled.min()

## Checks if this was a natural 20 on a d20 roll
func is_natural_20() -> bool:
	return die_sides == 20 and get_highest_die() == 20

## Checks if this was a natural 1 on a d20 roll  
func is_natural_1() -> bool:
	return die_sides == 20 and dice_rolled.has(1)

## Returns whether this roll involved percentile dice
func is_percentile_roll() -> bool:
	return percentile_tens >= 0 and percentile_ones >= 0

## Generates a detailed string representation for logging
func to_detailed_string() -> String:
	if breakdown.is_empty():
		return "Roll: %d" % total
	return "%s = %d" % [breakdown, total]
