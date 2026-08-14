extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
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
