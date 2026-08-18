class_name Enemy
extends CharacterBody2D

signal defeated(enemy: Enemy, xp_value: int)
signal fired(origin: Vector2, direction: Vector2, damage: float)
signal damaged(at: Vector2, amount: float, lethal: bool)
signal hazard_requested(position: Vector2, damage: float, radius: float)
signal reaction_triggered(position: Vector2)
signal affix_requested(source, effect_id: String, duration: float)
signal dramatic_attack(strength: float)

var target: Player
var kind := "追猎者"
var health := 30.0
var max_health := 30.0
var speed := 95.0
var move_velocity := Vector2.ZERO
var move_acceleration := 620.0
var turn_acceleration := 920.0
var move_deceleration := 760.0
var ai_role := "chaser"
var strafe_sign := 1.0
var decision_timer := 0.0
var lunge_timer := 0.0
var lunge_cooldown := 1.2
var damage := 8.0
var xp_value := 4
var radius := 16.0
var contact_timer := 0.0
var shoot_timer := 2.0
var is_boss := false
var tint := Color("ff5c8a")
var knockback := Vector2.ZERO
var hit_flash := 0.0
var boss_style := ""
var boss_action_timer := 1.5
var dash_time := 0.0
var dash_direction := Vector2.RIGHT
var charge_time := 0.0
var charge_direction := Vector2.RIGHT
var affixes: Array[String] = []
var boss_chapter := 1
var boss_tier := 1
var weakness_time := 0.0
var shield_time := 0.0
var shield_cycle := 3.2
var field_timer := 2.3
var deck_affix_timer := 4.8
var burn_time := 0.0
var burn_dps := 0.0
var shock_time := 0.0
var resonance_time := 0.0
var frost_time := 0.0
var conductive_time := 0.0
var collapse_time := 0.0
var collapse_stacks := 0
var phase_mark_time := 0.0
var visual_time := 0.0
var cuts_tethers := false
var tether_bait := Vector2.ZERO
const BOSS_CONTACT_SCALE := 0.5
const BOSS_HIT_CAP := 0.06

func setup(enemy_kind: String, difficulty: float, player_ref: Player) -> void:
	kind = enemy_kind
	target = player_ref
	match kind:
		"追猎者":
			health = 24.0; speed = 105.0; damage = 5.5; xp_value = 4; radius = 15.0; tint = Color("ff5c8a"); ai_role = "chaser"; move_acceleration = 680.0
		"疾行兽":
			health = 15.0; speed = 170.0; damage = 4.0; xp_value = 5; radius = 12.0; tint = Color("f97316"); ai_role = "flanker"; move_acceleration = 980.0; turn_acceleration = 1450.0
		"重甲怪":
			health = 75.0; speed = 60.0; damage = 9.0; xp_value = 9; radius = 23.0; tint = Color("a78bfa"); ai_role = "tank"; move_acceleration = 300.0; turn_acceleration = 440.0; move_deceleration = 420.0
		"咒术师":
			health = 42.0; speed = 72.0; damage = 7.0; xp_value = 10; radius = 17.0; tint = Color("22d3ee"); ai_role = "caster"; move_acceleration = 460.0; turn_acceleration = 760.0
		"星渊追猎者":
			health = 760.0; speed = 112.0; damage = 16.0; xp_value = 50; radius = 46.0; tint = Color("fb7185"); is_boss = true; boss_style = "pursuit"; move_acceleration = 760.0; turn_acceleration = 1050.0
		"星渊禁锢者":
			health = 900.0; speed = 52.0; damage = 17.0; xp_value = 60; radius = 50.0; tint = Color("a78bfa"); is_boss = true; boss_style = "control"; move_acceleration = 330.0; turn_acceleration = 520.0
		"星渊裁决者":
			health = 1080.0; speed = 48.0; damage = 20.0; xp_value = 70; radius = 52.0; tint = Color("facc15"); is_boss = true; boss_style = "burst"; move_acceleration = 300.0; turn_acceleration = 470.0
	health *= difficulty
	# 原来的斜率让六章的接触伤害只涨 10%，后期压力全部来自数量、缺少「这只怪很危险」的层次。
	# 攻击范围收进屏幕后敌人必然更靠近玩家，接触伤害相应下调
	damage *= (0.40 + difficulty * 0.62) * 0.88
	max_health = health
	cuts_tethers = kind in ["重甲怪", "咒术师"]
	strafe_sign = -1.0 if randf() < 0.5 else 1.0
	decision_timer = randf_range(0.55, 1.4)
	queue_redraw()

