class_name Player
extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)
signal hurt(amount: float)
signal healed(amount: float)
signal shield_blocked

var max_health := 100.0
var health := 100.0
var speed := 260.0
var acceleration := 1850.0
var turn_acceleration := 2700.0
var deceleration := 2250.0
var armor := 0.0
var incoming_damage_multiplier := 1.0
var regen := 0.0
var invulnerable := 0.0
var character_name := "游侠"
var color := Color("66d9ff")
var can_move := true
var selection_protected := false
var damage_flash := 0.0
var heal_flash := 0.0
var shield_charges := 0

func setup(chosen: String) -> void:
	character_name = chosen
	match chosen:
		"骑士":
			max_health += 45.0
			armor += 3.0
			speed -= 20.0
			color = Color("ffbd69")
		"星术师":
			max_health -= 10.0
			speed += 15.0
			color = Color("c084fc")
		"守卫":
			max_health += 30.0
			armor += 2.0
			speed -= 10.0
			color = Color("4ade80")
		"影舞者":
			max_health -= 15.0
			speed += 30.0
			color = Color("f472b6")
		"星火使":
			max_health += 5.0
			speed -= 5.0
			color = Color("fb923c")
	health = max_health
	queue_redraw()

func _physics_process(delta: float) -> void:
	invulnerable = maxf(0.0, invulnerable - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	heal_flash = maxf(0.0, heal_flash - delta)
	if regen > 0.0 and health > 0.0:
		heal(regen * delta)
	if not can_move:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		move_and_slide()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var desired_velocity := input.normalized() * speed
	if input.length_squared() > 0.01:
		var changing_direction := velocity.length_squared() > 1.0 and velocity.normalized().dot(desired_velocity.normalized()) < 0.35
		var active_acceleration := turn_acceleration if changing_direction else acceleration
		velocity = velocity.move_toward(desired_velocity, active_acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), minf(1.0, delta * 12.0))

func take_damage(amount: float) -> void:
	if health <= 0.0 or invulnerable > 0.0 or selection_protected:
		return
	if shield_charges > 0:
		shield_charges -= 1
		invulnerable = 0.35
		heal_flash = 0.3
		shield_blocked.emit()
		queue_redraw()
		return
	var mitigated := amount
	if armor >= 0.0:
		mitigated *= 100.0 / (100.0 + armor * 8.0)
	else:
		mitigated *= 1.0 + absf(armor) * 0.08
	var actual := maxf(1.0, mitigated * incoming_damage_multiplier)
	health = maxf(0.0, health - actual)
	invulnerable = 0.22
	damage_flash = 0.28
	hurt.emit(actual)
	health_changed.emit(health, max_health)
	queue_redraw()
	if health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	var previous := health
	health = minf(max_health, health + amount)
	if health != previous:
		heal_flash = 0.22
		healed.emit(health - previous)
		health_changed.emit(health, max_health)

func increase_max_health(amount: float) -> void:
	max_health += amount
	health += amount
	health_changed.emit(health, max_health)

func reduce_max_health(amount: float) -> void:
	max_health = maxf(20.0, max_health - amount)
	health = minf(health, max_health)
	health_changed.emit(health, max_health)

func _draw() -> void:
	var flash := invulnerable > 0.0 and int(invulnerable * 40.0) % 2 == 0
	var body_color := Color.WHITE if flash else color
	if damage_flash > 0.0:
		draw_circle(Vector2.ZERO, 28.0 + damage_flash * 25.0, Color(1.0, 0.18, 0.34, damage_flash * 0.6), false, 3.0)
	if heal_flash > 0.0:
		draw_circle(Vector2.ZERO, 25.0 + heal_flash * 18.0, Color(0.3, 1.0, 0.58, heal_flash * 0.65), false, 2.5)
	if shield_charges > 0:
		draw_arc(Vector2.ZERO, 29.0, 0, TAU, 30, Color("70d7ff"), 3.0)
	draw_circle(Vector2.ZERO, 21.0, Color(0.02, 0.04, 0.09, 0.9))
	draw_circle(Vector2.ZERO, 17.0, body_color)
	draw_circle(Vector2(7, -5), 4.0, Color.WHITE)
	draw_circle(Vector2(8, -5), 2.0, Color("13213c"))
	draw_line(Vector2(-11, 14), Vector2(-18, 22), body_color, 6.0, true)
	draw_line(Vector2(11, 14), Vector2(18, 22), body_color, 6.0, true)
