extends SceneTree
# 局内心流（快层）的门禁。
#
# 快层是连续反馈回路，最容易在后续改动里悄悄失效或跑偏。这里守住的性质：
#   1) 开局 FLOW_WARMUP 秒内完全不介入（否则「开局可控」当场就没了）
#   2) Boss 战期间冻结（否则「掉血→变简单」成了可利用的漏洞）
#   3) 幅度封顶 ±FLOW_BAND，且降压快于加压
#   4) 无尽模式不参与
#   5) 只作用在节奏与数量上，不碰伤害/血量/掉落
#   6) 重开一局必须归零，均值要落进战绩

const DT := 1.0 / 40.0

var game
var save
var problems: Array[String] = []
# 主线 Boss 在 60/120/180/240 秒登场，而这里没人去打死它们。Boss 在场时
# 快层是冻结的，于是长时间推进会全程被冻住——第一版就栽在这里，
# 表现为「压力停在 1.075 再也不动」（正好是 45~60 秒那 15 秒的收紧量）。
# 所以驱动默认连 Boss 一起清掉，只有冻结那条用例显式保留。
var preserve_boss := false

func _initialize() -> void:
	call_deferred("run_test")

func flag(ok: bool, message: String) -> void:
	if not ok:
		problems.append(message)

# 手动推进游戏时钟。不能靠引擎自己跑——那样步长是墙钟，断言会飘。
#
# 两件必须由驱动方接管的事：
#   1) 38 秒会开商店，state 一变 _process 就早退、elapsed 停住，
#      快层的豁免期永远过不去；
#   2) 玩家站着不动时敌人会自然贴上来打他，「长期无威胁」这个场景根本立不住。
# 所以用 mode 把两个输入信号直接钉死：这里测的是控制器本身的行为，
# 「它确实被 _process 调用」由 Boss/无尽/归零那几条断言覆盖。
func advance(seconds: float, mode := "") -> void:
	var steps := int(seconds / DT)
	for index in steps:
		if game.state != game.GameState.PLAYING:
			if is_instance_valid(game.shop_overlay):
				game.close_shop()
			else:
				game.state = game.GameState.PLAYING
		if mode != "":
			for enemy in get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
					continue
				if preserve_boss and enemy.is_in_group("bosses"):
					continue
				enemy.queue_free()
		if mode == "calm":
			game.player.health = game.player.max_health
			game.last_hurt_elapsed = -99.0
		elif mode == "pressed":
			game.player.health = game.player.max_health * 0.15
			game.last_hurt_elapsed = game.elapsed
		game._process(DT)
		if index % 40 == 0:
			await process_frame

func setup_run() -> void:
	save.apply_test_fixture({"run_history": []})
	save.data.intro_seen = true
	save.data.selected_character = "游侠"
	game.start_game_after_prologue()

func run_test() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	save = root.get_node("SaveManager")
	game.set_process(false)

	await check_warmup()
	await check_direction()
	await check_band()
	await check_asymmetry()
	await check_boss_freeze()
	await check_endless()
	await check_isolation_of_knobs()
	await check_knob_isolation()
	await check_reset_and_record()

	if problems.is_empty():
		print("DDA_FAST_LAYER_SMOKE_OK")
	else:
		for line in problems:
			print("FAIL: %s" % line)
		print("DDA_FAST_LAYER_SMOKE_FAILED (%d)" % problems.size())
	quit(0 if problems.is_empty() else 1)

# ---------------------------------------------------------------- 1. 开局豁免

func check_warmup() -> void:
	setup_run()
	await process_frame
	# 开局满血、没挨过打，正是最容易被误读成「在摸鱼」而立刻加压的状态。
	await advance(game.FLOW_WARMUP - 5.0, "calm")
	flag(is_equal_approx(game.flow_pressure, 1.0), "开局豁免期内快层就动了：%.4f" % game.flow_pressure)
	await advance(40.0, "calm")
	flag(game.flow_pressure > 1.0, "过了豁免期，一直没挨打也没有收紧：%.4f" % game.flow_pressure)

# ---------------------------------------------------------------- 2. 方向

