class_name EnergyBolt
extends Node2D

var target_pet: Node2D
var target_skill_id := ""
var game
var energy_amount := 1.0
var speed := 760.0
var lifetime := 1.8
var trail: Array[Vector2] = []
var delivered := false

func setup(target: Node2D, skill_id: String, game_ref, amount: float, travel_speed: float) -> void:
	target_pet = target
	target_skill_id = skill_id
	game = game_ref
	energy_amount = amount
	speed = travel_speed
	z_index = 8
	queue_redraw()

func _process(delta: float) -> void:
	if delivered:
		return
	if not is_instance_valid(target_pet) or game == null:
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var offset := target_pet.global_position - global_position
	if offset.length() <= 19.0:
		delivered = true
		game.on_pet_energy_received(target_skill_id, energy_amount)
		queue_free()
		return
	global_position += offset.normalized() * minf(offset.length(), speed * delta)
	trail.push_front(Vector2.ZERO)
	for index in trail.size():
		trail[index] -= offset.normalized() * speed * delta
	if trail.size() > 5:
		trail.pop_back()
	queue_redraw()

func _draw() -> void:
	for index in trail.size():
		var alpha := 0.20 * (1.0 - float(index) / maxf(1.0, trail.size()))
		draw_circle(trail[index], maxf(1.0, 4.0 - index * 0.55), Color(0.45, 0.95, 1.0, alpha))
	draw_circle(Vector2.ZERO, 8.0, Color(0.22, 0.86, 1.0, 0.18))
	draw_circle(Vector2.ZERO, 4.8, Color("70f0ff"))
	draw_circle(Vector2(-1.2, -1.2), 1.8, Color.WHITE)
