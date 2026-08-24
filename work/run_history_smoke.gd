extends SceneTree
# 战绩流水（难度心流第 1 步）的门禁。
#
# 守住三件事：
#   1. 无窗口脚本与玩家存档完全隔离——既不读也不写。这条一旦破了，
#      后续所有仿真跑分都会随本机战绩漂移，A/B 对照失去意义。
#   2. 落盘 schema 收口：脏数据进不来，字段与类型恒定。
#   3. 局内采集真的按章节切片，且结算时确实写进历史。

const DT := 1.0 / 40.0
const HistoryFixtures = preload("res://work/history_fixtures.gd")

var game
var save
var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("run_test")

func flag(ok: bool, message: String) -> void:
	if not ok:
		problems.append(message)

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	save = root.get_node("SaveManager")

	check_isolation()
	check_schema()
	check_ring_buffer()
	check_fixtures()
	await check_live_capture()

	if problems.is_empty():
		print("RUN_HISTORY_SMOKE_OK")
	else:
		for line in problems:
			print("FAIL: %s" % line)
		print("RUN_HISTORY_SMOKE_FAILED (%d)" % problems.size())
	quit(0 if problems.is_empty() else 1)

# ---------------------------------------------------------------- 1. 存档隔离

func check_isolation() -> void:
	flag(save.isolated, "无窗口脚本没有进入隔离模式，仿真会读到玩家真实存档")
	flag(save.data.run_history.is_empty(), "隔离模式下仍读进了本机战绩，跑分将不可复现")
	# 写一条再存盘，玩家的存档文件不能因此产生或变化。
	var before := FileAccess.get_file_as_string(save.SAVE_PATH) if FileAccess.file_exists(save.SAVE_PATH) else ""
	save.finish_run({"character": "游侠", "seconds": 12.0})
	var after := FileAccess.get_file_as_string(save.SAVE_PATH) if FileAccess.file_exists(save.SAVE_PATH) else ""
	flag(before == after, "冒烟脚本写动了玩家的 starfall_save.json")
	save.data.run_history.clear()

# ---------------------------------------------------------------- 2. schema 收口

func check_schema() -> void:
	save.data.run_history.clear()
	# 半成品 + 脏类型 + 越界值 + 不该存在的字段，一次性喂进去。
	save.finish_run({
		"character": "骑士",
		"mode": "作弊模式",
		"seconds": "不是数字",
		"chapter": 99,
		"wave": -4,
		"kills": 12.7,
		"damage": null,
		"ttk": "不是数组",
		"rows": [{"ch": 1, "hp": 88.0}, "不是字典"],
		"永久属性加成": 999
	})
	var entry: Dictionary = save.data.run_history[0]
	flag(not entry.has("永久属性加成"), "白名单没生效，未知字段被写进了存档")
	flag(entry.v == save.HISTORY_VERSION, "缺少 schema 版本号，将来无法迁移")
	flag(entry.mode == "mainline", "非法 mode 没有被收敛回 mainline")
	flag(entry.seconds == 0.0, "字符串型 seconds 没被归一为 0")
	flag(entry.chapter == 6, "chapter 没被夹在 0~6")
	flag(entry.wave == 1, "wave 没有下限保护")
	flag(entry.kills == 12, "kills 没有归一为整数")
	flag(entry.damage == 0.0, "null 型 damage 没被归一")
	flag(entry.ttk is Array and entry.ttk.is_empty(), "非数组 ttk 没被收敛为空数组")
	flag(entry.rows.size() == 1, "rows 里的非字典元素没被丢弃")
	var row: Dictionary = entry.rows[0]
	for key in ["ch", "secs", "kills", "dmg", "hp", "alive", "severed", "hands"]:
		flag(row.has(key), "章节切片缺字段 %s" % key)
	flag(row.secs == 0.0, "章节切片的缺省字段没有补 0")
	# 存档必须能被 JSON 原样往返，否则下次开机读回来会变形。
	var round_trip = JSON.parse_string(JSON.stringify(save.data.run_history))
	flag(round_trip is Array and JSON.stringify(round_trip) == JSON.stringify(save.data.run_history), "战绩流水无法 JSON 往返")
	save.data.run_history.clear()

# ---------------------------------------------------------------- 3. 环形缓冲

func check_ring_buffer() -> void:
	save.data.run_history.clear()
	var overflow := int(save.HISTORY_LIMIT) + 5
	for index in overflow:
		save.finish_run({"character": "游侠", "seconds": float(index), "kills": index})
	flag(save.data.run_history.size() == save.HISTORY_LIMIT, "环形缓冲没有封顶，存档会无限增长")
	flag(float(save.data.run_history[-1].seconds) == float(overflow - 1), "环形缓冲丢的是新条目而不是旧条目")
	flag(float(save.data.run_history[0].seconds) == float(overflow - save.HISTORY_LIMIT), "环形缓冲的截断起点不对")
	# 按角色查询：角色之间强度差距大，跨角色平均没有意义。
	save.finish_run({"character": "影舞者", "seconds": 500.0})
	flag(save.recent_runs("影舞者").size() == 1, "recent_runs 的角色筛选没生效")
	flag(save.recent_runs("游侠", "", 3).size() == 3, "recent_runs 的条数限制没生效")
	flag(save.recent_runs("", "endless").is_empty(), "recent_runs 的模式筛选没生效")
	save.data.run_history.clear()

