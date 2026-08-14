class_name SkillEffect
extends Node2D

var kind := "nova"
var color := Color.WHITE
var radius := 80.0
var duration := 0.42
var life := 0.42
var direction := Vector2.RIGHT

func setup(effect_kind: String, effect_color: Color, effect_radius: float, effect_direction := Vector2.RIGHT) -> void:
	kind = effect_kind
	color = effect_color
	radius = effect_radius
	direction = effect_direction
	life = duration

func _process(delta: float) -> void:
	life -= delta
	queue_redraw()
	if life <= 0.0:
		queue_free()

func _draw() -> void:
	var p := 1.0 - life / duration
	var alpha := clampf(1.0 - p, 0.0, 1.0)
	match kind:
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
			for i in 3:
				draw_arc(Vector2.ZERO, radius * (0.25 + p * 0.6) - i * 12, p * 3.0 + i, p * 3.0 + i + 4.5, 28, Color(color, alpha), 3.0)
		"meteor":
			draw_circle(Vector2.ZERO, radius * p, Color(color, alpha * 0.16))
			draw_arc(Vector2.ZERO, radius * p, 0, TAU, 32, Color(color, alpha), 4.0)
		"shield":
			draw_arc(Vector2.ZERO, radius * (0.7 + p * 0.3), 0, TAU, 36, Color(color, alpha), 4.0)
		_:
			draw_circle(Vector2.ZERO, radius * p, Color(color, alpha * 0.15))
			draw_arc(Vector2.ZERO, radius * p, 0, TAU, 32, Color(color, alpha), 4.0)
