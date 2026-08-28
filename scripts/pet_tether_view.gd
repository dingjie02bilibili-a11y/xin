class_name PetTetherView
extends Node2D
# 玩家与每只宠物之间的充能绳。用一个节点画出全部绳子，
# 避免每条绳一个节点带来的额外开销。
#
# 绳子是真的在跑物理：每条绳是一串质点，用 Verlet 积分推进，再用「每段不超过
# 绳长/段数」这一条约束反复收紧。带来两个效果，而且都不需要任何文字去解释：
#   · 宠物在身边时绳子是松的，会跟着你的走位甩来甩去；
#   · 宠物冲到最远处时每一段都被拉直，绳子绷成一条线——「到头了」是看出来的。

const SEGMENTS := 10
const CONSTRAINT_PASSES := 3
# 每 1/60 秒保留多少速度。越接近 1 越像没有阻力的绳子；0.86 留了明显的甩动，
# 又不会一直抖个不停。实际使用时按 delta 换算，避免高刷屏上绳子变硬。
const INERTIA_PER_TICK := 0.86

var game
var owner_player: Player
var flow := 0.0
# id -> {"points": Array[Vector2], "prev": Array[Vector2]}
var ropes: Dictionary = {}

func _process(delta: float) -> void:
	if not is_instance_valid(owner_player) or game == null:
		return
	global_position = Vector2.ZERO
	flow += delta
	# 掉帧时不要让绳子一步跳过去炸开，物理步长封顶在 1/30 秒。
	var step := minf(delta, 1.0 / 30.0)
	var here: Vector2 = owner_player.global_position
	var seg_limit: float = float(game.pet_tether_range()) / float(SEGMENTS)
	var alive: Dictionary = {}
	for id in game.active_core_skill_ids():
		var entity = game.skill_entities.get(id)
		if not is_instance_valid(entity) or not bool(game.pet_link_connected(str(id))):
			continue
		alive[str(id)] = true
		simulate_rope(str(id), here, entity.global_position, seg_limit, step)
	for id in ropes.keys():
		if not alive.has(id):
			ropes.erase(id)
	queue_redraw()

func simulate_rope(id: String, from: Vector2, to: Vector2, seg_limit: float, delta: float) -> void:
	var rope: Dictionary = ropes.get(id, {})
	if rope.is_empty():
		var points: Array[Vector2] = []
		var prev: Array[Vector2] = []
		for i in SEGMENTS + 1:
			var at := from.lerp(to, float(i) / float(SEGMENTS))
			points.append(at)
			prev.append(at)
		rope = {"points": points, "prev": prev}
		ropes[id] = rope
	var points: Array[Vector2] = rope.points
	var prev: Array[Vector2] = rope.prev
	# Verlet：新位置 = 当前位置 + (当前位置 - 上一帧位置) × 惯性。
	# 绳子因此会滞后、会甩，这就是「有物理」的全部来源，不需要额外动画。
	# 惯性按 delta 换算成「每秒」，否则 144Hz 上每帧衰减的次数是 60Hz 的两倍多，
	# 同一根绳子在高刷屏上会明显更硬——这个工程在帧率相关的手感上栽过一次了。
	var ticks := delta * 60.0
	var inertia := pow(INERTIA_PER_TICK, ticks)
	for i in points.size():
		var current: Vector2 = points[i]
		points[i] = current + (current - prev[i]) * inertia
		prev[i] = current
	points[0] = from
	points[points.size() - 1] = to
	for _pass in CONSTRAINT_PASSES:
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var offset: Vector2 = b - a
			var distance := offset.length()
			if distance <= seg_limit or distance < 0.001:
				continue
			# 只收不放：段长可以比上限短（松弛的绳子会垂），但不能更长。
			var fix: Vector2 = offset * ((distance - seg_limit) / distance)
			var weight_a := 0.0 if i == 0 else 0.5
			var weight_b := 0.0 if i + 1 == points.size() - 1 else 0.5
			var total := weight_a + weight_b
			if total <= 0.0:
				continue
			points[i] = a + fix * (weight_a / total)
			points[i + 1] = b - fix * (weight_b / total)
		points[0] = from
		points[points.size() - 1] = to
	# 只有「不许更长」这一条约束时，松弛的绳子会把多出来的长度胡乱堆在中间，
	# 看着像打结而不是垂弧。这里加一条很弱的回正力，把每个点往两端连线上拉一点：
	# 绷紧时它本来就在连线上、不起作用；松弛时绳子仍然会甩，只是甩完会慢慢摊平。
	var slack := clampf(1.0 - from.distance_to(to) / maxf(1.0, seg_limit * float(SEGMENTS)), 0.0, 1.0)
	var straighten := 1.0 - pow(1.0 - (0.06 + slack * 0.10), ticks)
	for i in range(1, points.size() - 1):
		var rest: Vector2 = from.lerp(to, float(i) / float(SEGMENTS))
		points[i] = points[i].lerp(rest, straighten)

func sample(points: Array[Vector2], t: float) -> Vector2:
	var span := float(points.size() - 1)
	var scaled := clampf(t, 0.0, 1.0) * span
	var index := mini(int(scaled), points.size() - 2)
	return points[index].lerp(points[index + 1], scaled - float(index))

func _draw() -> void:
	if game == null or not is_instance_valid(owner_player):
		return
	var range_limit: float = maxf(1.0, float(game.pet_tether_range()))
	for id in ropes.keys():
		var entity = game.skill_entities.get(id)
		if not is_instance_valid(entity):
			continue
		var points: Array[Vector2] = ropes[id].points
		var tension := clampf(owner_player.global_position.distance_to(entity.global_position) / range_limit, 0.0, 1.0)
		draw_rope(points, entity.entity_color(), float(game.pet_energy_ratio(str(id))), tension)

func draw_rope(points: Array[Vector2], color: Color, charge: float, tension: float) -> void:
	if points.size() < 2:
		return
	var path := PackedVector2Array(points)
	# 绳身：一条低亮度的底线，保证远距离也看得见通道存在
	draw_polyline(path, Color(color, 0.16), 5.0, true)
	# 绷到头时整条绳提亮并变粗，玩家不用读任何说明就知道「不能再远了」
	if tension > 0.86:
		var strain := (tension - 0.86) / 0.14
		draw_polyline(path, Color(color.lightened(0.5), 0.20 + strain * 0.55), 2.0 + strain * 2.0, true)
	# 链节：沿着绳子等间距排布的菱形，节与节留缝，读起来才像链条而不是光束
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var offset: Vector2 = b - a
		if offset.length() < 0.5:
			continue
		var direction: Vector2 = offset.normalized()
		var normal: Vector2 = direction.orthogonal()
		var at: Vector2 = (a + b) * 0.5
		var half := 4.6
		draw_colored_polygon(PackedVector2Array([
			at + direction * half, at + normal * 2.6,
			at - direction * half, at - normal * 2.6]),
			Color(color, 0.72))
	# 能量流：沿绳子向宠物推进的亮点，充能越满推得越密
	var pulses := 1 + int(charge * 3.0)
	for i in pulses:
		var phase: float = fmod(flow * 0.85 + float(i) / float(pulses), 1.0)
		var at: Vector2 = sample(points, phase)
		draw_circle(at, 4.2, Color(color.lightened(0.5), 0.85))
		draw_circle(at, 7.5, Color(color, 0.20))
