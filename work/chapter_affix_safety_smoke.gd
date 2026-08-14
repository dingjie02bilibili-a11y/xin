extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	assert(game.normally_castable_pet_ids().size() == 1, "Safety test needs one starting pet")
	for style in ["pursuit", "control", "burst"]:
		for sample in 40:
			var first_affixes: Array[String] = game.roll_boss_affixes(1, style)
			for forbidden in ["sealed_hand", "pet_thief", "pet_charm", "reverse_shuffle"]:
				assert(not first_affixes.has(forbidden), "Chapter 1 rolled a deprivation affix: " + forbidden)
	assert(game.boss_disruption_affix_pool(2, "control").all(func(id): return id == "reverse_shuffle"), "Chapter 2 contains a high-pressure disruption")
	assert(not game.boss_disruption_affix_pool(4, "control").has("pet_thief") and not game.boss_disruption_affix_pool(4, "control").has("pet_charm"), "Pet control unlocked before chapter 5")
	assert(not game.boss_disruption_affix_pool(6, "pursuit").has("pet_thief") and not game.boss_disruption_affix_pool(6, "pursuit").has("pet_charm"), "Pursuit boss received an unfair pet-recovery affix")

	var boss = game.spawn_enemy("星渊禁锢者", true)
	await process_frame
	for deprivation in ["sealed_hand", "pet_thief", "pet_charm"]:
		match deprivation:
			"sealed_hand": game.apply_boss_card_seal(boss, 4.2)
			"pet_thief": game.apply_boss_pet_theft(boss, 5.2)
			"pet_charm": game.apply_boss_pet_charm(boss, 4.5)
		assert(game.normally_castable_pet_ids().size() == 1, "Final pet was disabled by " + deprivation)
		assert(game.boss_card_disruptions.is_empty(), "Safety fallback left a disruption record")

	game.equipped_cards.append("aura")
	game.upgrade_levels["aura"] = 1
	game.refresh_derived_card_effects()
	game.refresh_skill_entities()
	var late_control_pool: Array[String] = game.boss_disruption_affix_pool(5, "control")
	assert(late_control_pool.has("pet_thief") or late_control_pool.has("pet_charm"), "Chapter 5 control boss did not unlock high-pressure pet play")
	game.apply_boss_pet_theft(boss, 5.2)
	assert(game.boss_card_disruptions.size() == 1 and game.normally_castable_pet_ids().size() == 1, "Two-pet theft did not preserve one caster")
	game.clear_boss_card_disruptions()
	assert(game.normally_castable_pet_ids().size() == 2 and game.boss_card_disruptions.is_empty(), "Boss cleanup did not restore pets")
	game.apply_boss_pet_charm(boss, 4.5)
	assert(game.boss_card_disruptions.size() == 1 and game.normally_castable_pet_ids().size() == 1, "Two-pet charm did not preserve one caster")
	game.clear_boss_card_disruptions()
	assert(game.normally_castable_pet_ids().size() == 2, "Charm cleanup did not restore pets")
	print("CHAPTER_AFFIX_SAFETY_OK chapter1_safe=true chapter5_high_pressure=true")
	quit()