# ---------------------------------------------------------------- 4. 夹具确定性

func check_fixtures() -> void:
	var first := HistoryFixtures.profile("median", "游侠")
	var second := HistoryFixtures.profile("median", "游侠")
	flag(JSON.stringify(first) == JSON.stringify(second), "同一档夹具两次生成结果不一致，仿真不可复现")
	flag(JSON.stringify(HistoryFixtures.profile("weak")) != JSON.stringify(first), "弱档与中档夹具没有区分度")
	flag(HistoryFixtures.profile("empty").run_history.is_empty(), "empty 档不是空历史")

	save.apply_test_fixture(HistoryFixtures.profile("strong", "骑士"))
	flag(save.data.run_history.size() == 8, "夹具注入后的局数不对")
	flag(save.recent_runs("骑士").size() == 8, "夹具没有落在指定角色上")
	flag(save.data.selected_character == "游侠", "夹具注入没有把其余存档字段复位")
	flag(save.data.achievements.is_empty(), "夹具注入没有清掉成就，跑分仍会受本机进度影响")

	# 夹具与真实结算必须走同一条 normalise 通道，字段集不能分叉。
	var fixture_entry: Dictionary = save.data.run_history[0]
	save.data.run_history.clear()
	save.finish_run(game.build_run_summary(false))
	var recorded_entry: Dictionary = save.data.run_history[0]
	var fixture_keys := fixture_entry.keys()
	var recorded_keys := recorded_entry.keys()
	fixture_keys.sort()
	recorded_keys.sort()
	flag(fixture_keys == recorded_keys, "夹具与真实结算的字段集不一致：%s vs %s" % [str(fixture_keys), str(recorded_keys)])
	save.data.run_history.clear()

# ---------------------------------------------------------------- 5. 局内采集

func check_live_capture() -> void:
	save.apply_test_fixture(HistoryFixtures.profile("empty"))
	save.data.intro_seen = true
	save.data.selected_character = "游侠"
	game.show_main_menu()
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.set_process(false)
	paused = true

	# 跨过第 1 章与第 2 章的边界（Boss 在 60 秒），确认切片确实按章节断开。
	var steps := int(78.0 / DT)
	for index in steps:
		if game.state == game.GameState.PLAYING:
			game._process(DT)
		elif is_instance_valid(game.shop_overlay):
			game.close_shop()
			await process_frame
		else:
			game.state = game.GameState.PLAYING
		if index % 200 == 0:
			await process_frame
	await process_frame

	flag(game.run_chapter_rows.size() >= 1, "跨过章节边界后仍未产出任何切片")
	flag(not game.run_bucket.is_empty(), "当前章节的采集缓冲不应为空")
	if game.run_chapter_rows.size() >= 1:
		var first_row: Dictionary = game.run_chapter_rows[0]
		flag(int(first_row.ch) == 1, "第一片不是第 1 章")
		flag(float(first_row.secs) > 50.0, "第 1 章的时长明显偏短：%.1f" % float(first_row.secs))
		flag(float(first_row.alive) > 0.0, "场均敌人数没有被采到")
		flag(float(first_row.hp) > 0.0, "章节末 HP% 没有被采到")

	game.end_run(false)
	await process_frame
	flag(save.data.run_history.size() == 1, "结算没有写入战绩流水")
	if save.data.run_history.size() == 1:
		var entry: Dictionary = save.data.run_history[0]
		flag(str(entry.character) == "游侠", "结算记错了角色")
		flag(str(entry.mode) == "mainline", "结算记错了模式")
		flag(float(entry.seconds) > 70.0, "结算记录的时长不对：%.1f" % float(entry.seconds))
		flag(entry.rows.size() >= 2, "结算时没有把当前未闭合的切片收尾")
		flag(int(entry.rows[-1].ch) == 2, "最后一片不是第 2 章")
		flag(int(entry.kills) >= 0 and int(entry.boss_kills) >= 0, "击杀数据异常")
	# 重开一局必须从零开始，不能把上一局的切片带进来。
	game.start_game_after_prologue()
	await process_frame
	flag(game.run_chapter_rows.is_empty(), "重开一局后仍残留上一局的切片")
	flag(game.run_boss_ttk.is_empty(), "重开一局后仍残留上一局的 Boss TTK")
	game.show_main_menu()
	await process_frame
