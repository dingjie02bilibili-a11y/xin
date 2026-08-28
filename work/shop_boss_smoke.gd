extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	game.gain_star_shards(12)
	game.show_boss_reward("赫巡·追赶者", 1)
	await process_frame
	assert(game.boss_reward_overlay != null and game.player.selection_protected, "Boss reward did not pause safely")
	game.select_boss_relic("predator_boots")
	await process_frame
	assert(game.shop_overlay == null, "Boss reward still caused a double shop interruption")
	assert(game.directed_shop_pending and game.star_shards == 12, "Next-shop directed build opportunity was not queued")
	assert(game.state == game.GameState.PLAYING and not game.player.selection_protected, "Boss reward did not resume play")
	print("SHOP_BOSS_SMOKE_OK relics=", game.active_relics.size(), " wallet=", game.star_shards)
	quit()
