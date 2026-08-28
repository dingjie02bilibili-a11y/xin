extends SceneTree
# 无尽模式验证：Boss 战期间的刷怪压制这条改动同样作用于无尽，
# 而无尽每 3 波就出一次 Boss，必须确认后半段不会长期停摆。

const DT := 1.0 / 40.0

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var sim_script = load("res://work/balance_sim.gd")
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	var save = root.get_node("SaveManager")
	save.data.intro_seen = true
	save.data.selected_character = "游侠"
	game.start_game_after_prologue()
	await process_frame
	game.set_process(false)
	paused = true
	game.start_endless_mode()
	game.player.max_health = 4000.0
	game.player.health = 4000.0

	var problems_extra: Array[String] = []
	var elapsed := 0.0
	var wave_seen := {}
	var boss_waves := 0
	var shops := 0
	var alive_sum := 0.0
	var samples := 0
	var stalled := 0
	var boss_spawned_manually := 0
	var boss_alive_sum := 0.0
	var boss_samples := 0
	while elapsed < 320.0:
		await process_frame
		if game.state == game.GameState.GAME_OVER:
			break
		if game.state == game.GameState.LEVEL_UP:
			if game.shop_overlay != null:
				shops += 1
				game.close_shop()
			elif game.boss_reward_overlay != null:
				game.finish_boss_reward_selection()
			else:
				game.state = game.GameState.PLAYING
			paused = true
			await process_frame
			continue
		game.player.health = game.player.max_health
		game._process(DT)
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e._physics_process(DT)
		for holder in [game.projectile_root, game.visual_root, game.hazard_root, game.pickup_root]:
			for node in holder.get_children():
				if is_instance_valid(node):
					if node.has_method("_physics_process"): node._physics_process(DT)
					elif node.has_method("_process"): node._process(DT)
		elapsed += DT
		# spawn_endless_boss 内部 await 的计时器在暂停树里不会走，
		# 直接手动放一只无尽 Boss，才能真正验证「Boss 在场时的刷怪压制」。
		if elapsed > 90.0 and boss_spawned_manually == 0:
			boss_spawned_manually = 1
			var boss = game.spawn_enemy("弥垣·关门人", true)
			boss.set_chapter_tier(7)
			boss.health = 26000.0
			boss.max_health = 26000.0
		wave_seen[game.endless_wave] = true
		var alive := get_nodes_in_group("enemies").size()
		alive_sum += alive
		samples += 1
		if alive == 0:
			stalled += 1
		if not get_nodes_in_group("bosses").is_empty():
			boss_waves += 1
			boss_alive_sum += alive
			boss_samples += 1

	var avg_alive := alive_sum / maxf(1.0, float(samples))
	var stall_pct := float(stalled) / maxf(1.0, float(samples)) * 100.0
	print("ENDLESS Boss在场时场均敌人 %.1f（样本 %d）" % [boss_alive_sum / maxf(1.0, float(boss_samples)), boss_samples])
	if boss_samples > 200 and boss_alive_sum / float(boss_samples) < 12.0:
		problems_extra.append("Boss 在场时无尽被压制到场均 %.1f" % (boss_alive_sum / float(boss_samples)))
	print("ENDLESS 波次抵达 %d | 平均场上敌人 %.1f | Boss 在场时长占比 %.0f%% | 商店 %d 次 | 空场占比 %.1f%%" % [
		game.endless_wave, avg_alive, float(boss_waves) / maxf(1.0, float(samples)) * 100.0, shops, stall_pct])
	var problems: Array[String] = problems_extra
	if game.endless_wave < 6: problems.append("波次没有正常推进")
	if avg_alive < 8.0: problems.append("平均场上敌人只有 %.1f，无尽被压制停摆" % avg_alive)
	if shops < 3: problems.append("无尽商店只开了 %d 次（累计待开 %d）" % [shops, game.queued_shops])
	if stall_pct > 12.0: problems.append("空场时间占 %.0f%%" % stall_pct)
	for x in problems:
		print("ENDLESS_PROBLEM " + x)
	assert(problems.is_empty(), "无尽模式异常：" + ", ".join(problems))
	print("ENDLESS_SMOKE_OK")
	quit()
