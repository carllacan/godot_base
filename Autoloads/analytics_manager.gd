extends Node
class_name AnalyticsManager
# add as Analytics

const MEASUREMENT_ID := "G-NL35EFYR15"
const API_SECRET := "WwzQAYjlStaMsBtXqU9XBw"
const CLIENT_ID_FILEPATH := "user://id"


var url:String 

var http:HTTPRequest
var client_id:String
var session_id:String
var debug_view:bool = false

func _ready()-> void:
	http = HTTPRequest.new()
	#http.request_completed.connect(_on_http_request_completed)
	
	if debug_view:
		url = "https://www.google-analytics.com/debug/mp/collect"
	else:
		url = "https://www.google-analytics.com/collect"
		url = "https://www.google-analytics.com/mp/collect"
	url += "?measurement_id=%s" % MEASUREMENT_ID
	url += "&api_secret=%s" % API_SECRET

	client_id = get_client_id()
	session_id = str(Time.get_unix_time_from_system())
	add_child(http)
	
	
func get_client_id()-> String:
	#return generate_random_id()
	var save_path = CLIENT_ID_FILEPATH
	if not FileAccess.file_exists(save_path):
		var id = generate_random_id()
		var f = FileAccess.open(save_path, FileAccess.WRITE)
		f.store_line(id)
		return id
	else:
		var f = FileAccess.open(save_path, FileAccess.READ)
		return f.get_line()
	

static func generate_random_id() -> String:
	randomize()
	return "%08x-%04x-%04x-%04x-%012x" % [
		randi() & 0xffffffff,
		randi() & 0xffff,
		randi() & 0xffff,
		randi() & 0xffff,
		randi() & 0xffffffffffff
	]
	
	
func track_event(event_name: String, params: Dictionary = {}):
	
	var ans = preload("res://GodotBase/SettingsSystem/BaseSettings/analytics_enabled.tres")
	if not Settings.get_setting_value(ans):
		return
	
	if debug_view:
		params["debug_mode"] = true
	#params["dummy"] = "true"
	#params["method"] = "Google"
	params["session_id"] = session_id
	#params["engagement_time_msec"] = 100	

	var body = {
	"client_id": client_id,
	"events": [
		{"name": event_name, 
		"params": params}
		]
	}
	var json = JSON.stringify(body)
	var headers = [
		"Content-Type: application/json",
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
	]
	var result = http.request(url, headers, HTTPClient.METHOD_POST, json)
	if result != OK and Flags.DEBUG:
		print("Analytics request failure")
	
