extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var save = root.get_node("SaveManager")
	var original_save: Dictionary = save.data.duplicate(true)
	save.data.achievements.erase("survive_minute")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.award_achievement("survive_minute")
	assert("survive_minute" in save.data.achievements, "Achievement was not recorded in the in-memory save")
	game.show_story_archive()
	assert(game.ui_layer != null and game.ui_layer.find_child("ArchiveList", true, false) != null, "Achievement-linked story archive failed")
	save.data = original_save
	print("COLLECTION_SMOKE_OK achievement_story=true")
	quit()
