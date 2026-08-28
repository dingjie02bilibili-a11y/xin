extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	for upgrade in game.UPGRADES:
		assert(game.make_skill_icon(upgrade.id) != null, "Skill icon failed: " + upgrade.id)
	for character in ["游侠", "骑士", "魔法师"]:
		assert(game.make_character_portrait(character) != null, "Portrait failed: " + character)
	game.start_game_after_prologue()
	await process_frame
	game.spawn_enemy("追踪怪")
	var pause_enemy = get_nodes_in_group("enemies")[-1]
	pause_enemy.global_position = game.player.global_position
	pause_enemy.take_damage(5.0)
	await process_frame
	assert(game.visual_root.get_child_count() >= 2, "Hit effect was not created")
	var health_before_pause: float = game.player.health
	game.gain_star_shards(100)
	game.show_shop(true)
	assert(paused, "Opening the shop did not pause combat")
	assert(game.player.selection_protected, "Opening the shop did not protect the player")
	assert(
		is_equal_approx(game.player.health, health_before_pause),
		"Player took damage while the shop was open"
	)
	var offer_index := 0
	var offer: Dictionary = game.shop_goods[offer_index]
	var wallet_before: int = game.star_shards
	game.purchase_shop_offer(offer_index)
	game.purchase_shop_offer(offer_index)
	assert(game.star_shards == wallet_before - int(offer.price), "A double click purchased the same item twice")
	game.close_shop()
	await process_frame
	assert(game.state == 1, "Game did not resume after the last upgrade choice")
	assert(not game.player.selection_protected, "Selection protection was not released")
	print(
		"SMOKE_OK state=",
		game.state,
		" shards=",
		game.star_shards,
		" offers=",
		game.shop_goods.size()
	)
	quit()
