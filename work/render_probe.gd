extends SceneTree
# 有窗口实时探针：真实驱动引擎（含 _draw / 渲染），采样帧耗时与渲染统计。
# 用法：godot --path . --script work/render_probe.gd -- <敌人数> <秒数>

var game
var save
var stress := 0
var run_seconds := 40.0
var elapsed := 0.0
var next_sample := 0.0
var booted := false
var rows: Array = []
var bot_phase := 0.0
var hide_world := false
var spikes: Array = []
var frame_ms: Array = []

func _initialize() -> void:
	call_deferred("boot")

func arg(index: int, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	return str(args[index]) if index < args.size() else fallback

func boot() -> void:
	stress = int(arg(0, "0"))
	run_seconds = float(arg(1, "40"))
	hide_world = arg(2, "") == "hide"
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(20260819)
	var packed := load("res://scenes/main.tscn") as PackedScene
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	save = root.get_node("SaveManager")
	save.data.intro_seen = true
	save.data.selected_character = "游侠"
	save.data.achievements = ["boss_breaker", "survive_three", "combo_adept", "streak_master", "molten_master"]
	game.show_main_menu()
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	if hide_world:
		game.visible = false
		if is_instance_valid(game.ui_layer):
			game.ui_layer.visible = false
	booted = true

func press_first_button(node: Node) -> bool:
	for child in node.get_children():
		if child is Button and not child.disabled:
			child.pressed.emit()
			return true
		if press_first_button(child):
			return true
	return false

func _process(delta: float) -> bool:
	if not booted:
		return false
	elapsed += delta
	if elapsed > 5.0:
		frame_ms.append(delta * 1000.0)
		if delta > 0.008:
			spikes.append("%.1fs %.1fms 敌%d" % [elapsed, delta * 1000.0, get_nodes_in_group("enemies").size()])
	if elapsed >= run_seconds:
		report()
		return true
	if not is_instance_valid(game) or game.state != game.GameState.PLAYING:
		for ov in [game.booster_overlay, game.card_replace_overlay, game.shop_overlay,
				game.boss_reward_overlay, game.mainline_complete_overlay]:
			if is_instance_valid(ov):
				press_first_button(ov)
				return false
		game.state = game.GameState.PLAYING
		return false
	# 保活 + 压场
	if is_instance_valid(game.player):
		game.player.health = game.player.max_health
	if stress > 0:
		var live := get_nodes_in_group("enemies").size()
		for i in mini(8, stress - live):
			game.spawn_enemy(game.chapter_enemy_kind(6, 0))
	# 简单走位：绕圈，保证怪群跟着、宠物有活干
	bot_phase += delta
	var dir := Vector2.RIGHT.rotated(bot_phase * 0.8)
	set_axis("move_right", "move_left", dir.x)
	set_axis("move_down", "move_up", dir.y)

	if elapsed >= next_sample:
		next_sample = elapsed + 1.0
		if elapsed > 5.0:
			rows.append({
				"fps": Performance.get_monitor(Performance.TIME_FPS),
				"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				"phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				"objs": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				"enemies": get_nodes_in_group("enemies").size(),
				"proj": game.projectile_root.get_child_count() if is_instance_valid(game.projectile_root) else 0,
				"vis": game.visual_root.get_child_count() if is_instance_valid(game.visual_root) else 0,
			})
	return false

func set_axis(positive: String, negative: String, value: float) -> void:
	if value >= 0.0:
		Input.action_release(negative)
		Input.action_press(positive, absf(value))
	else:
		Input.action_release(positive)
		Input.action_press(negative, absf(value))

func report() -> void:
	var f := FileAccess.open("res://work/render_out_%d%s.txt" % [stress, ("h" if hide_world else "")], FileAccess.WRITE)
	var n := maxf(1.0, float(rows.size()))
	var acc := {}
	for r in rows:
		for k in r.keys():
			acc[k] = float(acc.get(k, 0.0)) + float(r[k])
	var line := "stress=%d%s 样本=%d | FPS %.1f 帧 %.2fms | _process %.2fms 物理 %.2fms | 渲染剩余 %.2fms | 敌%.0f 弹%.0f 特效%.0f 节点%.0f | drawcall %.0f 图元 %.0f 可见对象 %.0f | 显存 %.1fMB" % [
		stress, (" HIDE" if hide_world else ""), rows.size(), acc.get("fps", 0) / n, 1000.0 / maxf(1.0, acc.get("fps", 0) / n),
		acc.get("proc", 0) / n, acc.get("phys", 0) / n,
		1000.0 / maxf(1.0, acc.get("fps", 0) / n) - acc.get("proc", 0) / n - acc.get("phys", 0) / n,
		acc.get("enemies", 0) / n, acc.get("proj", 0) / n, acc.get("vis", 0) / n, acc.get("nodes", 0) / n,
		acc.get("draws", 0) / n, acc.get("prims", 0) / n, acc.get("objs", 0) / n, acc.get("vram", 0) / n]
	frame_ms.sort()
	var m := frame_ms.size()
	if m > 0:
		var pct := "帧时间分布 中位 %.2fms  p95 %.2fms  p99 %.2fms  最差 %.2fms（%d 帧）" % [
			frame_ms[m / 2], frame_ms[mini(m - 1, int(m * 0.95))], frame_ms[mini(m - 1, int(m * 0.99))], frame_ms[m - 1], m]
		print(pct)
		print("超 8ms 的帧：%d 个  %s" % [spikes.size(), str(spikes.slice(0, 12))])
	print(line)
	if f:
		f.store_line(line)
		f.flush()
