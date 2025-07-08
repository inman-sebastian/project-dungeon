extends Node

# ==============================================================================
# DICE ROLLER SINGLETON
# ==============================================================================
# Global dice rolling system for D&D 5e mechanics. Handles all types of dice
# rolls including advantage/disadvantage, percentile dice, and provides detailed
# result tracking for combat logs and debugging.
#
# This singleton is autoloaded as "Dice" and accessible throughout the project.
# ==============================================================================

# ==============================================================================
# ENUMS
# ==============================================================================

## Types of rolls that can be performed in the dice system.
## Used to categorize and handle different roll mechanics appropriately.
enum RollType {
	ABILITY_CHECK,    # Ability score checks (Strength, Dexterity, etc.)
	ATTACK_ROLL,      # Attack rolls against AC
	SAVING_THROW,     # Saving throws against spell/effect DCs
	DAMAGE_ROLL,      # Damage dice for weapons, spells, etc.
	INITIATIVE,       # Initiative rolls for combat order
	SKILL_CHECK,      # Skill-based ability checks
	DEATH_SAVE,       # Death saving throws (special rules)
	CUSTOM           # Generic rolls for other purposes
}

## Advantage/disadvantage states as per D&D 5e rules.
## Determines how many d20s to roll and which result to use.
enum AdvantageState {
	NORMAL,          # Roll 1d20
	ADVANTAGE,       # Roll 2d20, take higher
	DISADVANTAGE     # Roll 2d20, take lower
}

## Logging levels for dice roll output and debugging.
## Controls how much detail is recorded/displayed for each roll.
enum LogLevel {
	NONE,            # No logging
	CRITICAL_ONLY,   # Only log natural 1s and 20s
	FAILURES,        # Log failed rolls and criticals
	ALL              # Log all rolls with full details
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## Whether to log all dice rolls for debugging purposes
@export var enable_logging: bool = true

## Level of detail to include in logging output
@export var log_level: LogLevel = LogLevel.ALL

## Whether to use a fixed seed for testing/debugging (deterministic results)
@export var use_fixed_seed: bool = false

## Fixed seed value when use_fixed_seed is enabled
@export var fixed_seed: int = 12345

# ==============================================================================
# SIGNALS
# ==============================================================================

## Emitted whenever any dice roll is performed
signal dice_rolled(result: RollResult)

## Emitted when a critical success occurs (natural 20)
signal critical_success(result: RollResult)

## Emitted when a critical failure occurs (natural 1)
signal critical_failure(result: RollResult)

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

## Random number generator instance
var rng: RandomNumberGenerator

# ==============================================================================
# LIFECYCLE METHODS
# ==============================================================================

func _ready() -> void:
	# Initialize random number generator
	rng = RandomNumberGenerator.new()
	
	if use_fixed_seed:
		rng.seed = fixed_seed
		print("[Dice] Using fixed seed: %d" % fixed_seed)
	else:
		rng.randomize()
	
	print("[Dice] Dice rolling system initialized")

# ==============================================================================
# CORE DICE ROLLING FUNCTIONS
# ==============================================================================

## Rolls a single die with the specified number of sides
## Returns a value from 1 to sides (special handling for d100)
func roll_die(sides: int) -> int:
	match sides:
		100:
			# Handle percentile dice (00-90 + 0-9)
			var tens = rng.randi_range(0, 9) * 10  # 0, 10, 20, ..., 90
			var ones = rng.randi_range(0, 9)      # 0, 1, 2, ..., 9
			var result = tens + ones
			return 100 if result == 0 else result  # 00+0 becomes 100
		_:
			# Standard die: 1 to sides
			return rng.randi_range(1, sides)

## Rolls multiple dice and returns an array of individual results
func roll_dice(count: int, sides: int) -> Array[int]:
	var results: Array[int] = []
	for i in count:
		results.append(roll_die(sides))
	return results

## Rolls multiple dice and returns the sum plus optional modifier
func roll_dice_sum(count: int, sides: int, modifier: int = 0) -> int:
	var dice_results = roll_dice(count, sides)
	var sum = 0
	for die_result in dice_results:
		sum += die_result
	return sum + modifier

## Creates a detailed RollResult for a basic dice roll
func roll_with_details(count: int, sides: int, modifier: int = 0, 
	roll_type: RollType = RollType.CUSTOM) -> RollResult:
	var result = RollResult.new()
	result.roll_type = roll_type
	result.die_count = count
	result.die_sides = sides
	result.modifier = modifier
	result.advantage_state = AdvantageState.NORMAL
	result.timestamp = Time.get_unix_time_from_system()
	
