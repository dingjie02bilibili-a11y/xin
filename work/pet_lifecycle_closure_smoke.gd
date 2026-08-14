extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	assert(game.equipped_pet_count() == 1, "Closure test needs one starting pet")
	var last_pet: String = game.active_core_skill_ids()[0]
	game.gain_star_shards(20)
	game.show_shop(true)
	await process_frame
	game.sell_shop_card(last_pet)
	assert(not game.equipped_cards.has(last_pet), "Shop still blocks selling the final pet")
	assert(game.directed_shop_pending, "Selling the final offense pet did not queue a recovery offer")
	game.close_shop()
	assert(game.state == game.GameState.PLAYING, "Lone Star deck could not leave the shop")
	assert(game.lone_star_protocol_active(), "Lone Star protocol did not close the empty-offense combat loop")
	print("PET_LIFECYCLE_CLOSURE_OK lone_star=", game.lone_star_protocol_active())
	quit()
