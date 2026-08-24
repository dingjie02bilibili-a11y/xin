extends RefCounted
# 仿真与冒烟脚本共用的合成战绩夹具。
#
# 一旦难度开始读历史，任何跑分都必须声明「跑在哪种玩家身上」。否则仿真会读到
# 本机真实存档，同一份代码在两台机器、甚至同一台机器的两天之间给出不同结论，
# A/B 对照立刻失效。三档画像刻意拉开距离：
#   weak   —— 第 2 章前后就崩，全程高损血、断链严重
#   median —— 稳定推到第 4~5 章，偶尔通关
#   strong —— 常规通关，末章仍有余血
#
# 这里的数字是「形状」而非实测值：等真实流水积累起来之后，应当用实测分布替换
# PROFILES 里的常量。
#
# scale 是这一档「已经收敛到」的压力系数。慢层对单局变化有限幅，如果夹具里
# 一律写 1.0，每次跑分都等于「第一局」，会被限幅卡在带宽中间，测不出这一档
# 真正稳定下来之后的样子。

const PROFILES := {
	"weak":   {"runs": 8, "seconds": 96.0,  "jitter": 11.0, "boss": 1, "hp": 12.0, "dmg": 620.0, "severed": 26.0, "ttk": 15.0, "deck": 3, "pets": 2, "scale": 0.85},
	"median": {"runs": 8, "seconds": 236.0, "jitter": 18.0, "boss": 3, "hp": 44.0, "dmg": 880.0, "severed": 12.0, "ttk": 9.0,  "deck": 5, "pets": 3, "scale": 1.00},
	"strong": {"runs": 8, "seconds": 372.0, "jitter": 9.0,  "boss": 6, "hp": 72.0, "dmg": 470.0, "severed": 3.0,  "ttk": 5.0,  "deck": 7, "pets": 4, "scale": 1.15}
}

static func names() -> Array:
	return ["empty", "weak", "median", "strong"]

static func profile(id: String, character := "游侠") -> Dictionary:
	if id == "" or id == "empty":
		return {"run_history": []}
	assert(PROFILES.has(id), "未知的战绩画像：%s" % id)
	var shape: Dictionary = PROFILES[id]
	var runs: Array = []
	for index in int(shape.runs):
		runs.append(_make_run(character, shape, index))
	return {"run_history": runs}

static func _make_run(character: String, shape: Dictionary, index: int) -> Dictionary:
	# 用序号做确定性抖动，绝不引入随机：同一档夹具两次生成必须逐字节一致。
	var drift := float(index % 4) - 1.5
	var seconds := maxf(20.0, float(shape.seconds) + drift * float(shape.jitter))
	var boss_kills := int(shape.boss)
	var slices := clampi(int(seconds / 60.0) + 1, 1, 6)
	var rows: Array = []
	for slice_index in slices:
		var t := float(slice_index) / float(maxi(1, slices))
		rows.append({
			"ch": slice_index + 1,
			"secs": minf(60.0, seconds - float(slice_index) * 60.0),
			"kills": int(40.0 + 55.0 * t),
			"dmg": float(shape.dmg) * (0.3 + t) / float(slices),
			"hp": maxf(0.0, 100.0 - (100.0 - float(shape.hp)) * t),
			"alive": 2.5 + 14.0 * t,
			"severed": float(shape.severed) * t,
			"hands": int(9.0 + 6.0 * t)
		})
	var ttk: Array = []
	for boss_index in boss_kills:
		ttk.append(float(shape.ttk) + float(boss_index) * 0.8)
	return {
		"character": character,
		"mode": "mainline",
		"victory": boss_kills >= 6,
		"seconds": seconds,
		"chapter": slices,
		"wave": 1,
		"kills": int(60.0 * float(slices)),
		"boss_kills": boss_kills,
		"damage": float(shape.dmg),
		"hands": int(12.0 * float(slices)),
		"earned": int(90.0 * float(slices)),
		"spent": int(78.0 * float(slices)),
		"deck": int(shape.deck),
		"pets": int(shape.pets),
		"scale": float(shape.get("scale", 1.0)),
		"ttk": ttk,
		"rows": rows
	}
