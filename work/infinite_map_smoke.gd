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
	game.player.position = Vector2(12000, -9000)
	game.spawn_enemy("追踪怪")
	var enemy = get_nodes_in_group("enemies")[-1]
	# 刷新距离已随攻击范围一起收进可视范围（430~560）；本用例要验证的是
	# 「围绕玩家刷新、不被世界边界钳制」，而不是某个具体距离。
	var spawn_gap: float = enemy.global_position.distance_to(game.player.global_position)
	assert(spawn_gap > 400.0 and spawn_gap < 600.0, "Enemy was not spawned around the player")
	assert(enemy.global_position.x > 10000.0 and enemy.global_position.y < -8000.0, "Enemy spawn was still clamped to arena bounds")
	assert(game.camera.limit_left < -1000000 and game.camera.limit_right > 1000000, "Camera still has world bounds")
	print("INFINITE_MAP_SMOKE_OK player=", game.player.position, " enemy=", enemy.position)
	quit()
