extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	assert(not game.active_core_skill_ids().is_empty(), "Run did not start with a pet")
	for relic in game.BOSS_RELICS:
		game.active_relics[str(relic.id)] = 3
	game.show_boss_reward("closure", 6)
	await process_frame
	assert(game.boss_reward_overlay != null, "Boss reward overlay did not open")
	var buttons: Array[Node] = game.boss_reward_overlay.find_children("*", "Button", true, false)
	assert(buttons.size() == 3, "Maxed relic pool did not produce three edition choices")
	var unique_rewards: Dictionary = {}
	for button in buttons:
		assert("版本" in button.text and "改造宠物" in button.text, "Fallback reward was not a valid pet edition")
		unique_rewards[button.text] = true
	assert(unique_rewards.size() == buttons.size(), "Boss edition choices contained duplicates")
	print("BOSS_REWARD_CLOSURE_OK choices=", buttons.size(), " relic_ranks=", game.active_relics.size())
	quit()