func set_affixes(ids: Array[String]) -> void:
	affixes = ids
	deck_affix_timer = randf_range(3.4, 5.0)
	queue_redraw()

func set_chapter_tier(chapter: int) -> void:
	boss_chapter = maxi(1, chapter)
	boss_tier = 1 + int(floor(maxi(0, boss_chapter - 1) / 3.0))
	boss_tier = mini(4, boss_tier)
	damage *= 1.0 + float(boss_chapter - 1) * 0.09

# 主线 Boss 的血量不能再由「原型基础值 × 时间线性难度」决定：三种原型在六章里
# 循环两遍，第 4 章的追猎者(760)会比第 3 章的裁决者(1080)还弱 23%。改为按章直接指定。
func set_mainline_health(value: float) -> void:
	health = value
	max_health = value

func affix_summary() -> String:
	var names: Array[String] = []
	for id in affixes:
		match id:
			"rapid_pattern": names.append("急袭脉冲")
			"riftfield": names.append("裂隙蔓延")
			"exposed_core": names.append("暴露核心")
			"prism_shield": names.append("棱镜屏障")
			"sealed_hand": names.append("封印契约")
			"pet_thief": names.append("星渊窃宠")
			"pet_charm": names.append("倒戈魅惑")
			"reverse_shuffle": names.append("逆序洗牌")
	return " · ".join(names)

func _physics_process(delta: float) -> void:
	visual_time += delta
	if burn_time > 0.0:
		burn_time -= delta
		take_damage(burn_dps * delta, Vector2.ZERO, "burn")
		if health <= 0.0:
			velocity = Vector2.ZERO
			return
	shock_time = maxf(0.0, shock_time - delta)
	resonance_time = maxf(0.0, resonance_time - delta)
	frost_time = maxf(0.0, frost_time - delta)
	conductive_time = maxf(0.0, conductive_time - delta)
	collapse_time = maxf(0.0, collapse_time - delta)
	phase_mark_time = maxf(0.0, phase_mark_time - delta)
	if collapse_time <= 0.0:
		collapse_stacks = 0
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()
	if not is_instance_valid(target) or target.health <= 0.0:
		velocity = Vector2.ZERO
		return
	contact_timer = maxf(0.0, contact_timer - delta)
	var to_target := target.global_position - global_position
	if is_boss:
		_process_boss_affixes(delta)
		_update_boss(delta, to_target)
	else:
		_update_normal(delta, to_target)
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	velocity = move_velocity * (0.58 if frost_time > 0.0 and not is_boss else (0.72 if frost_time > 0.0 else 1.0)) + knockback
	move_and_slide()
	if to_target.length() < radius + 20.0 and contact_timer <= 0.0:
		# Boss 的威胁应该来自可预警、可闪避的招式，而不是碰一下就掉一大块。
		# 追击型 Boss 冲刺速度高于玩家移速，纯接触伤害等于无法规避的固定 DPS。
		target.take_damage(damage * BOSS_CONTACT_SCALE if is_boss else damage)
		contact_timer = 1.0 if is_boss else 0.95
	if is_boss:
		queue_redraw()

