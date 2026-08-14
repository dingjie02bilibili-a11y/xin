extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.show_character_select()
	for frame in 8:
		await process_frame
	var back := game.ui_layer.find_child("CharacterBack", true, false) as Button
	assert(back != null, "Character screen back button is missing")
	var viewport_bottom: float = game.get_viewport().get_visible_rect().size.y
	assert(back.get_global_rect().end.y <= viewport_bottom - 8.0, "Character screen back button is clipped")
	var grids: Array[Node] = game.ui_layer.find_children("*", "GridContainer", true, false)
	assert(not grids.is_empty(), "Character grid is missing")
	var grid: GridContainer = grids[0]
	assert(grid.get_child_count() == 6, "Not all six character cards were rendered")
	for card in grid.get_children():
		assert(card.get_global_rect().end.y < back.get_global_rect().position.y, "A character card overlaps the back button")
		for button in card.find_children("*", "Button", true, false):
			assert(button.get_global_rect().end.y <= card.get_global_rect().end.y, "Character card action is clipped")
	print("CHARACTER_LAYOUT_SMOKE_OK back_bottom=", back.get_global_rect().end.y, " viewport=", viewport_bottom)
	quit()
