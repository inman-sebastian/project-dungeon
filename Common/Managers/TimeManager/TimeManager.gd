extends CanvasModulate
class_name TimeManager

enum TimePhase { DAWN, DAY, DUSK, NIGHT }

signal time_changed(current_time: float)
signal phase_changed(previous_phase: TimePhase, new_phase: TimePhase)
signal day_ended(previous_day: int, new_day: int)

@export_group("Time Settings")
@export var day_in_minutes: float = 1.0
@export_range(0.0, 24.0, 0.1) var current_time: float = 12.0
@export var days_elapsed: int = 0

@export_group("Time Override")
@export var override_time: bool = false
@export_range(0.0, 24.0, 0.1) var time_override: float = 12.0

@export_group("Time of Day Colors")
@export var time_colors: Gradient

@onready var current_color: Color = time_colors.sample(current_time)
@onready var current_phase: TimePhase = get_current_phase(current_time)

var time_scale: float = 24.0 / (60.0 * day_in_minutes)

func _ready() -> void:
	var hour: float = get_active_time()
	current_color = time_colors.sample(hour / 24.0)
	self.color = current_color
	current_phase = get_current_phase(hour)

func _process(delta: float) -> void:
	#var previous_hour := current_time
	var previous_day := days_elapsed

	if not override_time:
		current_time += delta * time_scale

		if current_time >= 24.0:
			current_time = fmod(current_time, 24.0)
			days_elapsed += 1
			emit_signal("day_ended", previous_day, days_elapsed)

	var hour: float = get_active_time()
	var time_ratio: float = hour / 24.0
	var target_color: Color = time_colors.sample(time_ratio)

	current_color = current_color.lerp(target_color, delta * time_scale)
	self.color = current_color

	var new_phase: TimePhase = get_current_phase(hour)

	if new_phase != current_phase:
		var previous_phase := current_phase
		current_phase = new_phase
		emit_signal("phase_changed", previous_phase, new_phase)

	emit_signal("time_changed", hour)

func get_active_time() -> float:
	return time_override if override_time else current_time

func get_current_phase(hour: float) -> TimePhase:
	if hour >= 6.0 and hour < 9.0:
		return TimePhase.DAWN
	elif hour >= 9.0 and hour < 17.0:
		return TimePhase.DAY
	elif hour >= 17.0 and hour < 20.0:
		return TimePhase.DUSK
	else:
		return TimePhase.NIGHT