func _update_normal(delta: float, to_target: Vector2) -> void:
	shoot_timer -= delta
	decision_timer -= delta
	if decision_timer <= 0.0:
		decision_timer = randf_range(0.65, 1.45)
		if randf() < 0.38:
			strafe_sign *= -1.0
	lunge_cooldown = maxf(0.0, lunge_cooldown - delta)
	lunge_timer = maxf(0.0, lunge_timer - delta)
	var predicted_target := target.global_position + target.velocity * (0.18 if ai_role != "caster" else 0.42)
	var predicted_delta := predicted_target - global_position
	var desired := predicted_delta.normalized()
	var distance := to_target.length()
	match ai_role:
		"chaser":
			if distance < 115.0:
				desired = desired.rotated(strafe_sign * 0.42)
		"flanker":
			if lunge_timer > 0.0:
				desired = to_target.normalized()
			elif distance > 150.0 and distance < 430.0 and lunge_cooldown <= 0.0:
				lunge_timer = 0.38
				lunge_cooldown = randf_range(1.5, 2.4)
				desired = to_target.normalized()
			elif distance > 120.0:
				desired = desired.rotated(strafe_sign * 0.72)
		"tank":
			desired = to_target.normalized().lerp(predicted_delta.normalized(), 0.25).normalized()
		"caster":
			if distance < 285.0:
				desired = -to_target.normalized()
			elif distance < 470.0:
				desired = to_target.normalized().rotated(strafe_sign * PI * 0.5)
			if shoot_timer <= 0.0:
				shoot_timer = randf_range(1.45, 1.9)
				var shot_direction := (predicted_target - global_position).normalized()
				fired.emit(global_position, shot_direction, damage)
	# 重甲怪与咒术师会主动去剪供能链条：普通怪只是路过误伤，精英是奔着链条去的。
	if cuts_tethers and tether_bait != Vector2.ZERO:
		var to_bait := tether_bait - global_position
		if to_bait.length() > 8.0:
			desired = desired.lerp(to_bait.normalized(), 0.72).normalized()
	desired = (desired + separation_steering() * (0.85 if ai_role != "tank" else 0.42)).normalized()
	var speed_multiplier := 1.75 if ai_role == "flanker" and lunge_timer > 0.0 else 1.0
	steer_move_velocity(desired, speed * speed_multiplier, delta, 1.7 if lunge_timer > 0.0 else 1.0)
	if move_velocity.length_squared() > 1.0:
		rotation = lerp_angle(rotation, move_velocity.angle(), minf(1.0, delta * (10.0 if ai_role == "flanker" else 6.0)))

func separation_steering() -> Vector2:
	var separation := Vector2.ZERO
	var checked := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node):
			continue
		var offset: Vector2 = global_position - node.global_position
		var safe_distance: float = radius + float(node.radius) + 18.0
		var distance_squared := offset.length_squared()
		if distance_squared > 0.01 and distance_squared < safe_distance * safe_distance:
			separation += offset.normalized() * (1.0 - sqrt(distance_squared) / safe_distance)
			checked += 1
			if checked >= 7:
				break
	return separation

func steer_move_velocity(direction: Vector2, target_speed: float, delta: float, acceleration_scale := 1.0) -> void:
	var desired_velocity := direction.normalized() * target_speed if direction.length_squared() > 0.001 else Vector2.ZERO
	var changing_direction := move_velocity.length_squared() > 1.0 and desired_velocity.length_squared() > 1.0 and move_velocity.normalized().dot(desired_velocity.normalized()) < 0.25
	var acceleration_value := (turn_acceleration if changing_direction else move_acceleration) * acceleration_scale
	if desired_velocity.length_squared() <= 0.01:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, move_deceleration * delta)
	else:
		move_velocity = move_velocity.move_toward(desired_velocity, acceleration_value * delta)

