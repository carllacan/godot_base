extends GutTest


func _make_body(obj: Variant) -> PackedByteArray:
	return JSON.stringify(obj).to_utf8_buffer()


func _make_games_body(games: Array) -> PackedByteArray:
	return _make_body({"version": 1, "games": games})


func _game(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"id": "testgame",
		"title": "Test Game",
		"description": "A test game",
		"store_url": "https://example.com",
		"thumbnail_url": "https://example.com/thumb.png",
		"sort_order": 1,
	}
	base.merge(overrides, true)
	return base


#region invalid input

func test_empty_body_returns_empty():
	var result := CrossPromotion._parse_json_body(PackedByteArray(), "mygame")
	assert_eq(result.size(), 0)


func test_invalid_json_returns_empty():
	var result := CrossPromotion._parse_json_body("not json".to_utf8_buffer(), "mygame")
	assert_eq(result.size(), 0)


func test_missing_games_key_returns_empty():
	var result := CrossPromotion._parse_json_body(_make_body({"version": 1}), "mygame")
	assert_eq(result.size(), 0)


func test_games_not_array_returns_empty():
	var result := CrossPromotion._parse_json_body(_make_body({"games": "oops"}), "mygame")
	assert_eq(result.size(), 0)


func test_empty_games_array_returns_empty():
	var result := CrossPromotion._parse_json_body(_make_games_body([]), "mygame")
	assert_eq(result.size(), 0)

#endregion


#region filtering

func test_excludes_entry_matching_game_id():
	var body := _make_games_body([_game({"id": "mygame"}), _game({"id": "other"})])
	var result := CrossPromotion._parse_json_body(body, "mygame")
	assert_eq(result.size(), 1)
	assert_eq(result[0].id, "other")


func test_excludes_entries_with_negative_sort_order():
	var body := _make_games_body([_game({"id": "hidden", "sort_order": -1}), _game({"id": "visible"})])
	var result := CrossPromotion._parse_json_body(body, "mygame")
	assert_eq(result.size(), 1)
	assert_eq(result[0].id, "visible")


func test_excludes_entries_with_zero_is_not_excluded():
	var body := _make_games_body([_game({"id": "zero", "sort_order": 0})])
	var result := CrossPromotion._parse_json_body(body, "mygame")
	assert_eq(result.size(), 1)


func test_all_entries_excluded_returns_empty():
	var body := _make_games_body([
		_game({"id": "mygame"}),
		_game({"id": "hidden", "sort_order": -1}),
	])
	var result := CrossPromotion._parse_json_body(body, "mygame")
	assert_eq(result.size(), 0)

#endregion


#region sorting

func test_entries_sorted_by_sort_order_ascending():
	var body := _make_games_body([
		_game({"id": "c", "sort_order": 3}),
		_game({"id": "a", "sort_order": 1}),
		_game({"id": "b", "sort_order": 2}),
	])
	var result := CrossPromotion._parse_json_body(body, "mygame")
	assert_eq(result[0].id, "a")
	assert_eq(result[1].id, "b")
	assert_eq(result[2].id, "c")


func test_already_sorted_entries_remain_sorted():
	var body := _make_games_body([
		_game({"id": "a", "sort_order": 1}),
		_game({"id": "b", "sort_order": 2}),
	])
	var result := CrossPromotion._parse_json_body(body, "mygame")
	assert_eq(result[0].id, "a")
	assert_eq(result[1].id, "b")

#endregion


#region field mapping

func test_all_fields_mapped_correctly():
	var body := _make_games_body([{
		"id": "myid",
		"title": "My Title",
		"description": "My Desc",
		"store_url": "https://store.example.com",
		"thumbnail_url": "https://img.example.com/t.png",
		"sort_order": 5,
	}])
	var result := CrossPromotion._parse_json_body(body, "other")
	assert_eq(result.size(), 1)
	var info: CrossPromotionInfo = result[0]
	assert_eq(info.id, "myid")
	assert_eq(info.title, "My Title")
	assert_eq(info.description, "My Desc")
	assert_eq(info.store_url, "https://store.example.com")
	assert_eq(info.thumbnail_url, "https://img.example.com/t.png")
	assert_eq(info.sort_order, 5)


func test_missing_fields_use_defaults():
	var body := _make_games_body([{"id": "minimal"}])
	var result := CrossPromotion._parse_json_body(body, "other")
	assert_eq(result.size(), 1)
	var info: CrossPromotionInfo = result[0]
	assert_eq(info.title, "")
	assert_eq(info.description, "")
	assert_eq(info.store_url, "")
	assert_eq(info.thumbnail_url, "")
	assert_eq(info.sort_order, 0)

#endregion


#region fixture json

func test_fixture_json_returns_two_entries():
	var path := "res://GodotBase/CrossPromotion/Tests/cross-promotion.json"
	var text := FileAccess.get_file_as_string(path)
	var result := CrossPromotion._parse_json_body(text.to_utf8_buffer(), "mygame")
	assert_eq(result.size(), 2)


func test_fixture_json_excludes_caller_game():
	var path := "res://GodotBase/CrossPromotion/Tests/cross-promotion.json"
	var text := FileAccess.get_file_as_string(path)
	var result := CrossPromotion._parse_json_body(text.to_utf8_buffer(), "bingobingle")
	assert_eq(result.size(), 1)
	assert_eq(result[0].id, "coreward")

#endregion
