extends Node2D

func _ready() -> void:
	var container := HBoxContainer.new()
	add_child(container)

	print("CrossPromo: fetching...")
	var promos: Array[CrossPromotionInfo] = await CrossPromotion.fetch(self, "bingomental")
	print("CrossPromo: got %d entries" % promos.size())
	for info: CrossPromotionInfo in promos:
		print("  - id=%s title=%s thumbnail=%s store_url=%s" % [info.id, info.title, info.thumbnail, info.store_url])
		var btn := TextureButton.new()
		if info.thumbnail:
			btn.texture_normal = info.thumbnail
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.custom_minimum_size = Vector2(200, 200)
		btn.pressed.connect(func() -> void: OS.shell_open(info.store_url))
		container.add_child(btn)