func _update_boss(delta: float, to_target: Vector2) -> void:
	boss_action_timer -= delta
	var desired := to_target.normalized()
	match boss_style:
		"pursuit":
			if boss_action_timer <= 0.0 and dash_time <= 0.0:
				boss_action_timer = 2.25 * _action_cadence()
				dash_time = 0.48
				dash_direction = desired
				# 预警冲锋终点，迫使玩家在突进前就选择侧移路线。
				hazard_requested.emit(global_position + desired * 290.0, damage * 0.55, 72.0)
				if boss_tier >= 2:
					hazard_requested.emit(global_position + desired.rotated(0.55) * 105.0, damage * 0.34, 42.0)
					hazard_requested.emit(global_position + desired.rotated(-0.55) * 105.0, damage * 0.34, 42.0)
				_open_weakness_window()
			if dash_time > 0.0:
				dash_time -= delta
				move_velocity = dash_direction * speed * (3.35 if affixes.has("rapid_pattern") else 3.0)
			else:
				steer_move_velocity((desired + separation_steering() * 0.25).normalized(), speed, delta, 1.15)
			rotation = lerp_angle(rotation, desired.angle(), delta * 8.0)
		"control":
			if boss_action_timer <= 0.0:
				boss_action_timer = 3.30 * _action_cadence()
				var center := target.global_position
				var trap_count := mini(6, (4 if affixes.has("rapid_pattern") else 3) + boss_tier - 1)
				for i in trap_count:
					var angle := TAU * i / trap_count + Time.get_ticks_msec() * 0.001
					# 圆环向中心收拢并彼此重叠：原地停留也会被命中，仍可横向离开预警区躲避。
					hazard_requested.emit(center + Vector2.from_angle(angle) * 62.0, damage * 0.40, 96.0)
				_open_weakness_window()
			if to_target.length() < 330.0:
				desired = -desired
			elif to_target.length() < 470.0:
				desired = desired.rotated(PI * 0.5)
			steer_move_velocity((desired + separation_steering() * 0.55).normalized(), speed, delta)
			rotation = lerp_angle(rotation, move_velocity.angle(), delta * 4.0)
		"burst":
			if charge_time > 0.0:
				charge_time -= delta
				move_velocity = move_velocity.move_toward(Vector2.ZERO, move_deceleration * 1.8 * delta)
				if charge_time <= 0.0:
					dramatic_attack.emit(8.0)
					var burst_count := mini(10, (7 if affixes.has("rapid_pattern") else 5) + (boss_tier - 1) * 2)
					for i in burst_count:
						fired.emit(global_position, charge_direction.rotated((i - (burst_count - 1) * 0.5) * 0.16), damage * 0.65)
					for i in 3:
						hazard_requested.emit(global_position + charge_direction.rotated((i - 1) * 0.42) * 150.0, damage * 0.42, 48.0)
					boss_action_timer = 2.7 * _action_cadence()
					_open_weakness_window()
			else:
				if boss_action_timer <= 0.0:
					charge_time = 0.8 if affixes.has("rapid_pattern") else 1.05
					charge_direction = desired
					boss_action_timer = 99.0
				if to_target.length() < 300.0:
					desired = -desired
				elif to_target.length() < 440.0:
					desired = desired.rotated(PI * 0.5)
				steer_move_velocity((desired + separation_steering() * 0.35).normalized(), speed, delta)
	rotation = lerp_angle(rotation, charge_direction.angle() if charge_time > 0.0 else desired.angle(), delta * 5.0)
	queue_redraw()

func _action_cadence() -> float:
	var cadence := 0.74 if affixes.has("rapid_pattern") else 1.0
	if affixes.has("exposed_core"):
		cadence *= 0.86
	cadence *= pow(0.94, boss_tier - 1)
	return maxf(0.58, cadence)

func _open_weakness_window() -> void:
	if affixes.has("exposed_core"):
		weakness_time = 2.2

func _process_boss_affixes(delta: float) -> void:
	weakness_time = maxf(0.0, weakness_time - delta)
	var deck_affix := ""
	for id in affixes:
		if id in ["sealed_hand", "pet_thief", "pet_charm", "reverse_shuffle"]:
			deck_affix = id
			break
	if not deck_affix.is_empty():
		deck_affix_timer -= delta
		if deck_affix_timer <= 0.0:
			deck_affix_timer = randf_range(9.0, 11.5) * _action_cadence()
			var duration := 4.2
			match deck_affix:
				"pet_thief": duration = 5.2
				"pet_charm": duration = 4.5
				"reverse_shuffle": duration = 5.5
			affix_requested.emit(self, deck_affix, duration)
	if affixes.has("prism_shield"):
		shield_cycle -= delta
		if shield_time > 0.0:
			shield_time = maxf(0.0, shield_time - delta)
		elif shield_cycle <= 0.0:
			shield_time = 2.15
			shield_cycle = 5.6
	if affixes.has("riftfield"):
		field_timer -= delta
		if field_timer <= 0.0:
			field_timer = 3.7
			for i in 2:
				var pos := target.global_position + Vector2.from_angle(randf() * TAU) * randf_range(85.0, 150.0)
				hazard_requested.emit(pos, damage * 0.42, 54.0)
	queue_redraw()