	# Handle percentile dice specially
	if sides == 100 and count == 1:
		var tens = rng.randi_range(0, 9) * 10
		var ones = rng.randi_range(0, 9)
		var raw_result = tens + ones
		var final_result = 100 if raw_result == 0 else raw_result
		
		result.dice_rolled = [final_result]
		result.percentile_tens = tens
		result.percentile_ones = ones
		result.total = final_result + modifier
		result.breakdown = "d100: %d (%d + %d)" % [
			final_result, tens, ones
		]
	else:
		# Standard dice rolling
		result.dice_rolled = roll_dice(count, sides)
		var dice_sum = 0
		for die_result in result.dice_rolled:
			dice_sum += die_result
		result.total = dice_sum + modifier
		
		# Build breakdown string
		if count == 1:
			result.breakdown = "d%d: %d" % [sides, result.dice_rolled[0]]
		else:
			result.breakdown = "%dd%d: %s" % [
				count, sides, str(result.dice_rolled)
			]
	
	# Add modifier to breakdown if present
	if modifier != 0:
		var sign = "+" if modifier > 0 else ""
		result.breakdown += " %s%d" % [sign, modifier]
	
	result.description = "Rolled %s" % result.breakdown
	
	# Check for critical success/failure on d20 rolls
	if sides == 20:
		result.critical_success = result.is_natural_20()
		result.critical_failure = result.is_natural_1()
	
	_process_roll_result(result)
	return result

# ==============================================================================
# D&D 5E ADVANTAGE/DISADVANTAGE SYSTEM
# ==============================================================================

## Rolls a d20 with advantage (roll twice, take higher)
func roll_with_advantage(modifier: int = 0) -> RollResult:
	return _roll_d20_with_advantage_state(modifier, AdvantageState.ADVANTAGE)

## Rolls a d20 with disadvantage (roll twice, take lower)  
func roll_with_disadvantage(modifier: int = 0) -> RollResult:
	return _roll_d20_with_advantage_state(modifier, AdvantageState.DISADVANTAGE)

## Rolls a d20 with the specified advantage state
func roll_d20(modifier: int = 0, advantage_state: AdvantageState = AdvantageState.NORMAL) -> RollResult:
	return _roll_d20_with_advantage_state(modifier, advantage_state)

## Internal method to handle d20 rolls with advantage/disadvantage
func _roll_d20_with_advantage_state(modifier: int, 
	advantage_state: AdvantageState) -> RollResult:
	var result = RollResult.new()
	result.roll_type = RollType.CUSTOM
	result.die_count = 1
	result.die_sides = 20
	result.modifier = modifier
	result.advantage_state = advantage_state
	result.timestamp = Time.get_unix_time_from_system()
	
	match advantage_state:
		AdvantageState.NORMAL:
			var die_result = roll_die(20)
			result.dice_rolled = [die_result]
			result.total = die_result + modifier
			result.breakdown = "d20: %d" % die_result
			
		AdvantageState.ADVANTAGE:
			var die1 = roll_die(20)
			var die2 = roll_die(20)
			var chosen = max(die1, die2)
			result.dice_rolled = [die1, die2]
			result.total = chosen + modifier
			result.breakdown = "d20 (advantage): %d (rolled %d, %d)" % [
				chosen, die1, die2
			]
			
		AdvantageState.DISADVANTAGE:
			var die1 = roll_die(20)
			var die2 = roll_die(20)
			var chosen = min(die1, die2)
			result.dice_rolled = [die1, die2]
			result.total = chosen + modifier
			result.breakdown = "d20 (disadvantage): %d (rolled %d, %d)" % [
				chosen, die1, die2
			]
	
	# Add modifier to breakdown if present
	if modifier != 0:
		var sign = "+" if modifier > 0 else ""
		result.breakdown += " %s%d" % [sign, modifier]
	
	result.description = "Rolled %s" % result.breakdown
	
	# Check for critical success/failure
	result.critical_success = result.is_natural_20()
	result.critical_failure = result.is_natural_1()
	
	_process_roll_result(result)
	return result

# ==============================================================================
# D&D 5E SPECIFIC ROLL TYPES
# ==============================================================================

## Performs an ability check against a Difficulty Class
func ability_check(modifier: int, dc: int, 
	advantage_state: AdvantageState = AdvantageState.NORMAL) -> RollResult:
	var result = roll_d20(modifier, advantage_state)
	result.roll_type = RollType.ABILITY_CHECK
	result.target_number = dc
	result.success = result.total >= dc
	result.description = "Ability Check (DC %d): %s" % [dc, result.breakdown]
	
