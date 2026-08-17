extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func advance_energy_bolts(game, steps := 24) -> void:
	for step in steps:
		for child in game.projectile_root.get_children():
			if is_instance_valid(child) and child is EnergyBolt and not child.is_queued_for_deletion():
				child._process(0.05)

func run_test() -> void:
	var save = root.get_node_or_null("SaveManager")
	assert(save != null, "SaveManager autoload missing")
	save.data.selected_character = "游侠"
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	assert(game.active_core_skill_ids().has("chain"), "Ranger did not start with an energy-receiving pet")
	# 只留弧牙：本用例验证的是「供能弹自身不造成伤害」，
	# 其它开局宠物会在同一轮里顺带开火，掩盖掉这个判定。
	game.equipped_cards.assign(["chain"])
	game.refresh_derived_card_effects()
	await process_frame
	game.pulse_timer = 999.0
	game.spawn_enemy("追猎者")
	await process_frame
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.global_position = game.skill_entity_origin("chain") + Vector2(90, 0)
	enemy.speed = 0.0
	var health_before: float = enemy.health
	game.fire_pulse()
	assert(game.projectile_root.get_child_count() > 0 and game.projectile_root.get_child(0) is EnergyBolt, "Player did not fire a physical energy bolt")
	advance_energy_bolts(game, 60)
	await process_frame
	assert(float(game.pet_energy.get("chain", 0.0)) > 0.0, "Energy bolt did not charge the pet")
	assert(is_equal_approx(enemy.health, health_before), "Player energy bolt directly damaged the enemy")
	game.fire_pulse()
	advance_energy_bolts(game, 60)
	await process_frame
	assert(enemy.health < health_before, "Charged pet did not convert energy into its skill")
	assert(bool(game.skill_cooldown_data("chain").get("energy", false)), "Pet HUD is not reporting energy instead of cooldown")

	game.gain_star_shards(30)
	game.show_shop(true)
	await process_frame
	var deck_before: Array = game.equipped_cards.duplicate()
	var power_before: float = float(game.stats.energy_power)
	game.shop_goods = [{"kind":"card", "id":"damage", "price":5, "sold":false}]
	game.refresh_shop_view()
	await process_frame
	game.purchase_shop_offer(0)
	await process_frame
	await process_frame
	assert(game.equipped_cards == deck_before, "One-use character training occupied a deck slot")
	assert(int(game.upgrade_levels.get("damage", 0)) == 1, "Training rank was not recorded")
	assert(is_equal_approx(float(game.stats.energy_power), power_before + 0.10), "Ranger did not receive the larger specialist training gain")
	game.shop_goods = [{"kind":"card", "id":"damage", "price":7, "sold":false}]
	game.refresh_shop_view()
	await process_frame
	game.purchase_shop_offer(0)
	await process_frame
	await process_frame
	assert(int(game.upgrade_levels.get("damage", 0)) == 2, "Repeatable one-use training could not be purchased again")

	print("PET_ENERGY_LINK_SMOKE_OK energy=", game.pet_energy.get("chain", 0.0), " power=", game.stats.energy_power, " deck=", game.equipped_cards)
	quit()
