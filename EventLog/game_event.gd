extends Resource
class_name GameEvent

@export var title: String = ""
@export var text: String = ""
@export var parameters: Dictionary = {}
@export var subevents: Array[GameEvent] = []


func get_title() -> String:
	return _replace_placeholders(title)


func get_text() -> String:
	return _replace_placeholders(text)


## Like get_title() but wraps parameter values in BBCode color tags.
## param_colors: Dictionary[String, Color] — maps parameter keys to display colors.
func get_title_bbcode(param_colors: Dictionary = {}) -> String:
	return _replace_placeholders_bbcode(title, param_colors)


## Like get_text() but wraps parameter values in BBCode color tags.
func get_text_bbcode(param_colors: Dictionary = {}) -> String:
	return _replace_placeholders_bbcode(text, param_colors)


func _replace_placeholders(template: String) -> String:
	var result := template
	for key in parameters:
		result = result.replace("{%s}" % key, str(parameters[key]))
	return result


func _replace_placeholders_bbcode(template: String, param_colors: Dictionary) -> String:
	var result := template
	for key in parameters:
		var value := str(parameters[key])
		if param_colors.has(key):
			var c: Color = param_colors[key]
			value = "[color=#%s]%s[/color]" % [c.to_html(false), value]
		result = result.replace("{%s}" % key, value)
	return result
