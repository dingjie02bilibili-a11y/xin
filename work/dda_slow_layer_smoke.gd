extends SceneTree
# 跨局难度心流（慢层）的门禁。
#
# 守住 difficulty_director.gd 里那四条硬性约束，它们都是「改起来很顺手、
# 改完游戏就变坏」的那类规则：
#   1) 证据不足不介入
#   2) 幅度封顶 ±BAND
#   3) 降压快、加压慢（不对称）
#   4) 只调压力，不调伤害与奖励
# 外加一条：无尽模式一律不参与。

const Director = preload("res://scripts/difficulty_director.gd")

var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("run_test")

func flag(ok: bool, message: String) -> void:
	if not ok:
		problems.append(message)

func make_runs(count: int, boss_kills: int, seconds: float, scale := 1.0) -> Array:
	var runs: Array = []
	for index in count:
		runs.append({"boss_kills": boss_kills, "seconds": seconds, "scale": scale})
	return runs

func run_test() -> void:
	check_insufficient_evidence()
	check_band()
	check_direction()
	check_asymmetry()
	check_dirty_input()
	check_describe()
	await check_wiring()

	if problems.is_empty():
		print("DDA_SLOW_LAYER_SMOKE_OK")
	else:
		for line in problems:
			print("FAIL: %s" % line)
		print("DDA_SLOW_LAYER_SMOKE_FAILED (%d)" % problems.size())
	quit(0 if problems.is_empty() else 1)

# ---------------------------------------------------------------- 1. 证据不足

func check_insufficient_evidence() -> void:
	flag(Director.pressure_scale([]) == 1.0, "空历史时也应该完全不介入")
	for count in range(1, Director.MIN_RUNS):
		var runs := make_runs(count, 6, 400.0)
		flag(Director.pressure_scale(runs) == 1.0, "只有 %d 局就开始调压力了，新玩家会被误判" % count)
		flag(Director.skill_estimate(runs) < 0.0, "只有 %d 局时熟练度不应该有值" % count)
	# 刚好够 MIN_RUNS 才允许介入
	flag(Director.pressure_scale(make_runs(Director.MIN_RUNS, 6, 400.0)) > 1.0, "样本够了却仍然不介入")

# ---------------------------------------------------------------- 2. 幅度封顶

func check_band() -> void:
	# 连续通关很多局，也不能超过带宽上限
	var ceiling := 1.0
	var runs := make_runs(Director.WINDOW * 3, 6, 400.0)
	for step in 40:
		ceiling = Director.pressure_scale(runs, ceiling)
	flag(is_equal_approx(ceiling, 1.0 + Director.BAND), "反复迭代后没有收敛到带宽上限，实得 %.3f" % ceiling)
	var floor_value := 1.0
	# 得分必须恰好为 0 才会顶到下限：seconds 留一点，目标就落在带内而不是带边。
	var weak_runs := make_runs(Director.WINDOW * 3, 0, 0.0)
	for step in 40:
		floor_value = Director.pressure_scale(weak_runs, floor_value)
	flag(is_equal_approx(floor_value, 1.0 - Director.BAND), "反复迭代后没有收敛到带宽下限，实得 %.3f" % floor_value)
	# 传进来一个越界的历史值也必须被夹住
	flag(Director.pressure_scale(runs, 9.0) <= 1.0 + Director.BAND, "上一局系数越界时没有夹回带内")
	flag(Director.pressure_scale(weak_runs, -3.0) >= 1.0 - Director.BAND, "上一局系数为负时没有兜底")

# ---------------------------------------------------------------- 3. 方向

func check_direction() -> void:
	var strong := Director.skill_estimate(make_runs(Director.WINDOW, 6, 400.0))
	var middle := Director.skill_estimate(make_runs(Director.WINDOW, 3, 200.0))
	var weak := Director.skill_estimate(make_runs(Director.WINDOW, 0, 60.0))
	flag(strong > middle and middle > weak, "熟练度没有随战绩单调，强%.3f 中%.3f 弱%.3f" % [strong, middle, weak])
	flag(Director.pressure_scale(make_runs(Director.WINDOW, 6, 400.0)) > 1.0, "常规通关的玩家没有被加压")
	flag(Director.pressure_scale(make_runs(Director.WINDOW, 0, 60.0)) < 1.0, "反复打崩的玩家没有被减压")
	# 同样的 boss_kills，撑得久的应该被判定更强
	var long_run := Director.run_score({"boss_kills": 3, "seconds": 300.0})
	var short_run := Director.run_score({"boss_kills": 3, "seconds": 130.0})
	flag(long_run > short_run, "关卡数相同时，存活时长没有参与判定")
	# 最近的局权重更高：同样八局，最后几局崩了应该压过前面的好成绩
	var improving := make_runs(Director.WINDOW - 2, 0, 60.0) + make_runs(2, 6, 400.0)
	var declining := make_runs(Director.WINDOW - 2, 6, 400.0) + make_runs(2, 0, 60.0)
	var improving_skill := Director.skill_estimate(improving)
	var declining_skill := Director.skill_estimate(declining)
	flag(improving_skill > declining_skill, "近期战绩没有获得更高权重：先弱后强%.4f 先强后弱%.4f" % [improving_skill, declining_skill])

# ---------------------------------------------------------------- 4. 不对称

