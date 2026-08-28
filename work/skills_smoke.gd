extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func give(game, id: String) -> void:
	if game.shop_overlay == null:
		game.show_shop(true)
	game.shop_goods = [{"kind":"card", "id":id, "price":0, "sold":false, "locked":false}]
	game.apply_upgrade(id, true, 0, 0)

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	# 开局带两只宠物会把 5 格卡组撑满并触发替换流程；本用例只验证技能是否生效。
	game.card_slots = 7
	game.equipped_cards.clear()
	game.refresh_derived_card_effects()
	for id in ["phase_step", "thunder_orb", "frost_brand", "soul_siphon"]:
		give(game, id)
	assert(game.phase_step_enabled and game.thunder_level == 1 and game.soul_siphon_level == 1, "New skill upgrades did not apply")
	var initial: Vector2 = game.player.position
	game.use_phase_step()
	assert(game.player.position.distance_to(initial) > 200.0 and game.player.invulnerable > 0.0, "Phase step did not move or protect player")
	var enemy = game.spawn_enemy("追踪怪")
	enemy.apply_frost(1.0)
	assert(enemy.frost_time > 0.0, "Frost effect did not apply")
	print("SKILLS_SMOKE_OK dash=", game.player.position.distance_to(initial), " thunder=", game.thunder_level)
	quit()
