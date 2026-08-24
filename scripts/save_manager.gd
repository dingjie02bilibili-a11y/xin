extends Node

const SAVE_PATH := "user://starfall_save.json"
const CHARACTERS := ["游侠", "骑士", "星术师", "守卫", "影舞者", "星火使"]
# 战绩流水。它不提供任何属性加成——局外依旧只保留角色、成就与故事解锁——
# 存在的唯一目的是给「难度心流」留一份证据：这位玩家实际打成什么样。
# 只留最近 HISTORY_LIMIT 局，存档体积因此有上界。
const HISTORY_LIMIT := 40
const HISTORY_VERSION := 1
const DEFAULT_DATA := {
	"selected_character": "游侠",
	"settings": {"sound": true, "screenshake": true},
	"achievements": [],
	"story_read": [],
	"intro_seen": false,
	"run_history": []
}

var data: Dictionary = {}
# 无窗口脚本（work/*.gd）必须与玩家存档完全隔离：既不写回，也不读取。
# 只要读了真实存档，仿真结论就会随本机战绩漂移，A/B 两次跑分不再可比。
var isolated := false

func _ready() -> void:
	for argument in OS.get_cmdline_args():
		var value := str(argument).replace("\\", "/")
		if value.contains("work/") and value.ends_with(".gd"):
			isolated = true
			break
	load_data()

func load_data() -> void:
	data = DEFAULT_DATA.duplicate(true)
	if isolated:
		return
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)
	if not str(data.selected_character) in CHARACTERS:
		data.selected_character = "游侠"
	if not data.achievements is Array:
		data.achievements = []
	if not data.story_read is Array:
		data.story_read = []
	_sanitize_history()
	if "slot_nine" in data.achievements:
		data.achievements.erase("slot_nine")
		if not "slot_seven" in data.achievements:
			data.achievements.append("slot_seven")
	# 旧版本已经进入过无尽，必然完成过这些现版本成就条件。
	if "endless_walker" in data.achievements:
		for implied_id in ["survive_minute", "survive_three", "survive_six", "boss_breaker", "boss_trio", "six_seals"]:
			if not implied_id in data.achievements:
				data.achievements.append(implied_id)
	# 旧版本已完成六关的存档，应直接补发新增的第四、第五封印锚记。
	if "six_seals" in data.achievements:
		for implied_id in ["fourth_seal", "fifth_seal"]:
			if not implied_id in data.achievements:
				data.achievements.append(implied_id)
	if "relic_master" in data.achievements:
		for relic_id in ["predator_boots", "rift_compass", "judge_spark", "ember_vessel", "aegis_fragment", "storm_relay"]:
			var implied_id: String = "relic_" + str(relic_id)
			if not implied_id in data.achievements:
				data.achievements.append(implied_id)
	save()

func _merge(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if not target.has(key):
			continue
		if target[key] is Dictionary and source[key] is Dictionary:
			_merge(target[key], source[key])
		else:
			target[key] = source[key]

func save() -> void:
	if isolated:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

# ------------------------------------------------------------------ 战绩流水

func finish_run(summary: Dictionary) -> void:
	data.run_history.append(normalise_run(summary))
	_trim_history()
	save()

# 查询入口。角色之间强度差距很大，跨角色平均没有意义，所以默认按角色筛。
func recent_runs(character := "", mode := "", limit := 0) -> Array:
	var picked: Array = []
	for entry in _as_array(data.run_history):
		if not entry is Dictionary:
			continue
		if character != "" and str(entry.get("character", "")) != character:
			continue
		if mode != "" and str(entry.get("mode", "")) != mode:
			continue
		picked.append(entry)
	if limit > 0 and picked.size() > limit:
		picked = picked.slice(picked.size() - limit)
	return picked

# 落盘前统一收口：字段白名单 + 类型归一。外部传进来的半成品或异常值
# 都不会进存档，读回来的一侧因此可以无条件相信这份 schema。
func normalise_run(summary: Dictionary) -> Dictionary:
	var mode := str(summary.get("mode", "mainline"))
	var entry := {
		"v": HISTORY_VERSION,
		"character": str(summary.get("character", "游侠")),
		"mode": mode if mode in ["mainline", "endless"] else "mainline",
		"victory": bool(summary.get("victory", false)),
		"seconds": _round1(summary.get("seconds", 0.0)),
		"chapter": clampi(int(_num(summary.get("chapter", 1))), 0, 6),
		"wave": maxi(1, int(_num(summary.get("wave", 1)))),
		"kills": int(_num(summary.get("kills", 0))),
		"boss_kills": int(_num(summary.get("boss_kills", 0))),
		"damage": _round1(summary.get("damage", 0.0)),
		"hands": int(_num(summary.get("hands", 0))),
		"earned": int(_num(summary.get("earned", 0))),
		"spent": int(_num(summary.get("spent", 0))),
		"deck": int(_num(summary.get("deck", 0))),
		"pets": int(_num(summary.get("pets", 0))),
		"ttk": [],
		"rows": []
	}
	for value in _as_array(summary.get("ttk", [])):
		entry.ttk.append(_round1(value))
	for row in _as_array(summary.get("rows", [])):
		if row is Dictionary:
			entry.rows.append(normalise_row(row))
	return entry

func normalise_row(row: Dictionary) -> Dictionary:
	return {
		"ch": int(_num(row.get("ch", 0))),
		"secs": _round1(row.get("secs", 0.0)),
		"kills": int(_num(row.get("kills", 0))),
		"dmg": _round1(row.get("dmg", 0.0)),
		"hp": _round1(row.get("hp", 0.0)),
		"alive": _round1(row.get("alive", 0.0)),
		"severed": _round1(row.get("severed", 0.0)),
		"hands": int(_num(row.get("hands", 0)))
	}

# 仿真与冒烟脚本用它把存档钉在一个已知状态。走的是同一条 normalise 通道，
# 所以夹具产出的条目与真实结算写下的条目在结构上不可能分叉。
func apply_test_fixture(fixture: Dictionary) -> void:
	isolated = true
	data = DEFAULT_DATA.duplicate(true)
	_merge(data, fixture)
	var normalised: Array = []
	for entry in _as_array(data.run_history):
		if entry is Dictionary:
			normalised.append(normalise_run(entry))
	data.run_history = normalised
	_trim_history()

func _sanitize_history() -> void:
	var cleaned: Array = []
	for entry in _as_array(data.run_history):
		# 旧存档没有这个字段，读进来是空数组；缺 seconds 的条目一律视为脏数据。
		if entry is Dictionary and entry.has("seconds"):
			cleaned.append(entry)
	data.run_history = cleaned
	_trim_history()

func _trim_history() -> void:
	if data.run_history.size() > HISTORY_LIMIT:
		data.run_history = data.run_history.slice(data.run_history.size() - HISTORY_LIMIT)

func _num(value) -> float:
	return float(value) if (value is float or value is int or value is bool) else 0.0

func _round1(value) -> float:
	return snappedf(_num(value), 0.1)

func _as_array(value) -> Array:
	return value if value is Array else []

# ------------------------------------------------------------------ 其它

func reset_all() -> void:
	data = DEFAULT_DATA.duplicate(true)
	save()

func add_achievement(id: String) -> bool:
	if id in data.achievements:
		return false
	data.achievements.append(id)
	save()
	return true

func mark_story_read(id: String) -> void:
	if id in data.story_read:
		return
	data.story_read.append(id)
	save()