func check_direction() -> void:
	setup_run()
	await process_frame
	await advance(game.FLOW_WARMUP + 5.0, "calm")
	await advance(30.0, "pressed")
	var struggling: float = game.flow_pressure
	flag(struggling < 1.0, "濒死且刚挨打时没有减压：%.4f" % struggling)

	setup_run()
	await process_frame
	await advance(game.FLOW_WARMUP + 35.0, "calm")
	var coasting: float = game.flow_pressure
	flag(coasting > 1.0, "满血且长期无威胁时没有加压：%.4f" % coasting)
	flag(coasting > struggling, "两种局面的方向没有拉开：摸鱼%.4f 卡住%.4f" % [coasting, struggling])

# ---------------------------------------------------------------- 3. 封顶

func check_band() -> void:
	setup_run()
	await process_frame
	await advance(game.FLOW_WARMUP + 200.0, "calm")
	flag(game.flow_pressure <= 1.0 + game.FLOW_BAND + 0.0001, "加压越过了上限：%.4f" % game.flow_pressure)
	flag(game.flow_pressure > 1.0, "长期摸鱼后的收紧值不应低于 1：%.4f" % game.flow_pressure)
	await advance(200.0, "pressed")
	flag(game.flow_pressure >= 1.0 - game.FLOW_BAND - 0.0001, "降压越过了下限：%.4f" % game.flow_pressure)
	flag(game.flow_pressure < 1.0, "长期挨打后没有降到 1 以下：%.4f" % game.flow_pressure)

# ---------------------------------------------------------------- 4. 不对称

func check_asymmetry() -> void:
	setup_run()
	await process_frame
	await advance(game.FLOW_WARMUP + 5.0, "calm")
	var before_tighten: float = game.flow_pressure
	await advance(10.0, "calm")
	var tighten_step: float = game.flow_pressure - before_tighten
	var before_ease: float = game.flow_pressure
	await advance(10.0, "pressed")
	var ease_step: float = before_ease - game.flow_pressure
	flag(tighten_step > 0.0, "收紧方向没有产生位移")
	flag(ease_step > tighten_step, "松手不比收紧快，喘息感做不出来：收紧%.4f 松手%.4f" % [tighten_step, ease_step])

# ---------------------------------------------------------------- 5. Boss 战冻结

func check_boss_freeze() -> void:
	setup_run()
	await process_frame
	await advance(game.FLOW_WARMUP + 30.0, "calm")
	preserve_boss = true
	var boss = game.spawn_enemy("星渊追猎者", true)
	await process_frame
	var frozen: float = game.flow_pressure
	# Boss 在场时把玩家打到濒死：这正是「掉血换简单」漏洞的形状。
	await advance(40.0, "pressed")
	flag(is_equal_approx(game.flow_pressure, frozen), "Boss 战期间快层仍在动，掉血就能换简单：%.4f -> %.4f" % [frozen, game.flow_pressure])
	preserve_boss = false
	boss.queue_free()
	await process_frame
	await advance(30.0, "pressed")
	flag(game.flow_pressure < frozen, "Boss 离场后快层没有恢复响应：%.4f" % game.flow_pressure)

# ---------------------------------------------------------------- 6. 无尽不参与

func check_endless() -> void:
	setup_run()
	await process_frame
	game.start_endless_mode()
	await process_frame
	await advance(game.FLOW_WARMUP + 60.0, "calm")
	flag(is_equal_approx(game.flow_pressure, 1.0), "无尽模式里快层仍在介入，波数将不可比：%.4f" % game.flow_pressure)
	flag(is_equal_approx(game.effective_pressure(), 1.0), "无尽模式的合成压力不是 1.0：%.4f" % game.effective_pressure())

# ---------------------------------------------------------------- 7. 合成压力

func check_isolation_of_knobs() -> void:
	setup_run()
	await process_frame
	# 敌人强度正比于 elapsed，两次生成之间必须把时间钉死。
	game.elapsed = 90.0
	game.flow_pressure = 1.0
	var baseline = game.spawn_enemy("追猎者")
	await process_frame
	game.elapsed = 90.0
	game.flow_pressure = 1.0 - game.FLOW_BAND
	var eased = game.spawn_enemy("追猎者")
	await process_frame
	flag(is_equal_approx(eased.damage, baseline.damage), "快层改到了敌人伤害上")
	flag(eased.xp_value == baseline.xp_value, "快层改到了掉落价值上")
	flag(eased.max_health < baseline.max_health, "快层减压没有降低敌人血量")
	game.run_pressure_scale = 1.1
	game.flow_pressure = 0.9
	flag(is_equal_approx(game.effective_pressure(), 0.99), "合成压力不是两层相乘：%.4f" % game.effective_pressure())

# ---------------------------------------------------------------- 8. 落点约束

