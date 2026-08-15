extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var names := ["游侠", "骑士", "星术师", "守卫", "影舞者", "星火使"]
	var save = root.get_node_or_null("SaveManager")
	assert(save != null, "SaveManager autoload missing")
	var original_save: Dictionary = save.data.duplicate(true)
	for achievement_id in ["boss_breaker", "survive_three", "combo_adept", "streak_master", "molten_master"]:
		if not save.data.achievements.has(achievement_id):
			save.data.achievements.append(achievement_id)
	for character in names:
		var game = packed.instantiate()
		root.add_child(game)
		await process_frame
		save.data.selected_character = character
		game.start_game_after_prologue()
		assert(game.player.character_name == character, "Character did not start: " + character)
		assert(game.make_character_portrait(character) != null, "Portrait missing: " + character)
		match character:
			"守卫": assert(game.has_orbit and game.orbit_count == 3, "Guardian orbit start failed")
			"影舞者": assert(game.stats.crit >= 0.25 and game.player.speed > 280.0, "Dancer crit/mobility failed")
			"星火使": assert(game.has_aura and game.aura_radius == 205.0, "Ember aura start failed")
		game.queue_free()
		await process_frame
	save.data = original_save
	save.save()
	print("CHARACTER_SMOKE_OK count=", names.size())
	quit()
