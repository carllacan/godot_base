extends Object
class_name CrossPromotion

const JSON_URL = "https://carllacan.github.io/carllacan-games/cross-promotion.json"

# Returns promotions for all games except game_id, sorted by sort_order.
# Entries with sort_order < 0 are excluded.
# Caller must be a Node (used to attach HTTPRequest nodes).
static func fetch(caller: Node, game_id: String) -> Array[CrossPromotionInfo]:
	var infos: Array[CrossPromotionInfo] = []

	var json_body := await _http_get(caller, JSON_URL)
	if json_body.is_empty():
		return infos

	var data = JSON.parse_string(json_body.get_string_from_utf8())
	if not data is Dictionary or not data.has("games") or not data["games"] is Array:
		return infos

	var entries: Array[CrossPromotionInfo] = []
	for game_dict: Dictionary in data["games"]:
		var info := CrossPromotionInfo.new()
		info.id = game_dict.get("id", "")
		info.title = game_dict.get("title", "")
		info.description = game_dict.get("description", "")
		info.store_url = game_dict.get("store_url", "")
		info.thumbnail_url = game_dict.get("thumbnail_url", "")
		info.sort_order = game_dict.get("sort_order", 0)

		if info.id == game_id or info.sort_order < 0:
			continue

		entries.append(info)

	entries.sort_custom(func(a: CrossPromotionInfo, b: CrossPromotionInfo) -> bool:
		return a.sort_order < b.sort_order)

	for entry: CrossPromotionInfo in entries:
		if not entry.thumbnail_url.is_empty():
			var img_body := await _http_get(caller, entry.thumbnail_url)
			if not img_body.is_empty():
				entry.thumbnail = _body_to_texture(img_body, entry.thumbnail_url)
		infos.append(entry)

	return infos


static func _http_get(caller: Node, url: String) -> PackedByteArray:
	var http := HTTPRequest.new()
	caller.add_child(http)
	http.request(url)
	var args: Array = await http.request_completed
	http.queue_free()

	var result_code: int = args[0]
	var response_code: int = args[1]
	var body: PackedByteArray = args[3]

	if result_code != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("CrossPromotion: HTTP request failed for %s (result=%d, code=%d)" \
			% [url, result_code, response_code])
		return PackedByteArray()

	return body


static func _body_to_texture(body: PackedByteArray, url: String) -> ImageTexture:
	var image := Image.new()
	var url_lower := url.to_lower()
	var err: Error

	if url_lower.ends_with(".jpg") or url_lower.ends_with(".jpeg"):
		err = image.load_jpg_from_buffer(body)
	elif url_lower.ends_with(".webp"):
		err = image.load_webp_from_buffer(body)
	else:
		err = image.load_png_from_buffer(body)

	if err != OK:
		push_warning("CrossPromotion: failed to decode image from %s" % url)
		return null

	return ImageTexture.create_from_image(image)
