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
	game.star_shards = 200
	game.show_shop(true)
	await process_frame
	assert(game.shop_goods.size() >= 3, "Early shop did not fill every shelf")
	assert(game.shop_goods.any(func(offer): return bool(offer.get("directed", false))), "Early shop did not provide a directed build offer")
	game.close_shop()
	await process_frame

	for upgrade in game.UPGRADES:
		game.upgrade_levels[str(upgrade.id)] = int(upgrade.max)
	game.start_endless_mode()
	game.show_shop(true)
	await process_frame
	assert(game.shop_goods.size() >= 3, "Exhausted endless shop produced an empty shelf")
	var endless_index := -1
	for index in game.shop_goods.size():
		if str(game.shop_goods[index].get("kind", "")) == "endless":
			endless_index = index
			break
	assert(endless_index >= 0, "Endless growth card was not reachable through the shop")
	var growth_id := str(game.shop_goods[endless_index].id)
	var wallet_before: int = game.star_shards
	game.purchase_shop_offer(endless_index)
	await process_frame
	assert(int(game.upgrade_levels.get(growth_id, 0)) == 1, "Endless growth purchase did not apply")
	assert(game.equipped_cards.has(growth_id), "First endless growth purchase did not enter the deck")
	assert(game.star_shards < wallet_before, "Endless growth did not consume currency")
	game.close_shop()
	await process_frame

	for id in game.ENDLESS_CARD_IDS:
		game.upgrade_levels[id] = 10
	game.show_shop(true)
	await process_frame
	assert(game.shop_goods.size() >= 3, "Maxed card pool did not receive deterministic fallbacks")
	for offer in game.shop_goods:
		assert(not offer.is_empty(), "Fallback shelf contains an empty offer")
	var supply_index := -1
	for index in game.shop_goods.size():
		if str(game.shop_goods[index].get("kind", "")) == "supply":
			supply_index = index
			break
	if supply_index >= 0:
		var pulses_before: int = game.surge_pulses
		game.purchase_shop_offer(supply_index)
		assert(game.surge_pulses == pulses_before + 3, "Stable shard sink did not grant temporary supply")

	game.close_shop()
	game.endless_wave = 20
	var wave20 = game.spawn_enemy("铁甲怪")
	var health20: float = wave20.max_health
	wave20.queue_free()
	game.endless_wave = 100
	var wave100 = game.spawn_enemy("铁甲怪")
	var health100: float = wave100.max_health
	assert(health100 / health20 > 1.45, "Late endless pressure flattened after player growth capped")
	assert(health100 / health20 < 2.20, "Late endless pressure spikes too sharply between waves 20 and 100")
	print("SHOP_ENDLESS_CLOSURE_OK shelves=", game.shop_goods.size(), " growth=", growth_id, " ratio=", health100 / health20)
	quit()
