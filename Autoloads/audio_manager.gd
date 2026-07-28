extends Node
class_name BaseAudioManager

static var BUS_NAMES:Array[String] = [
	"Music",
	"Sfx",
	"Master"
]

static var ENABLED_SETTING_NAMES:Dictionary[String, String] = {
	"Music": GodotBase.settings.music_enabled_setting.name,
	"Sfx": GodotBase.settings.sfx_enabled_setting.name,
	"Master": GodotBase.settings.master_enabled_setting.name,
}

static var VOLUME_SETTING_NAMES:Dictionary[String, String] = {
	"Music": GodotBase.settings.music_volume_setting.name,
	"Sfx": GodotBase.settings.sfx_volume_setting.name,
	"Master": GodotBase.settings.master_volume_setting.name,
}

var _bus_indices:Dictionary[String, int] = {}
var _internal_volumes:Dictionary[String, float] = {}
var _internal_mutes:Dictionary[String, bool] = {}


func _ready()-> void:
	for bname:String in BUS_NAMES:
		_bus_indices[bname] = AudioServer.get_bus_index(bname)
		_internal_volumes[bname] = 0
		_internal_mutes[bname] = false
		
	Settings.setting_changed.connect(update_buses.unbind(2))
	

func set_internal_volume(bus_name:String, db:float)-> void:
	_internal_volumes[bus_name] = db
	update_buses()


func set_internal_mute(bus_name:String, muted:bool)-> void:
	_internal_mutes[bus_name] = muted
	update_buses()


func update_buses()-> void:
	for bname in BUS_NAMES:
		var i = _bus_indices[bname]
		
		var v_lin = Settings.get_setting_value_by_name(VOLUME_SETTING_NAMES[bname])
		AudioServer.set_bus_volume_linear(i, v_lin / 10.0)
		var v_db = AudioServer.get_bus_volume_db(i)
		v_db += _internal_volumes[bname]
		AudioServer.set_bus_volume_db(i, v_db)
		
		var enabled = Settings.get_setting_value_by_name(ENABLED_SETTING_NAMES[bname])
		enabled = enabled and not _internal_mutes[bname]
		AudioServer.set_bus_mute(i, not enabled)
			
