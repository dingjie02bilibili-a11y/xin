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
	for step in 180:
		pet._process(1.0 / 60.0)
	var settled: Vector2 = pet.global_position
	game.player.global_position += Vector2(260, 0)
	pet._process(1.0 / 60.0)
	var first_frame_distance: float = pet.global_position.distance_to(settled)
	assert(first_frame_distance < 20.0, "Pet still moves synchronously with the player")
	assert(pet.global_position.distance_to(game.player.global_position) > 100.0, "Pet has no visible trailing movement")
	for step in 300:
		pet._process(1.0 / 60.0)
	var follow_distance: float = pet.global_position.distance_to(game.player.global_position)
	var catchup_error: float = absf(follow_distance - pet.pet_leash_distance())
	assert(catchup_error < 35.0, "Pet did not return to its leash distance")
	assert(pet.global_position.x < game.player.global_position.x - 20.0, "Pet returned to a fixed point above the player instead of keeping its trailing side")
	pet.skill_id = "aura"
	pet.global_position = Vector2.ZERO
	pet.follow_velocity = Vector2.ZERO
	pet.move_as_follower(Vector2(100, 0), 1.0 / 60.0)
	var near_speed: float = pet.follow_velocity.length()
	pet.global_position = Vector2.ZERO
	pet.follow_velocity = Vector2.ZERO
	pet.move_as_follower(Vector2(600, 0), 1.0 / 60.0)
	var far_speed: float = pet.follow_velocity.length()
	assert(far_speed > near_speed * 3.0, "Far-away pet does not accelerate its catch-up")
	pet.global_position = Vector2.ZERO
	pet.follow_velocity = Vector2(200, 0)
	pet.skill_id = "gravity_well"
	pet.move_as_follower(Vector2.ZERO, 1.0 / 60.0)
	var heavy_retained_speed: float = pet.follow_velocity.length()
	pet.global_position = Vector2.ZERO
	pet.follow_velocity = Vector2(200, 0)
	pet.skill_id = "phase_step"
	pet.move_as_follower(Vector2.ZERO, 1.0 / 60.0)
	var light_retained_speed: float = pet.follow_velocity.length()
	assert(heavy_retained_speed > light_retained_speed, "Heavy and light pets have the same inertia")
	assert(float(pet.pet_motion_profile().speed) > 500.0, "Fast pet does not have its own movement speed")
	print("PET_FOLLOW_MOTION_SMOKE_OK first_frame=", first_frame_distance, " catchup_error=", catchup_error, " near=", near_speed, " far=", far_speed, " inertia=", heavy_retained_speed, "/", light_retained_speed)
	quit()
