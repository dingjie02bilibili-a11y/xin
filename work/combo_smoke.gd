extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func give(game, id: String) -> void:
	if int(game.upgrade_levels.get(id, 0)) > 0:
		return
	if game.shop_overlay == null:
		game.show_shop(true)
	game.shop_goods = [{"kind":"card", "id":id, "price":0, "sold":false, "locked":false}]
	game.apply_upgrade(id, true, 0, 0)

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	# Two threshold evolutions and the streak reward.
	for id in ["burn", "chain", "aura", "satellite_engine", "momentum"]:
		give(game, id)
	assert(game.evolutions.has("molten_circuit"), "Molten Circuit did not unlock")
	assert(game.evolutions.has("stellar_lattice"), "Stellar Lattice did not unlock")
	assert(game.momentum_enabled, "Streak card did not unlock")
	# Satellite card can never reduce an existing formation.
	game.orbit_count = 5
	give(game, "orbit")
	assert(game.orbit_count >= 5, "Orbit upgrade reduced satellite count")
	# Critical chance is hard capped.
	give(game, "gamble")
	assert(game.stats.crit <= 0.85, "Critical cap exceeded")
	# Element reaction consumes burn on an enemy and shield only reduces pulse-tagged damage.
	var target = preload("res://scripts/enemy.gd").new()
	root.add_child(target)
	target.health = 100.0
	target.max_health = 100.0
	target.burn_time = 2.0
	target.burn_dps = 8.0
	assert(target.apply_shock(), "Burn + shock reaction did not trigger")
	assert(target.health < 80.0, "Reaction damage was not applied")
	target.health = 100.0
	target.shield_time = 2.0
	target.take_damage(10.0, Vector2.ZERO, "direct")
	assert(is_equal_approx(target.health, 90.0), "Prism shield must not reduce skill damage")
	# 蓝色护盾真正生效的地方是充能：蓝盾期间能量弹只送一半能量。
	target.is_boss = true
	target.set_affixes(["prism_shield"] as Array[String])
	target.add_to_group("bosses")
	var pet_id: String = str(game.active_core_skill_ids()[0])
	game.pet_energy[pet_id] = 0.0
	game.on_pet_energy_received(pet_id, 0.4)
	var shielded_gain: float = float(game.pet_energy.get(pet_id, 0.0))
	target.shield_time = 0.0
	game.pet_energy[pet_id] = 0.0
	game.on_pet_energy_received(pet_id, 0.4)
	var clear_gain: float = float(game.pet_energy.get(pet_id, 0.0))
	assert(shielded_gain < clear_gain - 0.001, "Prism shield no longer halves incoming energy")
	target.remove_from_group("bosses")
	print("COMBO_SMOKE_OK evolutions=", game.evolutions.size(), " crit=", game.stats.crit, " orbit=", game.orbit_count)
	quit()
