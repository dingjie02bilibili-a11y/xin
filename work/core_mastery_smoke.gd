extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func grant_core(game, id: String) -> void:
	if not game.equipped_cards.has(id):
		game.equipped_cards.append(id)
	game.upgrade_levels[id] = 1
	game.refresh_derived_card_effects()

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	assert(game.CORE_MASTERY_RULES.size() == game.CORE_SKILL_CARD_IDS.size(), "Not every core pet has a mastery rule")
	grant_core(game, "aura")
	var requirement: int = game.core_mastery_requirement("aura")
	for i in requirement:
		game.elapsed += 2.0
		game.record_core_mastery("aura")
	assert(game.core_mastery_rank("aura") == 1, "Aura did not rank up from its condition counter")
	assert(game.core_mastery_damage_factor("aura") > 1.0, "Mastery rank did not improve core damage")
	var aura_tip: String = game.skill_description("aura")
	assert("升级条件：" in aura_tip and "★1" in aura_tip, "Concise mastery condition is missing from the tooltip")
	assert(not "卡牌版本" in aura_tip and not "占用1格" in aura_tip, "Tooltip still contains verbose deck metadata")
	for angle in [0.0, 1.57, 3.14, 4.71]:
		var aura_enemy = game.spawn_enemy("重甲怪")
		aura_enemy.global_position = game.player.global_position + Vector2.from_angle(angle) * 45.0
	game.elapsed += 2.0
	game.fire_aura()
	assert(int(game.core_mastery_progress.get("aura", 0)) == 1, "Aura multi-hit condition did not advance mastery")
	grant_core(game, "phase_step")
	var start: Vector2 = game.player.global_position
	for x in [95.0, 185.0]:
		var enemy = game.spawn_enemy("重甲怪")
		enemy.global_position = start + Vector2(x, 0)
	game.player.rotation = 0.0
	game.phase_step_cooldown = 0.0
	game.use_phase_step()
	assert(int(game.core_mastery_progress.get("phase_step", 0)) == 1, "Phase step did not count enemies crossed along its path")
	grant_core(game, "aegis")
	game.player.shield_charges = 1
	game.player.invulnerable = 0.0
	game.elapsed += 2.0
	game.player.take_damage(20.0)
	assert(int(game.core_mastery_progress.get("aegis", 0)) == 1, "Aegis block did not advance mastery")
	for i in 80:
		game.elapsed += 3.0
		game.record_core_mastery("aura")
	assert(game.core_mastery_rank("aura") == game.CORE_MASTERY_MAX_RANK, "Mastery exceeded or failed to reach its cap")
	game.remove_slot_card_effect("aura")
	assert(game.core_mastery_rank("aura") == 0, "Selling a core pet did not clear its run mastery")
	print("CORE_MASTERY_SMOKE_OK phase=", game.core_mastery_progress.get("phase_step", 0), " aegis=", game.core_mastery_progress.get("aegis", 0))
	quit()
