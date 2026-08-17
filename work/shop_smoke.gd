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
	assert(game.star_shards == 0, "Run did not start with an empty wallet")
	game.gain_star_shards(30)
	assert(game.star_shards == 30 and game.total_star_shards == 30, "Shard wallet did not update")
	assert(game.state == game.GameState.PLAYING and game.shop_overlay == null, "Collecting shards incorrectly opened a selection")
	game.show_shop(true)
	await process_frame
	assert(game.shop_overlay != null and game.shop_goods.size() == 3, "Shop did not build three offers")
	assert(game.state == game.GameState.LEVEL_UP and game.player.selection_protected, "Shop did not pause and protect the player")
	var card_offer_index := -1
	for index in game.shop_goods.size():
		if str(game.shop_goods[index].kind) == "card":
			card_offer_index = index
			break
	assert(card_offer_index >= 0, "Shop did not offer a card")
	var offer: Dictionary = game.shop_goods[card_offer_index]
	var before_wallet: int = game.star_shards
	game.purchase_shop_offer(card_offer_index)
	await process_frame
	if game.is_training_card(str(offer.id)):
		assert(not game.equipped_cards.has(str(offer.id)), "Disposable training card incorrectly occupied a slot")
	else:
		assert(game.equipped_cards.has(str(offer.id)), "Purchased slot card was not equipped")
	assert(game.star_shards == before_wallet - int(offer.price), "Purchase did not spend shards")
	assert(int(game.upgrade_levels.get(str(offer.id), 0)) == 1, "Purchased card did not receive its single base state")
	game.close_shop()
	await process_frame
	assert(game.state == game.GameState.PLAYING and not game.player.selection_protected, "Leaving shop did not resume play")
	var before_pickup: int = game.star_shards
	game.spawn_pickup("shard", 3, game.player.global_position)
	game.process_pickups(0.1)
	assert(game.star_shards == before_pickup + 3, "Shard pickup did not enter wallet")
	game.gain_star_shards(30)
	game.next_shop_time = game.elapsed
	game._process(0.01)
	await process_frame
	assert(game.shop_overlay != null, "Scheduled wave shop did not open")
	var incoming_index := -1
	for index in game.shop_goods.size():
		if str(game.shop_goods[index].kind) == "card" and game.is_slot_card(str(game.shop_goods[index].id)):
			incoming_index = index
			break
	if incoming_index < 0:
		incoming_index = 0
		var fallback_id := "nova"
		for candidate in ["nova", "aura", "orbit", "thunder_orb"]:
			if not game.equipped_cards.has(candidate):
				fallback_id = candidate
				break
		game.shop_goods[incoming_index] = {"kind":"card", "id":fallback_id, "price":game.card_shop_price(fallback_id), "sold":false}
	assert(incoming_index >= 0, "Second shop did not offer a replacement card")
	var incoming: Dictionary = game.shop_goods[incoming_index]
	for filler in ["damage", "cooldown", "speed", "health", "armor", "regen", "magnet"]:
		if game.equipped_cards.size() >= game.card_slots:
			break
		if filler != str(incoming.id) and not game.equipped_cards.has(filler):
			game.equipped_cards.append(filler)
			game.upgrade_levels[filler] = 1
	assert(game.equipped_cards.size() == game.card_slots, "Test deck did not reach slot cap")
	var owned_id: String = game.equipped_cards[-1]
	var refund: int = game.card_sell_value(owned_id)
	var before_replace: int = game.star_shards
	game.purchase_shop_offer(incoming_index)
	assert(game.card_replace_overlay != null, "Full deck did not open replacement overlay")
	game.confirm_shop_replacement(owned_id, str(incoming.id), int(incoming.price), incoming_index)
	assert(game.equipped_cards.has(str(incoming.id)) and not game.equipped_cards.has(owned_id), "Replacement did not exchange cards")
	assert(game.star_shards == before_replace + refund - int(incoming.price), "Sale credit was not applied to replacement")
	var sale_id := str(incoming.id)
	var sale_refund: int = game.card_sell_value(sale_id)
	var before_sale: int = game.star_shards
	game.sell_shop_card(sale_id)
	assert(not game.equipped_cards.has(sale_id), "Sold card remained equipped")
	assert(game.star_shards == before_sale + sale_refund, "Card sale did not return shards")
	print("SHOP_SMOKE_OK wallet=", game.star_shards, " offers=", game.shop_goods.size(), " cards=", game.equipped_cards.size())
	quit()
