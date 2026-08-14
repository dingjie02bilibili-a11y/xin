extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	game.boss_kills = 6
	game.start_endless_mode()
	assert(game.endless_mode and game.state == 1, "Endless mode did not begin")
	game.endless_wave = 3
	game.spawn_endless_boss()
	await create_timer(1.0).timeout
	assert(get_nodes_in_group("bosses").size() == 1, "Endless boss did not spawn")
	for upgrade in game.UPGRADES:
		game.upgrade_levels[str(upgrade.id)] = int(upgrade.max)
	game.prepare_shop_goods(true)
	assert(game.shop_goods.size() >= 3, "Endless shop choices missing or shelf underfilled")
	assert(game.shop_goods.any(func(offer): return str(offer.get("kind", "")) == "endless"), "Endless growth is unreachable in shop")
	for id in game.ENDLESS_CARD_IDS:
		game.upgrade_levels[id] = 10
	game.prepare_shop_goods(true)
	assert(game.shop_goods.size() >= 3, "Maxed endless shop has empty shelves")
	print("ENDLESS_SMOKE_OK wave=", game.endless_wave, " boss=", get_nodes_in_group("bosses")[0].kind)
	quit()
