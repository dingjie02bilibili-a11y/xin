extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.equipped_cards.assign(["aura"])
	game.upgrade_levels["aura"] = 1
	game.refresh_derived_card_effects()
	game.refresh_skill_entities()
	await process_frame
	var pet = game.skill_entities["aura"]
	pet.set_process(false)
	pet.global_position = Vector2(1250, 0)
	var boss = game.spawn_enemy("星渊追猎者", true)
	boss.set_physics_process(false)
	boss.global_position = pet.global_position + Vector2(45, 0)
	var boss_health: float = boss.health
	assert(game.nearest_enemy(980.0) == null, "Test boss is still inside the player's old targeting range")
	assert(game.has_any_attack_target(), "Enemy beside a pet is not recognized as an attack target")
	game.pet_energy["aura"] = game.pet_energy_requirement("aura")
	assert(game.try_release_charged_pet("aura"), "Ready pet did not release against nearby boss")
	assert(float(game.pet_energy.get("aura", 0.0)) < game.pet_energy_requirement("aura"), "Pet-centered attack did not consume energy")
	assert(boss.health < boss_health, "Pet-centered skill did not damage the boss beside the pet")
	var old_health: float = boss.health
	boss.global_position = game.player.global_position + Vector2(35, 0)
	game.pet_energy["aura"] = game.pet_energy_requirement("aura")
	assert(not game.try_release_charged_pet("aura"), "Pet released at an enemy outside its own range")
	assert(is_equal_approx(boss.health, old_health), "Pet-centered aura still damages around the player")
	print("PET_ORIGIN_CAST_SMOKE_OK damage=", boss_health - old_health)
	quit()
