extends SceneTree


func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): push_error("LOGIC_CLOSURE_SMOKE_TIMEOUT"); quit(2))
	call_deferred("run_test")


func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame


func run_test() -> void:
	var save = root.get_node_or_null("SaveManager")
	assert(save != null, "SaveManager autoload missing")
	save.data.selected_character = "游侠"
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame

	# A successful offensive cast consumes only the old resonance. Damage generated
	# synchronously by that cast must remain for the next hand.
	var resonance_target = game.spawn_enemy("重甲怪")
	resonance_target.global_position = game.skill_entity_origin("chain") + Vector2(80.0, 0.0)
	resonance_target.speed = 0.0
	resonance_target.max_health = 1000.0
	resonance_target.health = 1000.0
	game.resonance = 40.0
	game.pet_energy["chain"] = game.pet_energy_requirement("chain")
	assert(game.try_release_charged_pet("chain"), "Charged chain pet did not release")
	assert(game.resonance > 0.0 and game.resonance < 40.0, "Fresh resonance was erased with the spent pool")

	# Echo replays 55% of the captured hit and does not use a generic fabricated base.
	game.card_editions["chain"] = "echo"
	game.pet_energy["chain"] = game.pet_energy_requirement("chain")
	assert(game.try_release_charged_pet("chain"), "Echo chain pet did not release")
	var health_after_primary: float = resonance_target.health
	await create_timer(0.35).timeout
	assert(resonance_target.health < health_after_primary, "Echo did not replay captured skill damage")
	assert(not game.echo_pending.has("chain"), "Echo pending state did not close")
	game.card_editions.erase("chain")
	await clear_enemies()

	# Pure utility pets preserve offensive resonance.
	game.equipped_cards.assign(["gravity_well"])
	game.upgrade_levels["gravity_well"] = 1
	game.refresh_derived_card_effects()
	await process_frame
	var gravity_target = game.spawn_enemy("重甲怪")
	gravity_target.global_position = game.skill_entity_origin("gravity_well") + Vector2(80.0, 0.0)
	gravity_target.speed = 0.0
	game.resonance = 30.0
	game.pet_energy["gravity_well"] = game.pet_energy_requirement("gravity_well")
	assert(game.try_release_charged_pet("gravity_well"), "Charged gravity pet did not release")
	assert(is_equal_approx(game.resonance, 30.0), "Utility pet consumed offensive resonance")
	await clear_enemies()

	# Foil status strength follows the source pet edition.
	var plain_burn = game.spawn_enemy("重甲怪")
	var foil_burn = game.spawn_enemy("重甲怪")
	game.card_editions.erase("chain")
	game.apply_chain_status(plain_burn, "burn", 1, "chain")
	game.card_editions["chain"] = "foil"
	game.apply_chain_status(foil_burn, "burn", 1, "chain")
	assert(absf(foil_burn.burn_dps / plain_burn.burn_dps - 1.15) < 0.001, "Foil pet edition did not strengthen its status")
	game.card_editions.erase("chain")
	await clear_enemies()

	# Execute must consume one charge on a non-lethal hit and affect only one target.
	game.equipped_cards.assign(["execute"])
	game.upgrade_levels["execute"] = 1
	game.refresh_derived_card_effects()
	await process_frame
	var execute_targets: Array = []
	for offset in [Vector2(50.0, 0.0), Vector2(70.0, 0.0)]:
		var target = game.spawn_enemy("重甲怪")
		target.global_position = game.skill_entity_origin("execute") + offset
		target.speed = 0.0
		target.max_health = 1000.0
		target.health = 190.0
		execute_targets.append(target)
	game.stats.damage = 0.1
	var execute_requirement: float = game.pet_energy_requirement("execute")
	game.pet_energy["execute"] = execute_requirement
	assert(game.try_release_charged_pet("execute"), "Non-lethal execute hit was treated as a failed cast")
	assert(float(game.pet_energy["execute"]) < 0.01, "Non-lethal execute did not consume energy")
	var damaged_targets := execute_targets.filter(func(target): return target.health < 190.0)
	assert(damaged_targets.size() == 1, "Execute still damaged every eligible target")
	game.stats.damage = 1.0
	await clear_enemies()

	# Phase step keeps its stored energy while cooling down and cannot chain i-frames.
	game.equipped_cards.assign(["phase_step"])
	game.upgrade_levels["phase_step"] = 1
	game.refresh_derived_card_effects()
	await process_frame
	var phase_target = game.spawn_enemy("追猎者")
	phase_target.global_position = game.skill_entity_origin("phase_step") + Vector2(90.0, 0.0)
	phase_target.speed = 0.0
	var phase_requirement: float = game.pet_energy_requirement("phase_step")
	game.pet_energy["phase_step"] = phase_requirement
	game.phase_step_cooldown = 0.4
	assert(not game.try_release_charged_pet("phase_step"), "Phase step ignored its independent cooldown")
	assert(is_equal_approx(float(game.pet_energy["phase_step"]), phase_requirement), "Phase cooldown discarded stored energy")
	game.phase_step_cooldown = 0.0
	game.player.invulnerable = 0.0
	assert(game.try_release_charged_pet("phase_step"), "Ready phase step did not release")
	assert(game.phase_step_cooldown >= game.PHASE_STEP_COOLDOWN - 0.01, "Phase cooldown was not started")
	assert(game.player.invulnerable <= game.PHASE_STEP_INVULNERABILITY + 0.01, "Phase invulnerability remains long enough to chain permanently")
	await clear_enemies()

	# Glass restores exactly what the health floor allowed it to remove.
	game.equipped_cards.assign(["chain"])
	game.upgrade_levels.erase("glass")
	game.player.max_health = 25.0
	game.player.health = 25.0
	game.state = game.GameState.LEVEL_UP
	game.pending_levels = 1
	game.apply_upgrade("glass")
	assert(is_equal_approx(game.player.max_health, 20.0), "Glass did not respect the health floor")
	game.equipped_cards.erase("glass")
	game.remove_slot_card_effect("glass")
	assert(is_equal_approx(game.player.max_health, 25.0), "Glass refunded more health than it removed")

	# Level-zero starter pets must not retain paid metadata after removal.
	game.equipped_cards.append("aura")
	game.upgrade_levels.erase("aura")
	game.card_editions["aura"] = "polychrome"
	game.card_seals["aura"] = "gold"
	game.card_drawbacks["aura"] = "rental"
	game.equipped_cards.erase("aura")
	game.remove_slot_card_effect("aura")
	assert(not game.card_editions.has("aura") and not game.card_seals.has("aura") and not game.card_drawbacks.has("aura"), "Level-zero pet metadata survived removal")

	# Every positive shop-side income must service rental debt before the wallet.
	game.star_shards = 0
	game.rental_debt = 3
	game.credit_star_shards(5)
	assert(game.rental_debt == 0 and game.star_shards == 2, "Shop-side income bypassed rental debt")

	# Sequence pattern and seal compatibility must reflect actual trigger rules.
	game.equipped_cards.assign(["sequence_protocol", "glass", "burn", "chain"])
	assert(game.has_valid_sequence_protocol(), "Valid four-card sequence was not recognized")
	game.equipped_cards.assign(["sequence_protocol", "glass", "chain", "burn"])
	assert(not game.has_valid_sequence_protocol(), "Misplaced sequence protocol still granted its pattern")
	game.equipped_cards.assign(["glass", "chain", "aegis"])
	assert(game.compatible_seals_for_card("glass") == ["white"], "Non-pet card received an inert trigger seal")
	assert(game.compatible_seals_for_card("aegis").has("gold") and not game.compatible_seals_for_card("aegis").has("red"), "Utility pet seal compatibility is incorrect")
	assert(game.compatible_editions_for_card("aegis").is_empty(), "Utility pet still received a damage-only edition")

	# Selling every offensive pet is legal. The weak Lone Star spark closes the
	# combat loop, and the next directed offer restores a normal offense pet.
	game.state = game.GameState.PLAYING
	game.equipped_cards.assign(["aegis"])
	game.upgrade_levels["aegis"] = 1
	game.refresh_derived_card_effects()
	assert(game.replacement_keeps_a_pet("aegis"), "Legacy last-pet sale guard is still active")
	assert(game.lone_star_protocol_active(), "Lone Star protocol did not activate without sustainable offense")
	assert(game.directed_shop_pending, "Lone Star protocol did not request a directed shop recovery")
	var spark_target = game.spawn_enemy("重甲怪")
	spark_target.global_position = game.player.global_position + Vector2(80.0, 0.0)
	spark_target.speed = 0.0
	var spark_health: float = spark_target.health
	assert(game.fire_lone_star_spark(), "Lone Star spark found no valid target")
	assert(spark_target.health < spark_health, "Lone Star spark dealt no emergency damage")
	var no_exclusions: Array[String] = []
	var recovery_offer: Dictionary = game.make_directed_build_offer(no_exclusions)
	assert(not recovery_offer.is_empty() and game.is_sustainable_offense_pet(str(recovery_offer.id)), "Directed shop did not offer sustainable offense")
	game.equipped_cards.append("chain")
	game.upgrade_levels["chain"] = 1
	assert(not game.lone_star_protocol_active(), "Lone Star protocol stayed active after offense recovered")
	await clear_enemies()

	# The post-threshold curve remains strictly increasing instead of deleting
	# late positive modifiers at a hard x6 cap.
	assert(is_equal_approx(game.soften_damage_multiplier(6.0), 6.0), "Soft-cap threshold drifted")
	assert(game.soften_damage_multiplier(8.0) > game.soften_damage_multiplier(7.0), "Soft cap has a zero-marginal region")
	assert(game.soften_damage_multiplier(8.0) < 8.0, "Soft cap no longer compresses extreme stacking")
	var capped_base: float = game.soften_damage_multiplier(9.0)
	var capped_boosted: float = game.soften_damage_multiplier(game.raw_damage_multiplier_from_effective(capped_base) * 1.2)
	assert(capped_boosted > capped_base, "Late mastery/hand modifier reduced an already-softened multiplier")

	# Copy cards must implement the advertised damage rule families, including
	# additive, crit and rhythm/economy multipliers.
	game.equipped_cards.assign(["chain", "blueprint", "glass"])
	game.upgrade_levels["glass"] = 1
	var copied_glass: Dictionary = game.copied_card_effect("glass", 0.0, 0, null, 1, false, false)
	var copied_crit: Dictionary = game.copied_card_effect("crit", 0.0, 0, null, 1, false, false)
	var unsupported_copy: Dictionary = game.copied_card_effect("aegis", 0.0, 0, null, 1, false, false)
	assert(float(copied_glass.multiplier) > 1.0 and float(copied_crit.crit_bonus) > 0.0, "Copy rules still silently omit damage modifiers")
	assert(not bool(unsupported_copy.supported), "Utility pet was incorrectly exposed as a copyable damage rule")

	# Suppressed cards no longer contribute tags, adjacency, sequence or energy.
	game.equipped_cards.assign(["sequence_protocol", "glass", "burn", "chain"])
	var unsuppressed_energy: int = game.active_hand_energy(game.active_star_patterns())
	assert(game.active_star_patterns().has("顺序式"), "Sequence precondition missing before suppression")
	game.boss_card_disruptions["glass"] = {"mode":"sealed", "remaining":2.0}
	assert(not game.active_star_patterns().has("顺序式"), "Suppressed middle card still completed sequence pattern")
	assert(game.active_hand_energy(game.active_star_patterns()) < unsuppressed_energy, "Suppressed card still contributed full hand energy")
	game.boss_card_disruptions.clear()

	# Red seals count casts per pet; capped gold/blue seals are not offered.
	game.card_cast_counts = {"chain":5, "aura":4}
	game.card_seals["chain"] = "red"
	assert(int(game.card_cast_counts.chain) % 5 == 0 and int(game.card_cast_counts.aura) % 5 != 0, "Red seal cast counters are not card-local")
	game.core_mastery_ranks["chain"] = game.CORE_MASTERY_MAX_RANK
	for pattern in game.active_star_patterns():
		game.pattern_mastery[pattern] = 3
	var capped_seals: Array[String] = game.compatible_seals_for_card("chain")
	assert(not capped_seals.has("gold") and not capped_seals.has("blue"), "Capped seals remain purchasable with no possible payoff")

	# Echo captures the final post-reaction amount at the damage boundary.
	var echo_target = game.spawn_enemy("重甲怪")
	var echo_capture: Array[Dictionary] = []
	game.echo_damage_captures["nova"] = echo_capture
	game.deal_skill_damage(echo_target, 123.0, "nova", Vector2.ZERO, "reaction")
	assert(echo_capture.size() == 1 and is_equal_approx(float(echo_capture[0].damage), 123.0), "Echo captured a pre-reaction damage snapshot")
	game.echo_damage_captures.erase("nova")
	await clear_enemies()

	# Shuffle is a real Boss disruption, and killing one Boss only clears its records.
	game.equipped_cards.assign(["glass", "chain"])
	game.boss_shuffle_remaining = 1.0
	var shuffled_order: Array[String] = game.equipped_cards.duplicate()
	game.swap_equipped_cards("glass", "chain")
	assert(game.equipped_cards == shuffled_order, "Reverse shuffle could still be bypassed by dragging")
	game.boss_shuffle_remaining = 0.0
	var source_a := Node2D.new()
	var source_b := Node2D.new()
	root.add_child(source_a)
	root.add_child(source_b)
	game.boss_card_disruptions = {
		"glass":{"mode":"sealed", "remaining":2.0, "source":source_a},
		"chain":{"mode":"sealed", "remaining":2.0, "source":source_b}
	}
	game.clear_boss_card_disruptions(source_a)
	assert(not game.boss_card_disruptions.has("glass") and game.boss_card_disruptions.has("chain"), "One Boss death cleared another Boss's disruption")
	source_a.queue_free()
	source_b.queue_free()

	# Danger contract applies the advertised independent health/damage multipliers.
	game.elapsed = 120.0
	game.danger_contract.clear()
	var baseline = game.spawn_enemy("重甲怪")
	var baseline_health: float = baseline.max_health
	var baseline_damage: float = baseline.damage
	baseline.queue_free()
	await process_frame
	game.danger_contract = {"kills":0, "target":25}
	var contracted = game.spawn_enemy("重甲怪")
	assert(absf(contracted.max_health / baseline_health - 1.25) < 0.001, "Danger contract health differs from its tooltip")
	assert(absf(contracted.damage / baseline_damage - 1.18) < 0.001, "Danger contract damage is being amplified twice")

	assert(0.055 > 0.62 * 0.07, "Starfire base heat still decays faster than normal supply can build it")
	print("LOGIC_CLOSURE_SMOKE_OK resonance=", game.resonance, " debt_wallet=", game.star_shards)
	quit()