func check_asymmetry() -> void:
	var strong_runs := make_runs(Director.WINDOW, 6, 400.0)
	var weak_runs := make_runs(Director.WINDOW, 0, 20.0)
	var up: float = Director.pressure_scale(strong_runs, 1.0) - 1.0
	var down: float = 1.0 - Director.pressure_scale(weak_runs, 1.0)
	flag(down > up, "降压不比加压快，橡皮筋感挡不住（加 %.3f / 减 %.3f）" % [up, down])
	flag(is_equal_approx(up, Director.MAX_STEP_UP), "单局加压幅度不等于 MAX_STEP_UP，实得 %.3f" % up)
	flag(is_equal_approx(down, Director.MAX_STEP_DOWN), "单局降压幅度不等于 MAX_STEP_DOWN，实得 %.3f" % down)
	# 打崩之后必须立刻松手，不能还停在高压
	var after_collapse: float = Director.pressure_scale(weak_runs, 1.0 + Director.BAND)
	flag(after_collapse < 1.0 + Director.BAND, "连续打崩后压力没有下降")

# ---------------------------------------------------------------- 5. 脏输入

func check_dirty_input() -> void:
	var dirty: Array = ["不是字典", null, {"boss_kills": "六", "seconds": {}}, {}]
	var scale: float = Director.pressure_scale(dirty)
	flag(scale >= 1.0 - Director.BAND and scale <= 1.0 + Director.BAND, "脏历史把系数带出了带宽：%.3f" % scale)
	flag(Director.last_applied_scale([]) == 1.0, "空历史的上一局系数应为 1.0")
	flag(Director.last_applied_scale([{"seconds": 1.0}]) == 1.0, "旧存档没有 scale 字段时应回落到 1.0")
	flag(is_equal_approx(Director.last_applied_scale([{"scale": 1.07}, {"seconds": 1.0}]), 1.07), "没有取到最近一条带 scale 的记录")

# ---------------------------------------------------------------- 6. 说明文案

func check_describe() -> void:
	flag(Director.describe(1.0) == "", "系数为 1 时不应该显示任何说明")
	flag(Director.describe(1.08).contains("+8"), "加压说明没有写出幅度")
	flag(Director.describe(0.9).contains("-10"), "降压说明没有写出幅度")

# ---------------------------------------------------------------- 7. 接线

func check_wiring() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	var save = root.get_node("SaveManager")
	save.apply_test_fixture({"run_history": []})
	save.data.intro_seen = true
	save.data.selected_character = "游侠"

	# 空历史：开局必须是标准难度
	game.start_game_after_prologue()
	await process_frame
	flag(is_equal_approx(game.run_pressure_scale, 1.0), "空存档开局不是标准难度：%.3f" % game.run_pressure_scale)

	# 塞进一串通关战绩，重开一局应当加压
	var strong: Array = []
	for index in Director.WINDOW:
		strong.append({"character": "游侠", "mode": "mainline", "boss_kills": 6, "seconds": 400.0, "victory": true})
	save.apply_test_fixture({"run_history": strong})
	save.data.intro_seen = true
	save.data.selected_character = "游侠"
	game.start_game_after_prologue()
	await process_frame
	var scaled: float = game.run_pressure_scale
	flag(scaled > 1.0, "有通关战绩后开局没有加压：%.3f" % scaled)

	# 压力只能作用在节奏和数量上：伤害与掉落必须原样
	# 敌人强度本来就正比于 elapsed（0.92 + elapsed/520），两次生成之间时间会走，
	# 所以必须把时间钉死，否则测的是时间曲线而不是压力系数。
	game.elapsed = 30.0
	var baseline_enemy = game.spawn_enemy("追猎者")
	await process_frame
	var damage_before: float = baseline_enemy.damage
	var health_before: float = baseline_enemy.max_health
	game.run_pressure_scale = 1.0 + Director.BAND
	game.elapsed = 30.0
	var pressured_enemy = game.spawn_enemy("追猎者")
	await process_frame
	flag(is_equal_approx(pressured_enemy.damage, damage_before), "压力系数改到了敌人伤害上")
	flag(is_equal_approx(pressured_enemy.max_health, health_before), "压力系数改到了敌人血量上")
	game.run_pressure_scale = scaled

	# 别的角色不该共享这份战绩。注意换角色前必须先解锁：没解锁的话
	# ensure_selected_character_unlocked 会把它退回游侠，测出来的还是游侠。
	save.data.achievements = ["boss_breaker", "survive_three", "combo_adept", "streak_master", "molten_master"]
	save.data.selected_character = "骑士"
	game.start_game_after_prologue()
	await process_frame
	flag(is_equal_approx(game.run_pressure_scale, 1.0), "另一个角色继承了游侠的战绩：%.3f" % game.run_pressure_scale)

	# 无尽模式一律不参与
	save.data.selected_character = "游侠"
	game.start_game_after_prologue()
	await process_frame
	game.start_endless_mode()
	await process_frame
	flag(is_equal_approx(game.run_pressure_scale, 1.0), "无尽模式仍在调难度，波数将不可比：%.3f" % game.run_pressure_scale)

	# 系数必须落进战绩，否则无法回溯，也做不了单局变化限制
	save.apply_test_fixture({"run_history": strong})
	save.data.intro_seen = true
	save.data.selected_character = "游侠"
	game.start_game_after_prologue()
	await process_frame
	var applied: float = game.run_pressure_scale
	game.end_run(false)
	await process_frame
	var recorded: Array = save.recent_runs("游侠", "mainline")
	flag(not recorded.is_empty() and is_equal_approx(float(recorded[-1].get("scale", 0.0)), snappedf(applied, 0.01)), "本局压力系数没有写进战绩")
	game.show_main_menu()
	await process_frame
