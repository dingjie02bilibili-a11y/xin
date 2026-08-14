extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	var before: float = game.player.health
	game.player.take_damage(12.0)
	assert(game.player.health < before and game.player.damage_flash > 0.0, "Player hit feedback did not trigger")
	assert(game.hp_bar != null and game.hp_lag_bar != null, "Animated health bars were not built")
	game.show_shop(true)
	assert(game.shop_overlay != null and game.shop_goods_row.get_child_count() == 3, "Shop overlay did not build")
	print("FEEDBACK_SMOKE_OK hp=", game.player.health, " goods=", game.shop_goods_row.get_child_count())
	quit()
