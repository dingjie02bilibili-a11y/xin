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
	var enemy = game.spawn_enemy("追猎者")
	enemy.global_position = game.player.global_position + Vector2(180, 0)
	var pet_id: String = game.active_core_skill_ids()[0]
	game.pet_energy[pet_id] = game.pet_energy_requirement(pet_id)
	var before_projectiles: int = game.projectile_root.get_child_count()
	game._process(0.25)
	assert(game.hands_played == 1, "Nearby target did not trigger automatic pet combat")
	assert(game.projectile_root.get_child_count() > before_projectiles, "Automatic combat did not create a projectile")
	assert(float(game.pet_energy.get(pet_id, 0.0)) < game.pet_energy_requirement(pet_id), "Pet release did not consume stored energy")
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
