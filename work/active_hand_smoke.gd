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
	# 有有效目标时，应由自动战斗生成攻击并进入结算冷却。
	var enemy = game.spawn_enemy("追踪怪")
	enemy.global_position = game.player.global_position + Vector2(180, 0)
	var pet_id: String = game.active_core_skill_ids()[0]
	game.pet_energy[pet_id] = game.pet_energy_requirement(pet_id)
	game._process(0.25)
	# 充能已从「发射弹丸」改为「沿链条连续注入」，所以不再有飞行物，
	# 而且同一帧内每只连着链条的宠物都会拿到能量，释放次数可能多于一次。
	assert(game.hands_played >= 1, "Nearby target did not trigger automatic pet combat")
	assert(float(game.pet_energy.get(pet_id, 0.0)) < game.pet_energy_requirement(pet_id), "Pet release did not consume stored energy")
	assert(game.projectile_root.get_child_count() == 0, "Tether supply should not spawn flying bolts")

	# 链条被切断后，宠物必须彻底停摆：既不接收能量，也不释放技能。
	var cutter = game.spawn_enemy("铁甲怪")
	game.cut_pet_tether(pet_id, cutter)
	assert(not game.pet_link_connected(pet_id), "Tether did not register as cut")
	game.pet_energy[pet_id] = game.pet_energy_requirement(pet_id)
	# hands_played 是全局计数，其它仍连着的宠物照常释放；要看的是这只被切断的宠物。
	var severed_casts: int = int(game.card_cast_counts.get(pet_id, 0))
	game._process(0.25)
	assert(int(game.card_cast_counts.get(pet_id, 0)) == severed_casts, "Severed pet still released its skill")
	assert(not game.selectable_energy_pet_ids().has(pet_id), "Severed pet still received energy")
	# 走到宠物身边即可重新接上
	var severed_entity = game.skill_entities.get(pet_id)
	game.player.global_position = severed_entity.global_position
	game._process(0.05)
	assert(game.pet_link_connected(pet_id), "Touching the pet did not restore the tether")
	# 清空敌人后，自动循环不得空放或消耗新一轮结算。
	for node in get_nodes_in_group("enemies"):
		node.queue_free()
	await process_frame
	game.pet_energy[pet_id] = game.pet_energy_requirement(pet_id)
	var played_before: int = game.hands_played
	game._process(0.25)
	assert(game.hands_played == played_before, "Automatic combat fired without a target")
	print("AUTO_PET_SMOKE_OK hands=", game.hands_played, " energy=", game.last_hand_energy)
	quit()
