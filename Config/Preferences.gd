extends Node
class_name Preferences

const PREFERENCES_PATH = "res://Config/Preferences.cfg"

var _preferences_file = ConfigFile.new()
var _preferences = {
	"audio": {
		"master_volume": 10,
		"sound_volume": 10,
		"music_volume": 10
	}
}

func _ready() -> void:
	_load()
	_save()
	
func _save() -> void:
	pass
	
func _load() -> void:
	pass
