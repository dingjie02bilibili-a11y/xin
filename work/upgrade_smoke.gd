extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	# 开局已自带两只宠物，5 格卡组买到第 3 张就满了，后面的会转进替换流程。
	# 本用例只验证「买到的卡是否真的生效」，先腾出空间。
	game.card_slots = 7
	game.equipped_cards.clear()
	# 开局宠物同时写进了 upgrade_levels，不清掉的话再买同一张会被「已达上限」挡下
	game.upgrade_levels.clear()
	game.refresh_derived_card_effects()
	game.show_shop(true)
	for upgrade in ["chain", "nova", "homing", "burn", "satellite_engine"]:
		game.shop_goods = [{"kind":"card", "id":upgrade, "price":0, "sold":false, "locked":false}]
		game.apply_upgrade(upgrade, true, 0, 0)
	assert(game.chain_level == 1 and game.nova_level == 1, "New weapons not enabled")
	assert(game.upgrade_levels.homing == 1 and game.upgrade_levels.burn == 1, "Projectile mods not enabled")
	assert(game.has_orbit, "Satellite engine not enabled")
	game.sell_shop_card("homing")
	game.sell_shop_card("burn")
	for upgrade in ["glass", "gamble"]:
		game.shop_goods = [{"kind":"card", "id":upgrade, "price":0, "sold":false, "locked":false}]
		game.apply_upgrade(upgrade, true, 0, 0)
	assert(game.player.max_health < 100.0 and game.player.armor < 0.0, "Risk cards did not apply costs")
	print("UPGRADE_SMOKE_OK chain=", game.chain_level, " nova=", game.nova_level)
	quit()
