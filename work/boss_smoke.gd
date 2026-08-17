extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	for style in ["pursuit", "control", "burst"]:
		for sample in 20:
			var chapter_one_affixes: Array[String] = game.roll_boss_affixes(1, style)
			for forbidden in ["sealed_hand", "pet_thief", "pet_charm", "reverse_shuffle"]:
				assert(not chapter_one_affixes.has(forbidden), "Chapter 1 rolled deprivation: " + forbidden)
	# 只剩一只宠物时不应被封印/夺走/魅惑，自行构造该状态再验证
	game.equipped_cards.assign([str(game.active_core_skill_ids()[0])])
	game.refresh_derived_card_effects()
	await process_frame
	var safety_boss = game.spawn_enemy("星渊禁锢者", true)
	game.apply_boss_card_seal(safety_boss, 4.2)
	game.apply_boss_pet_theft(safety_boss, 5.2)
	game.apply_boss_pet_charm(safety_boss, 4.5)
	assert(game.normally_castable_pet_ids().size() == 1 and game.boss_card_disruptions.is_empty(), "Single-pet protection failed")
	safety_boss.queue_free()
	await process_frame
	print("BOSS_SMOKE_START")
	game.player.selection_protected = true
	for boss_kind in ["星渊追猎者", "星渊禁锢者", "星渊裁决者"]:
		game.spawn_enemy(boss_kind, true)
	var bosses := get_nodes_in_group("bosses")
	assert(bosses.size() == 3, "Expected all three boss profiles")
	var first_affixes: Array[String] = ["rapid_pattern", "prism_shield"]
	var second_affixes: Array[String] = ["riftfield", "exposed_core"]
	var third_affixes: Array[String] = ["rapid_pattern", "exposed_core"]
	bosses[0].set_affixes(first_affixes)
	bosses[0].set_chapter_tier(1)
	bosses[1].set_affixes(second_affixes)
	bosses[1].set_chapter_tier(5)
	bosses[2].set_affixes(third_affixes)
	bosses[2].set_chapter_tier(6)
	for i in 90:
		for boss in bosses:
			if is_instance_valid(boss): boss._physics_process(0.05)
		await process_frame
	print("BOSS_SMOKE_MID hazards=", game.hazard_root.get_child_count())
	for i in 120:
		for boss in bosses:
			if is_instance_valid(boss): boss._physics_process(0.05)
		await process_frame
	assert(game.hazard_root.get_child_count() > 0, "Rift/control hazards did not trigger")
	assert(game.projectile_root.get_child_count() > 0, "Burst attack did not trigger")
	print("BOSS_SMOKE_OK bosses=", bosses.size(), " hazards=", game.hazard_root.get_child_count())
	quit()
