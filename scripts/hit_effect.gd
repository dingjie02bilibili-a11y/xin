extends Node2D

var duration := 0.32
var life := 0.32
var damage := 0.0
var lethal := false
var spark_rotation := 0.0
var label: Label
var source_color := Color("e8fbff")

func setup(amount: float, was_lethal: bool, from_color := Color("e8fbff")) -> void:
	damage = amount
	lethal = was_lethal
	source_color = from_color
	spark_rotation = randf() * TAU
	label = Label.new()
	label.text = str(int(round(amount)))
	label.position = Vector2(-28, -47)
	label.size = Vector2(56, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23 if not lethal else 29)
	# 飘字用施术宠物的颜色，让玩家一眼看出这一下是谁打的
	label.add_theme_color_override("font_color", source_color.lightened(0.45) if not lethal else Color("facc15"))
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.1, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)

func _process(delta: float) -> void:
	life -= delta
	var progress := 1.0 - life / duration
	label.position.y = -47.0 - progress * 34.0
	label.modulate.a = clampf(life / 0.14, 0.0, 1.0)
	queue_redraw()
	if life <= 0.0:
		queue_free()

func _draw() -> void:
	var progress := 1.0 - life / duration
	var alpha := clampf(1.0 - progress, 0.0, 1.0)
	var color := Color(source_color, alpha)
	if lethal:
		# 致命一击保留金色主调，外圈仍带上凶手宠物的颜色
		draw_arc(Vector2.ZERO, lerpf(8.0, 44.0, progress), 0, TAU, 26, Color(source_color, alpha * 0.7), 2.5)
		color = Color(1.0, 0.82, 0.28, alpha)
	var ring_radius := lerpf(6.0, 34.0 if lethal else 25.0, progress)
	draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 24, color, 3.0)
	for i in 7:
		var direction := Vector2.from_angle(spark_rotation + TAU * i / 7.0)
		var start := direction * lerpf(5.0, 18.0, progress)
		var end := direction * lerpf(15.0, 42.0 if lethal else 31.0, progress)
		draw_line(start, end, color, 3.0 if lethal else 2.0, true)

