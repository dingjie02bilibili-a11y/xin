extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var save = root.get_node_or_null("SaveManager")
	assert(save != null, "SaveManager autoload missing")
	save.data.selected_character = "游侠"
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame

	var phase_energy_before: float = game.pet_energy_requirement("phase_step")
	var supply_interval_before: float = game.energy_shot_interval()
	var speed_before: float = game.player.speed
	game.select_boss_relic("predator_boots")
	assert(game.player.speed > speed_before, "Character relic did not improve player speed")
	assert(game.energy_shot_interval() < supply_interval_before, "Character relic did not improve supply interval")
	assert(is_equal_approx(game.pet_energy_requirement("phase_step"), phase_energy_before), "Character relic still modified pet energy requirement")

	var health_before: float = game.player.max_health
	var armor_before: float = game.player.armor
	var aegis_energy_before: float = game.pet_energy_requirement("aegis")
	game.select_boss_relic("aegis_fragment")
	assert(is_equal_approx(game.player.max_health, health_before + 12.0), "Aegis character relic did not add health")
	assert(is_equal_approx(game.player.armor, armor_before + 1.0), "Aegis character relic did not add armor")
	assert(game.player.shield_charges >= 1, "Aegis character relic did not grant a shield")
	assert(is_equal_approx(game.pet_energy_requirement("aegis"), aegis_energy_before), "Character relic still modified Aegis pet energy")
	assert(not game.active_core_skill_ids().has("aegis"), "Character relic incorrectly granted an unequipped pet")

	var base_area: float = game.skill_area_multiplier("chain")
	game.select_boss_relic("rift_compass")
	assert(is_equal_approx(game.skill_area_multiplier("chain"), base_area * 1.15), "Rift compass global pet range was not applied")
	assert(is_equal_approx(game.skill_area_multiplier("gravity_well"), base_area * 1.15 * 1.35), "Rift compass gravity bonus was not applied")

	var crit_before: float = float(game.stats.crit)
	game.select_boss_relic("judge_spark")
	assert(is_equal_approx(float(game.stats.crit), minf(0.85, crit_before + 0.10)), "Judge spark did not improve pet crit")
	assert(is_equal_approx(game.bonus_crit_damage, 0.20), "Judge spark did not improve pet crit damage")

	game.spawn_enemy("追猎者")
	await process_frame
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.speed = 0.0
	enemy.global_position = game.skill_entity_origin("chain") + Vector2(80, 0)
	game.select_boss_relic("ember_vessel")
	game.calculate_skill_damage(10.0, "chain", enemy)
	assert(enemy.burn_time > 0.0 and enemy.burn_dps > 0.0, "Ember vessel did not apply real burn on pet hit")

	game.select_boss_relic("storm_relay")
	assert(not game.active_core_skill_ids().has("thunder_orb"), "Storm pet relic incorrectly granted an unequipped pet")
	assert(game.relic_rank("storm_relay") == 1, "Storm relic rank was not recorded")
	game.select_boss_relic("storm_relay")
	game.select_boss_relic("storm_relay")
	game.select_boss_relic("storm_relay")
	assert(game.relic_rank("storm_relay") == 3, "Relic resonance did not stop at rank 3")

	print("RELIC_LOGIC_SMOKE_OK ranks=", game.active_relics, " interval=", game.energy_shot_interval())
	quit()