# 压力系数的落点试错过两轮，这一节把结论钉死：
#   按数量调 —— 减压 15% 让收入掉 18%、Boss 少清 0.6 个（敌人同时是资源供给）
#   按接近速度调 —— 断链 21%、收入掉 30%（「简单」变成了「无聊」）
# 现在只作用于**非 Boss 敌人的血量**：接触照旧发生，只是解决得快一点或慢一点。
# 伤害、掉落、刷怪速率、出生距离一律不动。
func check_knob_isolation() -> void:
	setup_run()
	await process_frame
	var readings: Dictionary = {}
	for pressure in [0.85, 1.0, 1.15]:
		game.run_pressure_scale = float(pressure)
		game.flow_pressure = 1.0
		# 掉落率随章节（elapsed）变化，对照前必须先钉死时间。
		game.elapsed = 90.0
		seed(4242)
		var reward := 0
		for index in 400:
			reward += game.roll_enemy_shard_reward(false, "追猎者")
		seed(4242)
		game.elapsed = 90.0
		var probe = game.spawn_enemy("追猎者")
		readings[pressure] = {"reward": reward, "health": probe.max_health,
			"damage": probe.damage, "speed": probe.speed,
			"distance": probe.global_position.distance_to(game.player.global_position)}
		probe.queue_free()
		await process_frame
	var base: Dictionary = readings[1.0]
	for pressure in [0.85, 1.15]:
		var row: Dictionary = readings[pressure]
		flag(int(row.reward) == int(base.reward), "压力 %.2f 改变了掉落收入：%d vs %d" % [pressure, int(row.reward), int(base.reward)])
		flag(is_equal_approx(float(row.damage), float(base.damage)), "压力 %.2f 改到了敌人伤害上——这是致死变量，不许动" % pressure)
		flag(is_equal_approx(float(row.speed), float(base.speed)), "压力 %.2f 改到了接近速度上——会制造没仗可打的真空" % pressure)
		flag(is_equal_approx(float(row.distance), float(base.distance)), "压力 %.2f 改到了出生距离上" % pressure)
	# 血量：高压更耐打，低压更脆
	flag(float(readings[1.15].health) > float(base.health), "加压没有提高敌人血量")
	flag(float(readings[0.85].health) < float(base.health), "减压没有降低敌人血量")
	flag(absf(float(readings[0.85].health) - float(base.health) * 0.85) < 0.01, "血量不是按系数线性缩放")
	# Boss 不参与：它是设计好的 set piece
	game.run_pressure_scale = 1.0
	game.elapsed = 90.0
	var boss_base = game.spawn_enemy("星渊追猎者", true)
	var boss_health: float = boss_base.max_health
	boss_base.queue_free()
	await process_frame
	game.run_pressure_scale = 1.15
	game.elapsed = 90.0
	var boss_pressured = game.spawn_enemy("星渊追猎者", true)
	flag(is_equal_approx(boss_pressured.max_health, boss_health), "Boss 血量被压力系数改动了：%.2f vs %.2f" % [boss_health, boss_pressured.max_health])
	boss_pressured.queue_free()
	await process_frame

# ---------------------------------------------------------------- 9. 归零与记录

func check_reset_and_record() -> void:
	setup_run()
	await process_frame
	await advance(game.FLOW_WARMUP + 80.0, "calm")
	flag(not is_equal_approx(game.flow_pressure, 1.0), "这一段本应产生介入，否则下面的断言没有意义")
	var average: float = game.flow_pressure_average()
	flag(average > 1.0 and average < game.flow_pressure + 0.0001, "时间加权均值不在合理区间：均值%.4f 当前%.4f" % [average, game.flow_pressure])
	game.end_run(false)
	await process_frame
	var recorded: Array = save.recent_runs("游侠", "mainline")
	flag(not recorded.is_empty(), "结算没有写进战绩")
	if not recorded.is_empty():
		flag(is_equal_approx(float(recorded[-1].get("flow", 0.0)), snappedf(average, 0.01)), "快层均值没有落进战绩：%s" % str(recorded[-1].get("flow", null)))
	setup_run()
	await process_frame
	flag(is_equal_approx(game.flow_pressure, 1.0), "重开一局后快层没有归零：%.4f" % game.flow_pressure)
	flag(is_equal_approx(game.flow_pressure_average(), 1.0), "重开一局后均值没有归零")
	game.show_main_menu()
	await process_frame