func take_damage(amount: float, push: Vector2 = Vector2.ZERO, damage_tag := "direct") -> void:
	if health <= 0.0:
		return
	if weakness_time > 0.0:
		amount *= 1.75
	if is_boss:
		# 单次伤害封顶在最大生命的 6%：Boss 是关卡高潮，不该被一次乘算爆发在
		# 三五秒内融掉。这条同时把「同一局里 5 秒和 40 秒并存」的方差压回来。
		amount = minf(amount, max_health * BOSS_HIT_CAP)
	health -= amount
	knockback += push
	hit_flash = 0.075
	damaged.emit(global_position, amount, health <= 0.0)
	queue_redraw()
	if health <= 0.0:
		defeated.emit(self, xp_value)
		queue_free()

func apply_burn(dps: float, duration: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_time = maxf(burn_time, duration)
	queue_redraw()

func apply_shock(duration := 1.4) -> bool:
	shock_time = maxf(shock_time, duration)
	if burn_time <= 0.0:
		queue_redraw()
		return false
	var stored_burn := burn_dps
	burn_time = 0.0
	burn_dps = 0.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node != self and global_position.distance_to(node.global_position) <= 92.0 + node.radius:
			node.take_damage(12.0 + stored_burn * 1.2, (node.global_position - global_position).normalized() * 45.0, "reaction")
	take_damage(18.0 + stored_burn * 1.6, Vector2.ZERO, "reaction")
	reaction_triggered.emit(global_position)
	queue_redraw()
	return true

func apply_resonance(duration := 1.25) -> void:
	resonance_time = maxf(resonance_time, duration)
	queue_redraw()

func apply_frost(duration := 1.1) -> void:
	frost_time = maxf(frost_time, duration)
	queue_redraw()

func consume_resonance() -> bool:
	if resonance_time <= 0.0:
		return false
	resonance_time = 0.0
	queue_redraw()
	return true

func apply_conductive(duration := 2.2) -> void:
	conductive_time = maxf(conductive_time, duration)
	queue_redraw()

func consume_conductive() -> bool:
	if conductive_time <= 0.0:
		return false
	conductive_time = 0.0
	queue_redraw()
	return true

func apply_collapse(stacks := 1, duration := 2.5) -> void:
	collapse_stacks = mini(8, collapse_stacks + stacks)
	collapse_time = maxf(collapse_time, duration)
	queue_redraw()

func consume_collapse() -> int:
	var result := collapse_stacks if collapse_time > 0.0 else 0
	collapse_stacks = 0
	collapse_time = 0.0
	queue_redraw()
	return result

func apply_phase_mark(duration := 1.4) -> void:
	phase_mark_time = maxf(phase_mark_time, duration)
	queue_redraw()

func consume_phase_mark() -> bool:
	if phase_mark_time <= 0.0:
		return false
	phase_mark_time = 0.0
	queue_redraw()
	return true

func consume_frost() -> bool:
	if frost_time <= 0.0:
		return false
	frost_time = 0.0
	queue_redraw()
	return true

func _draw() -> void:
	var draw_tint := Color.WHITE if hit_flash > 0.0 else tint
	if is_boss:
		for i in 8:
			var a := TAU * i / 8.0
			draw_circle(Vector2.from_angle(a) * 41.0, 14.0, tint.darkened(0.25))
		draw_circle(Vector2.ZERO, radius, Color(0.06, 0.04, 0.12))
		draw_circle(Vector2.ZERO, radius - 7.0, draw_tint)
		match boss_style:
			"pursuit":
				for i in 4:
					var spike := Vector2.from_angle(TAU * i / 4.0) * radius
					draw_line(spike * 0.55, spike * 1.28, Color("ffe4e6"), 6.0, true)
			"control":
				draw_arc(Vector2.ZERO, radius * 0.62, 0, TAU, 32, Color("f5d0fe"), 4.0)
				for i in 3:
					draw_circle(Vector2.from_angle(TAU * i / 3.0) * radius * 0.72, 7.0, Color("ddd6fe"))
			"burst":
				draw_colored_polygon(PackedVector2Array([Vector2(0, -30), Vector2(24, 0), Vector2(0, 30), Vector2(-24, 0)]), Color("fff4bf"))
				if charge_time > 0.0:
					var charge_progress := 1.0 - charge_time / 1.05
					draw_arc(Vector2.ZERO, radius + 18.0, -PI * 0.5, -PI * 0.5 + TAU * charge_progress, 40, Color("ff4d6d"), 6.0)
					draw_line(Vector2.ZERO, charge_direction * (radius + 72.0), Color("ffb3c1", 0.75), 3.0, true)
		if weakness_time > 0.0:
			draw_arc(Vector2.ZERO, radius + 11.0, 0, TAU, 36, Color("70f0ff"), 4.0)
		if shield_time > 0.0:
			draw_circle(Vector2.ZERO, radius + 17.0, Color(0.2, 0.75, 1.0, 0.12))
			draw_arc(Vector2.ZERO, radius + 17.0, 0, TAU, 42, Color("70d7ff"), 3.0)
		var deck_affixes := ["sealed_hand", "pet_thief", "pet_charm", "reverse_shuffle"]
		var active_deck_affix := ""
		for affix_id in deck_affixes:
			if affix_id in affixes:
				active_deck_affix = affix_id
				break
		if not active_deck_affix.is_empty():
			var affix_color := Color("c084fc")
			if active_deck_affix == "pet_thief": affix_color = Color("ef4444")
			elif active_deck_affix == "pet_charm": affix_color = Color("f472b6")
			elif active_deck_affix == "reverse_shuffle": affix_color = Color("facc15")
			for i in 4:
				var card_angle: float = visual_time * 0.7 + TAU * float(i) / 4.0
				var card_position := Vector2.from_angle(card_angle) * (radius + 31.0)
				draw_set_transform(card_position, card_angle + PI * 0.5, Vector2.ONE)
				draw_rect(Rect2(-7, -10, 14, 20), Color(0.04, 0.03, 0.09, 0.92), true)
				draw_rect(Rect2(-7, -10, 14, 20), affix_color, false, 2.0)
				draw_circle(Vector2.ZERO, 2.5, affix_color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var points := PackedVector2Array()
		var corners := 6 if kind != "疾行兽" else 4
		for i in corners:
			points.append(Vector2.from_angle(TAU * i / corners) * radius)
		draw_colored_polygon(points, draw_tint)
		draw_polyline(points + PackedVector2Array([points[0]]), tint.lightened(0.35), 2.0)
	draw_circle(Vector2(radius * 0.25, -5), maxf(2.5, radius * 0.12), Color.WHITE)
	draw_circle(Vector2(radius * 0.28, -5), maxf(1.2, radius * 0.06), Color("2b173d"))
	if health < max_health or is_boss:
		var w := radius * 2.0
		draw_rect(Rect2(-w * 0.5, -radius - 11.0, w, 5.0), Color("351b3b"))
		draw_rect(Rect2(-w * 0.5, -radius - 11.0, w * clampf(health / max_health, 0, 1), 5.0), Color("7cff6b"))
	if burn_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color("fb923c"), 2.0)
	if shock_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 8.0, 0, TAU, 24, Color("70d7ff"), 2.0)
	if resonance_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 11.0, 0, TAU, 24, Color("c084fc"), 2.0)
	if frost_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 14.0, 0, TAU, 24, Color("93c5fd"), 2.0)
	if conductive_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 17.0, -1.0, 4.7, 18, Color("fde047"), 2.0)
	if collapse_time > 0.0:
		draw_circle(Vector2.ZERO, radius + 5.0, Color(0.45, 0.18, 0.85, minf(0.24, collapse_stacks * 0.025)))
	if phase_mark_time > 0.0:
		draw_line(Vector2(-radius, -radius), Vector2(radius, radius), Color("70f0ff", 0.8), 2.0)
