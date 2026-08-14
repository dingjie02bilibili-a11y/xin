class_name Projectile
extends Area2D

var direction := Vector2.RIGHT
var speed := 620.0
var damage := 10.0
var lifetime := 2.5
var radius := 6.0
var enemy_shot := false
var piercing := 0
var hit_ids: Dictionary = {}
var target_player: Player
var homing_strength := 0.0
var burn_dps := 0.0
var frost_duration := 0.0

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if enemy_shot:
		if is_instance_valid(target_player) and global_position.distance_to(target_player.global_position) < radius + 18.0:
			target_player.take_damage(damage)
			queue_free()
	else:
		if homing_strength > 0.0:
			var closest: Enemy
			var best := INF
			for node in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(node) and not hit_ids.has(node.get_instance_id()):
					var distance := global_position.distance_squared_to(node.global_position)
					if distance < best:
						best = distance
						closest = node
			if closest:
				direction = direction.lerp((closest.global_position - global_position).normalized(), minf(1.0, homing_strength * delta)).normalized()
		for node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or hit_ids.has(node.get_instance_id()):
				continue
			if global_position.distance_to(node.global_position) < radius + node.radius:
				hit_ids[node.get_instance_id()] = true
				node.take_damage(damage, direction * 120.0, "pulse")
				if burn_dps > 0.0:
					node.apply_burn(burn_dps, 2.4)
				if frost_duration > 0.0:
					node.apply_frost(frost_duration)
				if piercing <= 0:
					queue_free()
					return
				piercing -= 1

func _draw() -> void:
	var c := Color("ff6b85") if enemy_shot else Color("7df9ff")
	draw_circle(Vector2.ZERO, radius + 3.0, Color(c, 0.2))
	draw_circle(Vector2.ZERO, radius, c)
	draw_circle(Vector2.ZERO, radius * 0.35, Color.WHITE)
