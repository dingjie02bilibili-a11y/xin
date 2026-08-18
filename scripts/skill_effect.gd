class_name SkillEffect
extends Node2D

var kind := "nova"
var color := Color.WHITE
var radius := 80.0
var duration := 0.42
var life := 0.42
var direction := Vector2.RIGHT
var span := 0.0
var thickness := 0.0
var points: PackedVector2Array = PackedVector2Array()
var pool

func setup(effect_kind: String, effect_color: Color, effect_radius: float, effect_direction := Vector2.RIGHT) -> void:
	kind = effect_kind
	color = effect_color
	radius = effect_radius
	direction = effect_direction
	duration = 0.42
	life = duration

func setup_capsule(effect_color: Color, travel: float, width: float, effect_direction: Vector2) -> void:
	# 冲刺类技能的判定是一条带宽度的线段，视觉必须和它逐像素对应，
	# 否则玩家无法用特效判断自己有没有打中。
	kind = "capsule"
	color = effect_color
	span = travel
	thickness = width
	direction = effect_direction
	duration = 0.30
	life = duration

func setup_polyline(effect_color: Color, path: PackedVector2Array) -> void:
	kind = "arc_path"
	color = effect_color
	points = path
	duration = 0.26
	life = duration

func revive() -> void:
	# 复用节点而不是重新分配：AoE 命中 40 只怪时，每秒的特效节点分配会上百次。
	span = 0.0
	thickness = 0.0
	points = PackedVector2Array()
	duration = 0.42
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	life -= delta
	queue_redraw()
	if life <= 0.0:
		retire()

func retire() -> void:
	visible = false
	set_process(false)
	if pool != null:
		pool.call("recycle_effect", self)
	else:
		queue_free()

func _draw() -> void:
	var p := 1.0 - life / duration
	var alpha := clampf(1.0 - p, 0.0, 1.0)
	match kind:
		"capsule":
			# 判定即视觉：起点就是冲刺起点，长度就是冲刺距离，宽度就是判定直径。
			var head: Vector2 = direction * span
			draw_line(Vector2.ZERO, head, Color(color, alpha * 0.30), thickness, true)
			draw_line(Vector2.ZERO, head, Color(color.lightened(0.4), alpha * 0.9), maxf(2.0, thickness * 0.22), true)
			draw_arc(Vector2.ZERO, thickness * 0.5, 0, TAU, 20, Color(color, alpha * 0.55), 2.0)
			draw_arc(head, thickness * 0.5, 0, TAU, 20, Color(color, alpha * 0.75), 2.5)
		"field":
			# 范围型技能的覆盖圈，半径与伤害判定完全一致
			draw_circle(Vector2.ZERO, radius, Color(color, alpha * 0.13))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, alpha * 0.85), 3.0)
			draw_arc(Vector2.ZERO, radius * (0.35 + p * 0.65), 0, TAU, 32, Color(color.lightened(0.4), alpha * 0.5), 2.0)
		"blades":
			# 轨道扫描：实心覆盖 + 高速旋转的刃痕
			draw_circle(Vector2.ZERO, radius, Color(color, alpha * 0.11))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(color, alpha * 0.7), 2.5)
			for i in 4:
				var sweep := p * 7.0 + TAU * float(i) / 4.0
				draw_arc(Vector2.ZERO, radius * 0.82, sweep, sweep + 1.1, 12, Color(color.lightened(0.45), alpha), 4.0)
		"arc_path":
			# 连锁电弧：每一跳都画出来，跳几次就有几段
			if points.size() >= 2:
				for i in range(points.size() - 1):
					var a: Vector2 = points[i]
					var b: Vector2 = points[i + 1]
					var mid: Vector2 = (a + b) * 0.5 + (b - a).orthogonal().normalized() * sin(p * 9.0 + float(i)) * 11.0
					draw_polyline(PackedVector2Array([a, mid, b]), Color(color, alpha), 3.4, true)
					draw_circle(b, 5.0 * alpha + 2.0, Color(color.lightened(0.5), alpha * 0.8))
		"sever":
			# 链条被切断
			for i in 6:
				var shard := Vector2.from_angle(TAU * float(i) / 6.0 + p * 2.0)
				draw_line(shard * radius * 0.3, shard * radius * (0.5 + p * 0.7), Color(color, alpha), 3.0, true)
			draw_arc(Vector2.ZERO, radius * (0.4 + p * 0.8), 0, TAU, 24, Color("ef7791", alpha), 3.0)
		"cast":
			draw_line(Vector2.ZERO, direction * radius, Color(color, alpha * 0.82), maxf(1.0, 5.0 * alpha), true)
			draw_circle(direction * radius, 5.0 + p * 8.0, Color(color, alpha * 0.55))
		"dash":
			draw_line(-direction * radius * 0.55, direction * radius * 0.35, Color(color, alpha), 14.0 * alpha, true)
			draw_arc(Vector2.ZERO, 25.0 + p * 30.0, 0, TAU, 24, Color(color, alpha), 3.0)
		"thunder":
			draw_line(Vector2(0, -radius), Vector2.ZERO, Color(color, alpha), 7.0, true)
			draw_arc(Vector2.ZERO, radius * p, 0, TAU, 28, Color(color, alpha), 4.0)
		"gravity":
			draw_circle(Vector2.ZERO, radius, Color(color, alpha * 0.10))
			for i in 3:
				draw_arc(Vector2.ZERO, radius - i * 14.0, p * 3.0 + i, p * 3.0 + i + 4.5, 30, Color(color, alpha * (1.0 - i * 0.22)), 3.0)
		"meteor":
			draw_circle(Vector2.ZERO, radius * p, Color(color, alpha * 0.16))
			draw_arc(Vector2.ZERO, radius * p, 0, TAU, 32, Color(color, alpha), 4.0)
		"shield":
			draw_arc(Vector2.ZERO, radius * (0.7 + p * 0.3), 0, TAU, 36, Color(color, alpha), 4.0)
		_:
			draw_circle(Vector2.ZERO, radius * p, Color(color, alpha * 0.15))
			draw_arc(Vector2.ZERO, radius * p, 0, TAU, 32, Color(color, alpha), 4.0)
