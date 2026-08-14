extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.show_story_archive()
	for frame in 8:
		await process_frame
	var viewport := game.get_viewport().get_visible_rect().size
	var list_panel := game.ui_layer.find_child("ArchiveList", true, false) as Control
	var detail_panel := game.ui_layer.find_child("ArchiveDetail", true, false) as Control
	var back := game.ui_layer.find_child("ArchiveBack", true, false) as Button
	var tabs := game.ui_layer.find_child("ArchiveTabs", true, false) as Control
	assert(list_panel != null and detail_panel != null and back != null and tabs != null, "Archive full-screen regions are missing")
	assert(back.get_global_rect().end.y <= tabs.get_global_rect().position.y, "Archive back button overlaps category tabs")
	assert(tabs.get_global_rect().end.y <= list_panel.get_global_rect().position.y, "Archive category tabs overlap content panels")
	assert(list_panel.get_global_rect().position.x <= 24.5, "Archive list leaves excessive left margin")
	assert(detail_panel.get_global_rect().end.x >= viewport.x - 24.5, "Archive detail does not fill the screen width")
	assert(list_panel.get_global_rect().end.y >= viewport.y - 12.5, "Archive list does not fill the screen height")
	assert(detail_panel.get_global_rect().end.y >= viewport.y - 12.5, "Archive detail does not fill the screen height")
	assert(back.get_global_rect().end.x <= viewport.x, "Archive back button is clipped")
	print("ARCHIVE_LAYOUT_SMOKE_OK list=", list_panel.get_global_rect(), " detail=", detail_panel.get_global_rect())
	quit()
