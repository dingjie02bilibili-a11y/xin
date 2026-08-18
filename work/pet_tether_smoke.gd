extends SceneTree
# 供能链路：玩家与宠物之间是一条持续的能量通道，能量沿它连续注入；
# 敌人挤进玩家与宠物之间会切断链条，宠物随即停摆，走过去才能重新接上。

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var save = root.get_node_or_null("SaveManager")
	assert(save != null, "SaveManager autoload missing")
	save.data.selected_character = "游侠"
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	assert(game.active_core_skill_ids().has("chain"), "Ranger did not start with an energy-receiving pet")
	game.equipped_cards.assign(["chain"])
	game.refresh_derived_card_effects()
	await process_frame

	var enemy = game.spawn_enemy("追猎者")
	enemy.global_position = game.skill_entity_origin("chain") + Vector2(90, 0)
	enemy.speed = 0.0
	var health_before: float = enemy.health

	# 供能是连续注入，不再产生任何飞行物
	game.pet_energy["chain"] = 0.0
	game.fire_pulse()
	assert(float(game.pet_energy.get("chain", 0.0)) > 0.0, "Tether did not feed the pet")
	assert(game.projectile_root.get_child_count() == 0, "Tether supply still spawns flying bolts")
	assert(is_equal_approx(enemy.health, health_before), "Energy supply itself damaged the enemy")

	# 攒满后由宠物把能量转成技能，超出阈值的部分保留给下一次
	var requirement: float = game.pet_energy_requirement("chain")
	game.pet_energy["chain"] = requirement + 0.30
	assert(game.try_release_charged_pet("chain"), "Charged pet did not convert energy into its skill")
	assert(enemy.health < health_before, "Pet release dealt no damage")
	assert(float(game.pet_energy.get("chain", 0.0)) > 0.25, "Pet release discarded overflow energy")
	assert(bool(game.skill_cooldown_data("chain").get("energy", false)), "Pet HUD is not reporting energy instead of cooldown")

	# 切断：宠物被弹开、停摆，并且不再接收能量
	var cutter = game.spawn_enemy("重甲怪")
	var pet_before: Vector2 = game.skill_entity_origin("chain")
	game.cut_pet_tether("chain", cutter)
	assert(not game.pet_link_connected("chain"), "Tether did not register as cut")
	assert(game.skill_entity_origin("chain").distance_to(pet_before) > 40.0, "Severed pet was not knocked loose")
	game.pet_energy["chain"] = requirement
	var casts_before: int = int(game.card_cast_counts.get("chain", 0))
	game._process(0.2)
	assert(int(game.card_cast_counts.get("chain", 0)) == casts_before, "Severed pet still released its skill")
	assert(game.selectable_energy_pet_ids().is_empty(), "Severed pet still received energy")

	# 重连：玩家走到宠物身边即可恢复
	game.player.global_position = game.skill_entity_origin("chain")
	game._process(0.05)
	assert(game.pet_link_connected("chain"), "Touching the pet did not restore the tether")
	assert(not game.selectable_energy_pet_ids().is_empty(), "Reconnected pet still refuses energy")

	print("PET_TETHER_SMOKE_OK energy=", game.pet_energy.get("chain", 0.0))
	quit()
