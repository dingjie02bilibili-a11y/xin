class_name BossHazard
extends Node2D

var target: Player
var damage := 10.0
var radius := 66.0
var telegraph_time := 0.85
var active_time := 3.1
var age := 0.0
var hit_timer := 0.0

func setup(player_ref: Player, hit_damage: float, zone_radius: float) -> void:
	target = player_ref
	damage = hit_damage
	radius = zone_radius
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	hit_timer = maxf(0.0, hit_timer - delta)
	if age >= telegraph_time and is_instance_valid(target):
		if global_position.distance_to(target.global_position) < radius + 18.0 and hit_timer <= 0.0:
			target.take_damage(damage)
			hit_timer = 0.6
	queue_redraw()
	if age >= telegraph_time + active_time:
		queue_free()

func _draw() -> void:
	var is_active := age >= telegraph_time
	var color := Color("ef476f") if is_active else Color("c084fc")
	var phase := age / telegraph_time if not is_active else (age - telegraph_time) / active_time
	var alpha := 0.7 if is_active else 0.28 + phase * 0.35
	draw_circle(Vector2.ZERO, radius, Color(color, 0.13 if is_active else 0.05))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color, alpha), 3.0 if is_active else 2.0)
	if not is_active:
		draw_arc(Vector2.ZERO, radius * phase, -PI * 0.5, TAU * phase - PI * 0.5, 32, Color("f5d0fe", 0.9), 4.0)
	else:
		for i in 6:
			var direction := Vector2.from_angle(TAU * i / 6.0 + age * 1.8)
			draw_line(direction * (radius * 0.38), direction * (radius * 0.78), Color("ffd6e0", 0.65), 2.0)
