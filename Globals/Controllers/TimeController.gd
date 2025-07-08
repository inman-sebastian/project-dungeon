extends CanvasModulate

signal hour_changed(previous_hour: int, new_hour: int)
signal time_of_day_changed(previous_time_of_day: TimeOfDay.Enum, new_time_of_day: TimeOfDay.Enum)
signal day_changed(previous_day: int, new_day: int)

## TODO: Refactor this to load the value from save state data.
## The current time of the day, from 0.0 to < 24.0
var current_time: float = Global.DEFAULT_TIME_OF_DAY

## The current hour of the day (0–23)
var current_hour: int = floor(current_time)

## TODO: Refactor this to load the value from save state data.
## The current day count representing the number of days that have passed.
var current_day: int = 1

## Track the current TimeOfDay enum
var current_time_of_day: TimeOfDay.Enum = get_current_time_of_day(current_hour)

## Reference to the previous hour.
var previous_hour: int
## Reference to the previous day.
var previous_day: int
## Reference to the previous time of day.
var previous_time_of_day: TimeOfDay.Enum

## TODO: Refactor this to load the value from save state data.
## The relative time speed that controls how fast time progresses in-game.
## E.g. if DEFAULT_RELATIVE_TIME_SPEED = 1, time will move at a normal speed.
var relative_time_speed: float = Global.DEFAULT_RELATIVE_TIME_SPEED

## The current time scale that controls how fast time progresses in-game
## E.g. if IN_GAME_DAY_IN_MINUTES = 10, one in-game day = 10 real minutes
var time_delta_to_hours: float = (24.0 / (60.0 * Global.IN_GAME_DAY_IN_MINUTES)) * relative_time_speed

## Get the Time of Day gradient from the active stage in the scene.
#@onready var time_of_day_gradient: Gradient = SceneManager.get_active_stage().time_of_day_gradient
const time_of_day_gradient = preload("res://Stages/Overworld/TimePhases.tres")

@onready var current_time_of_day_color: Color = time_of_day_gradient.sample(current_time)
@onready var previous_time_of_day_color: Color

func _ready() -> void:
	current_time_of_day_color = time_of_day_gradient.sample(current_time / 24.0)
	self.color = current_time_of_day_color

func _process(delta: float) -> void:
	# Progress time based on the current time scale.
	current_time += delta * time_delta_to_hours
	
	# Wrap around to next day when the current time reaches 24.0 (midnight)
	if current_time >= 24.0:
		current_time -= 24.0
		current_day += 1
		emit_signal("day_changed", previous_day, current_day)
		
	# Update and emit hour change
	current_hour = int(floor(current_time))
	current_time_of_day = get_current_time_of_day(current_hour)
	
	if current_hour != previous_hour:
		emit_signal("hour_changed", previous_hour, current_hour)
		print("Day %d - %02d:00 (%s)" % [
			current_day,
			current_hour,
			TimeOfDay.Enum.keys()[current_time_of_day]
		])
		
	# Update and emit time of day change
	if current_time_of_day != previous_time_of_day:
		emit_signal("time_of_day_changed", previous_time_of_day, current_time_of_day)
		
	## Reference to the previous hour.
	previous_hour = current_hour
	## Reference to the previous day.
	previous_day = current_day
	## Reference to the previous time of day.
	previous_time_of_day = current_time_of_day
		
	_update_modulate(delta)

## Gets the current time of day based on the the provided hour integer.
## The time of day is based on a 24-hour clock represented as an integer
## between the values of 0 and 23.
func get_current_time_of_day(hour: int) -> TimeOfDay.Enum:
	if hour < 0 or hour > 23:
		push_error("Invalid hour: %d. Must be between 0 and 23." % hour)
		return TimeOfDay.Enum.Midnight

	if hour <= 1:  return TimeOfDay.Enum.Midnight
	if hour <= 3:  return TimeOfDay.Enum.LateNight
	if hour == 4:  return TimeOfDay.Enum.PreDawn
	if hour == 5:  return TimeOfDay.Enum.Sunrise
	if hour <= 7:  return TimeOfDay.Enum.Morning
	if hour <= 11: return TimeOfDay.Enum.Morning
	if hour <= 13: return TimeOfDay.Enum.Noon
	if hour <= 16: return TimeOfDay.Enum.Afternoon
	if hour == 17: return TimeOfDay.Enum.Evening
	if hour == 18: return TimeOfDay.Enum.Sunset
	if hour <= 20: return TimeOfDay.Enum.Dusk
	return TimeOfDay.Enum.Night


## Updates the CanvasModulate node color based on the current time of day.
## This is done by sampling a point from a gradient, using the time of day
## as a percentage.
func _update_modulate(delta: float) -> void:
	previous_time_of_day_color = current_time_of_day_color
	var target_time_of_day_color = time_of_day_gradient.sample(current_time / 24.0)
	current_time_of_day_color = current_time_of_day_color.lerp(target_time_of_day_color, delta * time_delta_to_hours)
	
	self.color = current_time_of_day_color
