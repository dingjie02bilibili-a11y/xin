extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame

	assert(game.card_shop_price("damage") >= 5, "Common card is still too cheap")
	var prices: Array[int] = []
	for rarity in ["普通", "稀有", "史诗", "传奇"]:
		var matching = game.UPGRADES.filter(func(card): return game.card_rarity(str(card.id)) == rarity)
		assert(not matching.is_empty(), "Missing rarity for economy test: %s" % rarity)
		prices.append(game.card_shop_price(str(matching[0].id)))
	assert(prices == [5, 8, 11, 15], "Card rarity prices are not properly separated")

	seed(1337)
	var ordinary_income := 0
	for index in 200:
		ordinary_income += game.roll_enemy_shard_reward(false, "追迹者")
	assert(ordinary_income > 35 and ordinary_income < 90, "Ordinary enemy income is not probabilistic and controlled")
	assert(game.roll_enemy_shard_reward(false, "重甲怪") == 2, "Elite shard reward changed unexpectedly")
	assert(game.roll_enemy_shard_reward(true, "Boss") == 6, "First Boss shard reward is not controlled")

	game.gain_star_shards(20)
	game.show_shop(true)
	await process_frame
	game.shop_goods = [
		{"kind":"heal", "id":"field_heal", "price":4, "sold":false},
		{"kind":"heal", "id":"field_heal", "price":4, "sold":false},
		{"kind":"heal", "id":"field_heal", "price":4, "sold":false}
	]
	game.refresh_shop_view()
	await process_frame
	var wallet_before: int = game.star_shards
	game.purchase_shop_offer(0)
	await process_frame
	await process_frame
	game.purchase_shop_offer(1)
	await process_frame
	await process_frame
	assert(game.star_shards == wallet_before - 8, "Shop incorrectly limits multiple purchases despite sufficient funds")
	assert(bool(game.shop_goods[0].sold) and bool(game.shop_goods[1].sold), "Purchased offers were not marked sold")
	assert((game.shop_wallet_label as Label).text == "◆ 星屑 %d" % game.star_shards, "Shop wallet still exposes a purchase quota")

	print("SHOP_ECONOMY_PACING_OK ordinary_200=", ordinary_income, " prices=", prices, " wallet=", game.star_shards)
	quit()
