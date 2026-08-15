extends SceneTree
# 守住「重开一局会把上一局的整个世界泄漏进新一局」这个 P0 缺陷。
#
# 根因：clear_game() 曾经按节点名匹配来释放战场，而 queue_free 要到帧末才生效。
# 「再次远征」会在同一帧里清场并重建根节点，此时旧的同名兄弟还在树上，Godot 会
# 直接丢弃新节点的名字换成内部名（@Node2D@N），之后任何按名字的清场都再也匹配不到。
# 后果：上一局的敌人占满 enemy_cap 导致新一局不刷怪，残留 Boss 永久阻塞商店。

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	var save = root.get_node_or_null("SaveManager")
	assert(save != null, "SaveManager autoload missing")
	save.data.intro_seen = true

	# 第 1 局：正常开局并留下一批敌人
	game.start_game_after_prologue()
	await process_frame
	for i in 20:
		game.spawn_wavelet()
	await process_frame
	assert(get_nodes_in_group("enemies").size() > 0, "First run did not spawn any enemies")

	# 第 2 局：模拟结算界面的「再次远征」——同一帧内清场并重建
	game.end_run(false)
	game.start_game_after_prologue()
	await process_frame
	await process_frame
	assert(get_nodes_in_group("enemies").is_empty(), "Restart leaked the previous run's enemies")
	for node_name in ["Entities", "Projectiles", "Pickups", "Visuals", "Hazards"]:
		assert(game.get_node_or_null(node_name) != null, "World root %s lost its name on same-frame restart" % node_name)

	# 第 2 局死在 Boss 战里，第 3 局不能继承这只 Boss
	game.elapsed = 60.0
	game.check_boss_timing()
	await process_frame
	assert(get_nodes_in_group("bosses").size() == 1, "Boss did not spawn for the leak scenario")
	game.end_run(false)
	game.start_game_after_prologue()
	await process_frame
	await process_frame
	assert(get_nodes_in_group("bosses").is_empty(), "Restart leaked the previous run's Boss")
	assert(get_nodes_in_group("enemies").is_empty(), "Restart leaked the previous run's enemies")

	# 残留 Boss 会让 `shop_pending and bosses.is_empty()` 永远不成立，商店再也开不出来
	game.shop_pending = true
	game.elapsed = 40.0
	for i in 30:
		game._process(1.0 / 60.0)
	await process_frame
	assert(game.shop_overlay != null, "Shop stayed blocked after restart")
	game.close_shop()
	await process_frame

	# 返回主菜单同样必须清干净
	game.start_game_after_prologue()
	await process_frame
	for i in 20:
		game.spawn_wavelet()
	await process_frame
	game.show_main_menu()
	await process_frame
	await process_frame
	assert(get_nodes_in_group("enemies").is_empty(), "Returning to the menu left the world behind")

	print("RESTART_LEAK_SMOKE_OK")
	quit()
