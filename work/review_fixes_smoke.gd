extends SceneTree


func _initialize() -> void:
	create_timer(8.0).timeout.connect(func(): push_error("REVIEW_FIXES_SMOKE_TIMEOUT"); quit(2))
	call_deferred("run_test")


func run_test() -> void:
	var save = root.get_node_or_null("SaveManager")
	assert(save != null, "SaveManager autoload missing")
	save.data.selected_character = "游侠"

	# Armor must mitigate meaningfully without flattening normal hits to one point.
	var armor_player = (load("res://scripts/player.gd") as Script).new()
	root.add_child(armor_player)
	await process_frame
	armor_player.health = 100.0
	armor_player.armor = 20.0
	armor_player.take_damage(20.0)
	var armor_damage: float = 100.0 - float(armor_player.health)
	assert(armor_damage > 1.0 and armor_damage < 20.0, "Armor still uses an all-or-nothing flat subtraction")
	armor_player.queue_free()
	print("REVIEW_FIXES_STAGE armor")

	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	assert(game.active_core_skill_ids().has("chain"), "Ranger did not start with chain pet")

	# Energy above the release threshold must remain available after the pet casts.
	var target = game.spawn_enemy("追猎者")
	target.global_position = game.skill_entity_origin("chain") + Vector2(90.0, 0.0)
	target.speed = 0.0
	var requirement: float = game.pet_energy_requirement("chain")
	game.pet_energy["chain"] = requirement - 0.20
	game.on_pet_energy_received("chain", 0.50)
	var overflow: float = float(game.pet_energy.get("chain", 0.0))
	assert(overflow > 0.25 and overflow < 0.35, "Pet release discarded overflow energy")
	print("REVIEW_FIXES_STAGE energy")

	# Fragile now has both its advertised reward and a real incoming-damage cost.
	var normal_damage: float = game.calculate_skill_damage(10.0, "chain")
	game.card_drawbacks["chain"] = "fragile"
	game.refresh_derived_card_effects()
	var fragile_damage: float = game.calculate_skill_damage(10.0, "chain")
	assert(fragile_damage > normal_damage * 1.20, "Fragile lost its outgoing damage reward")
	assert(game.player.incoming_damage_multiplier > 1.17, "Fragile still has no incoming-damage drawback")
	game.card_drawbacks.erase("chain")
	game.refresh_derived_card_effects()
	print("REVIEW_FIXES_STAGE fragile")

	# Area checks density around the casting pet, even when that pet is far away.
	for old_enemy in get_nodes_in_group("enemies"):
		old_enemy.queue_free()
	await process_frame
	var chain_pet = game.skill_entities.get("chain")
	chain_pet.global_position = game.player.global_position + Vector2(900.0, 0.0)
	for offset in [Vector2(-40.0, 0.0), Vector2(40.0, 0.0)]:
		var nearby = game.spawn_enemy("追猎者")
		nearby.global_position = chain_pet.global_position + offset
		nearby.speed = 0.0
	game.equipped_cards.append("area")
	game.upgrade_levels["area"] = 1
	assert(game.skill_area_multiplier("chain") > float(game.stats.area) * 1.10, "Area card still checks density around the player")
	print("REVIEW_FIXES_STAGE area")

	# A burn-lethal enemy may not deal one last contact hit in the same frame.
	for old_enemy in get_nodes_in_group("enemies"):
		old_enemy.queue_free()
	await process_frame
	var burning = game.spawn_enemy("追猎者")
	burning.global_position = game.player.global_position
	burning.speed = 0.0
	burning.health = 1.0
	burning.burn_dps = 100.0
	burning.burn_time = 1.0
	game.player.health = game.player.max_health
	game.player.invulnerable = 0.0
	var health_before_burn: float = game.player.health
	burning._physics_process(0.10)
	assert(is_equal_approx(game.player.health, health_before_burn), "Burn-killed enemy dealt a post-mortem contact hit")
	await process_frame
	print("REVIEW_FIXES_STAGE burn")

	# Rental debt survives an empty wallet and is collected from later income.
	game.card_drawbacks["area"] = "rental"
	game.star_shards = 0
	game.show_shop(true)
	await process_frame
	game.close_shop()
	assert(game.rental_debt == 1 and game.star_shards == 0, "Rental maintenance was avoidable with an empty wallet")
	game.gain_star_shards(3)
	assert(game.rental_debt == 0 and game.star_shards == 2, "Later income did not settle rental debt")
	print("REVIEW_FIXES_STAGE rental")

	# Eternal cards cannot be sold indirectly through melt or replacement APIs.
	game.card_drawbacks["area"] = "eternal"
	game.show_shop(true)
	await process_frame
	game.consumable_sigils.clear()
	game.consumable_sigils.append("melt")
	game.use_sigil("melt")
	assert(game.equipped_cards.has("area") and game.consumable_sigils.has("melt"), "Melt consumed an eternal card")
	var deck_before_replace: Array = game.equipped_cards.duplicate()
	game.confirm_shop_replacement("area", "speed", 0, -1)
	assert(game.equipped_cards == deck_before_replace, "Direct replacement bypassed eternal protection")
	game.close_shop()
	print("REVIEW_FIXES_STAGE eternal")

	# Cleanse can be prepared in a shop and blocks the next Boss deck disruption.
	var affix_source = game.spawn_enemy("星渊追猎者", true)
	game.cleanse_ward_charges = 1
	game.boss_affix_pending = false
	game.on_boss_affix_requested(affix_source, "sealed_hand", 5.0)
	assert(game.cleanse_ward_charges == 0 and not game.boss_affix_pending, "Cleanse ward did not block Boss disruption")
	print("REVIEW_FIXES_STAGE cleanse")

	# Simultaneous Boss rewards are serialized instead of replacing one another.
	game.show_boss_reward("first", 1)
	game.show_boss_reward("second", 2)
	assert(game.pending_boss_rewards.size() == 1, "Second Boss reward was not queued")
	game.finish_boss_reward_selection()
	await process_frame
	assert(is_instance_valid(game.boss_reward_overlay) and game.pending_boss_rewards.is_empty(), "Queued Boss reward did not open")
	game.finish_boss_reward_selection()
	await process_frame
	assert(game.state == game.GameState.PLAYING and not game.player.selection_protected, "Reward queue did not resume play")
	print("REVIEW_FIXES_STAGE reward_queue")

	# Sixth-chapter flow now exposes the choice and can enter endless deliberately.
	game.mainline_completion_pending = true
	game.show_boss_reward("chapter_six", 6)
	game.finish_boss_reward_selection()
	await process_frame
	assert(is_instance_valid(game.mainline_complete_overlay), "Sixth chapter did not open completion choice")
	game.continue_to_endless()
	assert(game.endless_mode and game.state == game.GameState.PLAYING, "Continue choice did not enter endless mode")
	print("REVIEW_FIXES_STAGE endless_choice")

	game.queue_free()
	await process_frame

	# The other completion choice reaches the formerly unreachable victory ending.
	var victory_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	victory_game.test_mode = true
	root.add_child(victory_game)
	await process_frame
	victory_game.start_game_after_prologue()
	await process_frame
	victory_game.mainline_completion_pending = true
	victory_game.show_mainline_completion_choice()
	assert(is_instance_valid(victory_game.mainline_complete_overlay), "Completion overlay could not open")
	victory_game.complete_mainline_run()
	assert(victory_game.finished_run and victory_game.state == victory_game.GameState.GAME_OVER, "Victory settlement remains unreachable")

	print("REVIEW_FIXES_SMOKE_OK armor_damage=", armor_damage, " overflow=", overflow)
	victory_game.queue_free()
	await process_frame
	quit()