	_process_roll_result(result)
	return result

## Performs an attack roll against Armor Class
func attack_roll(attack_bonus: int, target_ac: int, 
	advantage_state: AdvantageState = AdvantageState.NORMAL) -> RollResult:
	var result = roll_d20(attack_bonus, advantage_state)
	result.roll_type = RollType.ATTACK_ROLL
	result.target_number = target_ac
	result.success = result.total >= target_ac or result.critical_success
	result.description = "Attack Roll (AC %d): %s" % [target_ac, result.breakdown]
	
	_process_roll_result(result)
	return result

## Performs a saving throw against a Difficulty Class
func saving_throw(save_bonus: int, dc: int, 
	advantage_state: AdvantageState = AdvantageState.NORMAL) -> RollResult:
	var result = roll_d20(save_bonus, advantage_state)
	result.roll_type = RollType.SAVING_THROW
	result.target_number = dc
	result.success = result.total >= dc
	result.description = "Saving Throw (DC %d): %s" % [dc, result.breakdown]
	
	_process_roll_result(result)
	return result

## Performs an initiative roll for combat ordering
func initiative_roll(dex_modifier: int) -> RollResult:
	var result = roll_d20(dex_modifier, AdvantageState.NORMAL)
	result.roll_type = RollType.INITIATIVE
	result.description = "Initiative: %s" % result.breakdown
	
	_process_roll_result(result)
	return result

## Performs a damage roll using dice expression (e.g., "2d6+3")
func damage_roll(dice_expression: String) -> RollResult:
	var parsed = _parse_dice_expression(dice_expression)
	if parsed.is_empty():
		push_error("[Dice] Invalid dice expression: %s" % dice_expression)
		return RollResult.new()
	
	var result = roll_with_details(parsed.count, parsed.sides, 
		parsed.modifier, RollType.DAMAGE_ROLL)
	result.description = "Damage (%s): %s" % [dice_expression, result.breakdown]
	
	_process_roll_result(result)
	return result

## Performs a death saving throw (special D&D 5e mechanic)
func death_saving_throw() -> RollResult:
	var result = roll_d20(0, AdvantageState.NORMAL)
	result.roll_type = RollType.DEATH_SAVE
	result.target_number = 10
	result.success = result.total >= 10
	result.description = "Death Saving Throw: %s" % result.breakdown
	
	_process_roll_result(result)
	return result

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

## Parses a dice expression string (e.g., "2d6+3", "1d20", "d4-1")
func _parse_dice_expression(expression: String) -> Dictionary:
	# Remove spaces and convert to lowercase
	var clean_expr = expression.strip_edges().to_lower()
	
	# Handle shorthand "d20" as "1d20"
	if clean_expr.begins_with("d"):
		clean_expr = "1" + clean_expr
	
	# Regular expression pattern: (count)d(sides)(+/-modifier)
	var regex = RegEx.new()
	regex.compile(r"^(\d+)d(\d+)([+-]\d+)?$")
	var result = regex.search(clean_expr)
	
	if not result:
		return {}
	
	var count = int(result.get_string(1))
	var sides = int(result.get_string(2))
	var modifier = 0
	
	if result.get_string(3):
		modifier = int(result.get_string(3))
	
	return {
		"count": count,
		"sides": sides,
		"modifier": modifier
	}

## Processes a completed roll result (logging, signals, etc.)
func _process_roll_result(result: RollResult) -> void:
	# Emit appropriate signals
	dice_rolled.emit(result)
	
	if result.critical_success:
		critical_success.emit(result)
	elif result.critical_failure:
		critical_failure.emit(result)
	
	# Handle logging based on current log level
	_log_roll_result(result)

## Logs a roll result based on the current logging settings
func _log_roll_result(result: RollResult) -> void:
	if not enable_logging:
		return
	
	match log_level:
		LogLevel.NONE:
			return
		LogLevel.CRITICAL_ONLY:
			if result.critical_success or result.critical_failure:
				print("[Dice] %s" % result.to_detailed_string())
		LogLevel.FAILURES:
			if result.critical_failure or (result.target_number > 0 and not result.success):
				print("[Dice] %s" % result.to_detailed_string())
		LogLevel.ALL:
			print("[Dice] %s" % result.to_detailed_string())
