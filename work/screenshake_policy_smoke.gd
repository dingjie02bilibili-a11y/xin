extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func wait_short() -> void:
	await create_timer(0.055).timeout

func settle_camera(game) -> void:
	await create_timer(0.45).timeout
	game.camera.offset = Vector2.ZERO

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.on_player_hurt(5.0)
	await wait_short()
	assert(game.camera.offset.length() < 0.01, "Light player damage still shakes the camera")
	game.on_player_hurt(20.0)
	await wait_short()
	assert(game.camera.offset.length() > 0.01, "Heavy player damage does not shake the camera")
	await settle_camera(game)
	game.displayed_health = 20.0
	game.on_health_changed(21.0, 100.0)
	await wait_short()
	assert(game.camera.offset.length() < 0.01, "Low-health healing still shakes the camera")
	await settle_camera(game)
	game.nova_level = 1
	game.fire_nova()
	await wait_short()
	assert(game.camera.offset.length() < 0.01, "Automatic nova still shakes the camera")
	game.spawn_enemy("追踪怪")
	game.meteor_level = 1
	game.fire_meteor_rain()
	await wait_short()
	assert(game.camera.offset.length() < 0.01, "Automatic meteor still shakes the camera")
	var normal = game.spawn_enemy("追踪怪")
	game.on_enemy_defeated(normal, 4)
	await wait_short()
	assert(game.camera.offset.length() < 0.01, "Normal enemy defeat still shakes the camera")
	var elite = game.spawn_enemy("铁甲怪")
	game.on_enemy_defeated(elite, 9)
	await wait_short()
	assert(game.camera.offset.length() < 0.01, "Elite enemy defeat still shakes the camera")
	await settle_camera(game)
	game.on_boss_dramatic_attack(8.0)
	await wait_short()
	assert(game.camera.offset.length() > 0.01, "Boss burst has no dramatic shake")
	print("SCREENSHAKE_POLICY_SMOKE_OK")
	quit()
