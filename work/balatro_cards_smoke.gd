extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func equip(game, ids: Array[String]) -> void:
	game.equipped_cards.clear()
	game.upgrade_levels.clear()
	for id in ids:
		game.equipped_cards.append(id)
		game.upgrade_levels[id] = 1
	game.refresh_derived_card_effects()

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.stats.crit = 0.0
	var target = preload("res://scripts/enemy.gd").new()
	root.add_child(target)
	target.health = 1000.0
	target.max_health = 1000.0
	target.global_position = game.player.global_position + Vector2(320, 0)
	equip(game, ["chain", "empty_stencil"])
	var stencil_damage: float = game.resolve_core_card_chain(10.0, "chain", target)
	if stencil_damage < 13.0: print("FAIL stencil"); quit(); return
	equip(game, ["chain", "loyalty_cycle"])
	game.core_hit_counts["chain"] = 5
	var loyalty_damage: float = game.resolve_core_card_chain(10.0, "chain", target)
	if loyalty_damage < 22.0: print("FAIL loyalty"); quit(); return
	equip(game, ["sequence_protocol", "damage", "cooldown", "chain"])
	var sequence_damage: float = game.resolve_core_card_chain(10.0, "chain", target)
	if sequence_damage < 13.0: print("FAIL sequence"); quit(); return
	equip(game, ["chain", "red_contract", "moon_interest"])
	game.star_shards = 20
	game.show_shop(true)
	game.close_shop()
	if game.red_contract_stacks != 1 or game.star_shards != 22: print("FAIL economy"); quit(); return
	equip(game, ["chain", "campfire", "damage"])
	game.show_shop(true)
	game.sell_shop_card("damage")
	if game.campfire_stacks != 1: print("FAIL campfire"); quit(); return
	game.close_shop()
	# 货架基数会随开店次数增长（prepare_shop_goods 里的 mini(2, (shop_visit-1)/2)），
	# 所以不能钉死数字——这里钉 4 是固定 3 格时代的遗留，第 3 次开店时基数已经是 4。
	# 改成在同一个 shop_visit 下比「有没有杂耍货架」的差值，测的才是这张卡声称的 +1。
	equip(game, ["chain"])
	game.shop_visit = 2
	game.show_shop(true)
	var base_goods: int = game.shop_goods.size()
	if base_goods < game.SHOP_ITEM_COUNT:
		print("FAIL juggler 基准货架只有 %d 件，差值判定失去意义" % base_goods); quit(); return
	game.close_shop()
	equip(game, ["chain", "juggler"])
	game.shop_visit = 2
	game.show_shop(true)
	if game.shop_goods.size() != base_goods + 1:
		print("FAIL juggler 无卡%d 有卡%d" % [base_goods, game.shop_goods.size()]); quit(); return
	game.close_shop()
	equip(game, ["chain", "luchador"])
	var boss = game.spawn_enemy("星渊追猎者", true)
	var test_affixes: Array[String] = ["rapid_pattern", "sealed_hand"]
	boss.set_affixes(test_affixes)
	game.apply_luchador_counter(boss)
	if boss.affixes.size() != 1 or game.equipped_cards.has("luchador"): print("FAIL luchador"); quit(); return
	print("BALATRO_CARDS_SMOKE_OK loyalty=", loyalty_damage, " sequence=", sequence_damage, " 货架 ", base_goods, "->", base_goods + 1, " boss_affixes=", boss.affixes.size())
	quit()
