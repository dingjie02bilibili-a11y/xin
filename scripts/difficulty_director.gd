extends RefCounted
# 跨局难度心流的「慢层」。
#
# 只根据最近几局的战绩，在开局那一刻定下本局的压力系数，局内不再变动——
# 玩家应该能感知到「这一局的难度是稳定的」，而不是打着打着被暗中调参。
#
# 四条硬性约束，改这个文件之前先读：
#   1) 系数只作用在普通敌人的血量上（威胁在场上停留多久）。伤害是致死变量，
#      动它会把一次可挽救的失误变成暴毙，玩家也会读成「我被针对了」；奖励一旦
#      跟着动，玩家会发现「打得好反而掉落变少」，动机当场就废。按敌人数量调、
#      按接近速度调这两条路都实测过并被否掉，原因写在 main.gd 的 spawn_enemy 里。
#   2) 降压快、加压慢。打崩了立刻松手，打得顺要连着好几局才敢加压。
#      这条不对称是防「橡皮筋感」的核心，不要图省事改成对称的。
#   3) 证据不足就不动。少于 MIN_RUNS 局一律返回 1.0，新玩家永远打标准难度。
#   4) 幅度封顶 ±BAND。这是心流微调，不是难度选择器。
#
# 只作用于主线。无尽模式一律 1.0——那是计分模式，波数必须在不同存档之间可比。

# 取最近多少局。太短会被一局失手带偏，太长又跟不上玩家变强。
const WINDOW := 8
const MIN_RUNS := 3
const BAND := 0.15
# 每局允许的变化上限，体现「降压快、加压慢」：加压要四局才能走满整个带宽，
# 降压两局就能到底。
const MAX_STEP_UP := 0.04
const MAX_STEP_DOWN := 0.10
# 六关全清为满分；355 秒是第六关 Boss 的登场时刻，即打满全程。
const FULL_CLEAR_BOSSES := 6.0
const FULL_RUN_SECONDS := 355.0
# 越近的局权重越高：手感和构筑理解都在变，很久以前的战绩不该继续拖着。
# 这个底数要足够陡——1.35 时窗口里最老的 6 局加起来仍压过最近 2 局，
# 「刚连崩两局」会被判成和「刚连过两关」差不多，方向就反了。1.7 时最近
# 两局占约 2/3 权重。估计器允许灵敏，稳定性由 MAX_STEP_* 的单局限幅负责，
# 两者分工不要混：把限幅放宽再来压平这里，会同时失去灵敏和稳定。
const RECENCY_BASE := 1.7

static func run_score(entry: Dictionary) -> float:
	# 通关进度是主项，存活时长是次项。两者都要：只看 boss_kills 的话，
	# 「卡在第 4 关但撑满六分钟」和「第 4 关刚开始就崩」得分相同，
	# 而这两种局的压力体感完全不是一回事。
	var progress := clampf(_num(entry.get("boss_kills", 0)) / FULL_CLEAR_BOSSES, 0.0, 1.0)
	var survival := clampf(_num(entry.get("seconds", 0.0)) / FULL_RUN_SECONDS, 0.0, 1.0)
	return clampf(progress * 0.65 + survival * 0.35, 0.0, 1.0)

# 返回 0~1 的熟练度；证据不足返回 -1，调用方据此完全不介入。
static func skill_estimate(runs: Array) -> float:
	var recent: Array = []
	for entry in runs:
		if entry is Dictionary:
			recent.append(entry)
	if recent.size() > WINDOW:
		recent = recent.slice(recent.size() - WINDOW)
	if recent.size() < MIN_RUNS:
		return -1.0
	var total := 0.0
	var weight_sum := 0.0
	for index in recent.size():
		var weight: float = pow(RECENCY_BASE, float(index))
		total += run_score(recent[index]) * weight
		weight_sum += weight
	if weight_sum <= 0.0:
		return -1.0
	return clampf(total / weight_sum, 0.0, 1.0)

# runs 必须是同一角色、同一模式的战绩（角色之间强度差距很大，混着平均没有意义）。
# previous 是上一局实际生效的系数，用来限制单局变化幅度。
static func pressure_scale(runs: Array, previous := 1.0) -> float:
	var skill := skill_estimate(runs)
	if skill < 0.0:
		return 1.0
	var target := 1.0 + (skill - 0.5) * 2.0 * BAND
	var previous_scale := clampf(previous, 1.0 - BAND, 1.0 + BAND) if previous > 0.0 else 1.0
	var limited := clampf(target, previous_scale - MAX_STEP_DOWN, previous_scale + MAX_STEP_UP)
	return clampf(limited, 1.0 - BAND, 1.0 + BAND)

# 上一局实际生效的系数。旧存档没有这个字段，按 1.0 处理。
static func last_applied_scale(runs: Array) -> float:
	for index in range(runs.size() - 1, -1, -1):
		var entry = runs[index]
		if entry is Dictionary and entry.has("scale"):
			var value := _num(entry.get("scale", 1.0))
			if value > 0.0:
				return value
	return 1.0

# 给玩家看的说明。心流调节必须是明示的：玩家可以不同意，但不该被瞒着。
static func describe(scale: float) -> String:
	var percent := int(round((scale - 1.0) * 100.0))
	if percent == 0:
		return ""
	if percent > 0:
		return "远征压力 +%d%%（依据最近战绩）" % percent
	return "远征压力 %d%%（依据最近战绩）" % percent

static func _num(value) -> float:
	return float(value) if (value is float or value is int) else 0.0
