class_name SkillEntity
extends Node2D

var skill_id := ""
var owner_player: Player
var game
var formation_index := 0
var formation_count := 1
var cast_flash := 0.0
var wake_flash := 0.0
var life_time := 0.0
var aim_direction := Vector2.RIGHT
var was_weak := false
var follow_velocity := Vector2.ZERO
var leash_direction := Vector2.UP
var leash_initialized := false

func setup(id: String, player_ref: Player, game_ref, index: int, count: int) -> void:
	skill_id = id
	owner_player = player_ref
	game = game_ref
	formation_index = index
	formation_count = maxi(1, count)
	leash_direction = initial_leash_direction()
	leash_initialized = true
	name = "CorePet_" + id
	z_index = 4
	was_weak = cooldown_ratio() > 0.02
	queue_redraw()

func set_formation(index: int, count: int) -> void:
	formation_index = index
	formation_count = maxi(1, count)

func release_toward(target_position: Vector2) -> void:
	cast_flash = 0.30
	if target_position != Vector2.ZERO:
		aim_direction = (target_position - global_position).normalized()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(owner_player) or game == null:
		queue_free()
		return
	life_time += delta
	cast_flash = maxf(0.0, cast_flash - delta)
	wake_flash = maxf(0.0, wake_flash - delta)
	var weak_now := cooldown_ratio() > 0.02
	if was_weak and not weak_now:
		wake_flash = 0.48
	was_weak = weak_now
	var relative_to_player := global_position - owner_player.global_position
	if relative_to_player.length() > 12.0:
		leash_direction = relative_to_player.normalized()
	elif not leash_initialized:
		leash_direction = initial_leash_direction()
		leash_initialized = true
	var bob := 4.0 * sin(life_time * pet_idle_speed() + formation_index * 1.37)
	var desired := owner_player.global_position + leash_direction * (pet_leash_distance() + bob)
	desired += pet_separation_offset()
	# 充满能量却够不着目标时主动扑向最近的敌人，而不是干等在玩家身后。
	# 玩家 260 移速永远甩得开 105 移速的追踪怪，光环/卫星类宠物否则大半时间零输出。
	if cooldown_ratio() <= 0.02 and game.has_method("pet_hunt_target"):
		var hunt: Vector2 = game.pet_hunt_target()
		if hunt != Vector2.ZERO:
			var anchor: Vector2 = owner_player.global_position
			var lunge: Vector2 = hunt - anchor
			if lunge.length() > 1.0:
				desired = anchor + lunge.normalized() * minf(lunge.length(), float(game.pet_tether_range()))
	# 链条被切断：宠物停摆，只以很慢的速度飘向玩家，等玩家走过来重新接上。
	if not tether_connected():
		var to_player: Vector2 = owner_player.global_position - global_position
		if to_player.length() > 1.0:
			global_position += to_player.normalized() * game.TETHER_DRIFT_SPEED * delta
		follow_velocity = Vector2.ZERO
		rotation = lerp_angle(rotation, to_player.angle(), minf(1.0, delta * 3.0))
		queue_redraw()
		return
	var control_state := pet_control_state()
	var control_target = pet_control_target()
	if control_state in ["stolen", "charmed"] and is_instance_valid(control_target):
		var orbit_radius := 74.0 if control_state == "stolen" else 102.0
		var orbit_angle := life_time * (1.35 if control_state == "stolen" else -1.7) + formation_index * 1.9
		desired = control_target.global_position + Vector2.from_angle(orbit_angle) * orbit_radius
	move_as_follower(desired, delta)
	# 绳子是硬的：宠物出不去这个圈。玩家跑开时它会被拽着走，
	# 这正是绳子该有的手感，也让「绳长」这件事不需要任何文字说明。
	var leash_limit: float = float(game.pet_tether_range())
	var from_player: Vector2 = global_position - owner_player.global_position
	if from_player.length() > leash_limit:
		global_position = owner_player.global_position + from_player.normalized() * leash_limit
		follow_velocity = follow_velocity.slide(from_player.normalized())
	rotation = lerp_angle(rotation, aim_direction.angle(), minf(1.0, delta * 8.0))
	queue_redraw()

func initial_leash_direction() -> Vector2:
	var centered_index := float(formation_index) - float(formation_count - 1) * 0.5
	var fan_step := minf(0.46, 2.2 / maxf(1.0, float(formation_count)))
	return Vector2.from_angle(-PI * 0.5 + centered_index * fan_step)

func pet_leash_distance() -> float:
	match skill_id:
		"orbit", "satellite_engine", "nova", "blade_dance", "aegis": return 54.0
		"gravity_well", "meteor_rain": return 74.0
	return 64.0

func pet_separation_offset() -> Vector2:
	if game == null:
		return Vector2.ZERO
	var separation := Vector2.ZERO
	for other in game.skill_entities.values():
		if not is_instance_valid(other) or other == self:
			continue
		var away: Vector2 = global_position - other.global_position
		var distance := away.length()
		if distance > 0.01 and distance < 52.0:
			separation += away.normalized() * (52.0 - distance) * 0.55
	return separation

func move_as_follower(desired: Vector2, delta: float) -> void:
	var offset: Vector2 = desired - global_position
	var distance := offset.length()
	var profile := pet_motion_profile()
	var weight := float(profile.weight)
	# 120像素以内保持宠物个性；明显掉队后逐步开启追赶加速，避免慢宠永久离队。
	var catchup := smoothstep(120.0, 520.0, distance)
	var spring_strength := float(profile.spring) * lerpf(1.0, 4.2, catchup) / weight
	var damping := (float(profile.damping) / sqrt(weight)) + catchup * 1.6
	follow_velocity += offset * spring_strength * delta
	follow_velocity *= exp(-damping * delta)
	var max_speed := float(profile.speed) * lerpf(1.0, 3.4, catchup)
	if follow_velocity.length() > max_speed:
		follow_velocity = follow_velocity.normalized() * max_speed
	global_position += follow_velocity * delta
	# 仅处理异常场景跨度；正常闪现仍会完整表现宠物加速追赶。
	if global_position.distance_to(desired) > 1400.0:
		global_position = desired
		follow_velocity = Vector2.ZERO

func pet_motion_profile() -> Dictionary:
	# speed=正常最高速度，spring=追随响应，weight越高越难改变速度，damping越低惯性越明显。
	match skill_id:
		"phase_step": return {"speed":520.0, "spring":15.5, "weight":0.65, "damping":6.8}
		"blade_dance": return {"speed":500.0, "spring":15.0, "weight":0.70, "damping":6.4}
		"orbit": return {"speed":470.0, "spring":14.2, "weight":0.74, "damping":6.2}
		"chain": return {"speed":445.0, "spring":13.5, "weight":0.82, "damping":5.9}
		"execute": return {"speed":460.0, "spring":14.0, "weight":0.78, "damping":6.1}
		"thunder_orb": return {"speed":420.0, "spring":12.2, "weight":0.92, "damping":5.6}
		"aura": return {"speed":350.0, "spring":10.0, "weight":1.18, "damping":4.8}
		"satellite_engine": return {"speed":335.0, "spring":9.2, "weight":1.42, "damping":4.1}
		"meteor_rain": return {"speed":320.0, "spring":8.8, "weight":1.48, "damping":3.9}
		"nova": return {"speed":310.0, "spring":8.4, "weight":1.55, "damping":3.8}
		"aegis": return {"speed":295.0, "spring":7.8, "weight":1.68, "damping":3.5}
		"gravity_well": return {"speed":280.0, "spring":7.2, "weight":1.82, "damping":3.2}
	return {"speed":380.0, "spring":11.0, "weight":1.0, "damping":5.2}

func pet_idle_speed() -> float:
	match skill_id:
		"orbit", "phase_step": return 3.1
		"gravity_well", "aegis": return 1.45
		"chain", "thunder_orb": return 2.65
	return 2.0

func cooldown_ratio() -> float:
	if game == null:
		return 0.0
	var cd: Dictionary = game.skill_cooldown_data(skill_id)
	return clampf(float(cd.remaining) / maxf(0.01, float(cd.total)), 0.0, 1.0)

func tether_connected() -> bool:
	if game == null or not game.has_method("pet_link_connected"):
		return true
	return bool(game.pet_link_connected(skill_id))

func pet_control_state() -> String:
	if game == null or not game.has_method("core_pet_control_state"):
		return "normal"
	return str(game.core_pet_control_state(skill_id))

func pet_control_target():
	if game == null or not game.has_method("core_pet_control_target"):
		return null
	return game.core_pet_control_target(skill_id)

func entity_color() -> Color:
	match skill_id:
		"aura": return Color("c084fc")
		"orbit": return Color("67e8f9")
		"satellite_engine": return Color("22d3ee")
		"chain": return Color("fde047")
		"nova": return Color("fb923c")
		"phase_step": return Color("70f0ff")
		"thunder_orb": return Color("60a5fa")
		"gravity_well": return Color("a78bfa")
		"blade_dance": return Color("d8e5f3")
		"meteor_rain": return Color("ef476f")
		"aegis": return Color("3b82f6")
		"execute": return Color("f472b6")
	return Color("e8f5ff")

func pet_name() -> String:
	match skill_id:
		"aura": return "暮环"
		"orbit": return "环尾"
		"satellite_engine": return "蜂蜂"
		"chain": return "弧牙"
		"nova": return "爆星"
		"phase_step": return "瞬影"
		"thunder_orb": return "雷鸣"
		"gravity_well": return "黑潮"
		"blade_dance": return "刃舞"
		"meteor_rain": return "坠火"
		"aegis": return "星垒"
		"execute": return "黑羽"
	return "星灵"

func _draw() -> void:
	var ratio := cooldown_ratio()
	var weak := ratio > 0.02
	var color := entity_color()
	var control_state := pet_control_state()
	if control_state == "stolen":
		color = Color("ef4444")
	elif control_state == "charmed":
		color = Color("f472b6")
	var mastery_rank := pet_level()
	var scale_factor := (0.76 + (1.0 - ratio) * 0.24) * (1.0 + mastery_rank * 0.018)
	if cast_flash > 0.0:
		scale_factor += cast_flash * 1.25
	if wake_flash > 0.0:
		scale_factor += sin((0.48 - wake_flash) * 18.0) * wake_flash * 0.18
	var severed := not tether_connected()
	var body_color := color if not weak else color.lerp(Color("596275"), 0.70)
	var alpha := 1.0 if not weak else 0.48 + sin(life_time * 7.0) * 0.06
	if severed:
		body_color = body_color.lerp(Color("3f4756"), 0.62)
		alpha *= 0.62
	var edition_id := str(game.card_editions.get(skill_id, ""))
	if edition_id == "polychrome":
		body_color = Color.from_hsv(fmod(life_time * 0.16 + formation_index * 0.11, 1.0), 0.72, 1.0)
	elif edition_id == "foil":
		body_color = body_color.lightened(0.28)
	draw_combo_links(alpha)
	if edition_id == "echo":
		draw_set_transform(Vector2(-7, 5), 0.0, Vector2.ONE)
		draw_pet(body_color, alpha * 0.18, scale_factor * 0.92, weak)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif edition_id == "holographic":
		draw_arc(Vector2(-5, 2), 20.0 * scale_factor, 0, TAU, 24, Color("f0abfc", 0.22 * alpha), 3.0)
	draw_circle(Vector2.ZERO, 23.0 * scale_factor, Color(body_color, 0.07 * alpha))
	draw_pet(body_color, alpha, scale_factor, weak)
	draw_pet_growth(body_color, alpha, scale_factor)
	draw_modifier_attachments(alpha, scale_factor)
	draw_combo_rune(alpha, scale_factor)
	if weak:
		var ready_arc := TAU * (1.0 - ratio)
		draw_arc(Vector2.ZERO, 25.0, -PI * 0.5, -PI * 0.5 + ready_arc, 30, Color(body_color, 0.78), 2.7)
		for i in 2:
			var bubble := Vector2(-5.0 + i * 7.0, -24.0 - i * 5.0)
			draw_circle(bubble, 2.0 + i, Color("cbd5e1", 0.34 + i * 0.12))
	else:
		draw_arc(Vector2.ZERO, 25.0 + sin(life_time * 3.0) * 1.3, 0, TAU, 30, Color(color, 0.48), 2.2)
	if wake_flash > 0.0:
		draw_arc(Vector2.ZERO, 27.0 + (0.48 - wake_flash) * 32.0, 0, TAU, 30, Color("ffffff", wake_flash), 3.0)
	if not edition_id.is_empty():
		draw_arc(Vector2.ZERO, 29.0, life_time, life_time + 4.7, 22, Color(body_color, 0.72 * alpha), 2.0)
	if control_state != "normal":
		draw_control_overlay(control_state, body_color, alpha, scale_factor)
	if cast_flash > 0.0:
		draw_line(Vector2(17, 0), Vector2(29, 0), Color(body_color, 0.85 * alpha), 2.6, true)
	if severed:
		# 断口：残留的半截链节 + 呼吸的求救环，走近即可重连
		var flare := 0.5 + 0.5 * sin(life_time * 4.4)
		draw_arc(Vector2.ZERO, 30.0 + flare * 5.0, 0, TAU, 28, Color("ef7791", 0.35 + flare * 0.35), 2.4)
		var stub := to_local(owner_player.global_position) if is_instance_valid(owner_player) else Vector2.RIGHT
		if stub.length() > 1.0:
			var dir := stub.normalized()
			for i in 3:
				var at := dir * (22.0 + i * 11.0)
				draw_circle(at, 3.4 - i * 0.8, Color("ef7791", (0.6 - i * 0.16) * flare))

func draw_control_overlay(control_state: String, color: Color, alpha: float, s: float) -> void:
	var source = pet_control_target()
	if is_instance_valid(source):
		var tether := to_local(source.global_position)
		draw_dashed_line(Vector2.ZERO, tether, Color(color, 0.46 * alpha), 2.0, 8.0, true)
	if control_state == "stolen":
		draw_rect(Rect2(Vector2(-8, -35) * s, Vector2(16, 13) * s), Color("3f1015", 0.92 * alpha), true)
		draw_arc(Vector2(0, -35) * s, 6.0 * s, PI, TAU, 16, Color("fecaca", alpha), 2.5 * s)
		draw_line(Vector2(-5, -29) * s, Vector2(5, -29) * s, Color("fecaca", alpha), 2.0 * s)
	else:
		for i in 3:
			var angle := life_time * 2.8 + TAU * float(i) / 3.0
			var heart_pos := Vector2.from_angle(angle) * 31.0 * s
			draw_circle(heart_pos + Vector2(-2, 0) * s, 3.0 * s, Color("fbcfe8", alpha))
			draw_circle(heart_pos + Vector2(2, 0) * s, 3.0 * s, Color("fbcfe8", alpha))
			draw_colored_polygon(PackedVector2Array([heart_pos + Vector2(-5, 1) * s, heart_pos + Vector2(5, 1) * s, heart_pos + Vector2(0, 8) * s]), Color("fbcfe8", alpha))
		draw_arc(Vector2.ZERO, 29.0 * s, life_time, life_time + 4.8, 24, Color("f472b6", 0.8 * alpha), 3.0 * s)

func draw_pet(color: Color, alpha: float, s: float, weak: bool) -> void:
	match skill_id:
		"aura": draw_void_jelly(color, alpha, s, weak)
		"orbit": draw_orbit_fox(color, alpha, s, weak)
		"satellite_engine": draw_hive_sprite(color, alpha, s, weak)
		"chain": draw_storm_eel(color, alpha, s, weak)
		"nova": draw_nova_lion(color, alpha, s, weak)
		"phase_step": draw_phase_fox(color, alpha, s, weak)
		"thunder_orb": draw_storm_owl(color, alpha, s, weak)
		"gravity_well": draw_void_manta(color, alpha, s, weak)
		"blade_dance": draw_blade_mantis(color, alpha, s, weak)
		"meteor_rain": draw_meteor_drake(color, alpha, s, weak)
		"aegis": draw_aegis_turtle(color, alpha, s, weak)
		"execute": draw_judgement_raven(color, alpha, s, weak)
		_:
			draw_circle(Vector2.ZERO, 12.0 * s, Color(color, alpha))

func draw_void_jelly(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var dark := Color(color.darkened(0.68), alpha)
	var bell := scaled_points(PackedVector2Array([Vector2(-15, 2), Vector2(-12, -10), Vector2(0, -17), Vector2(12, -10), Vector2(15, 2), Vector2(8, 7), Vector2(-8, 7)]), s)
	draw_colored_polygon(bell, dark)
	draw_polyline(bell + PackedVector2Array([bell[0]]), c, 2.5 * s, true)
	var tentacle_length := 7.0 if weak else 15.0
	for x in [-9.0, -3.0, 3.0, 9.0]:
		var sway := sin(life_time * 2.2 + x) * (1.5 if weak else 4.0)
		draw_polyline(PackedVector2Array([Vector2(x, 6) * s, Vector2(x + sway, 11) * s, Vector2(x - sway * 0.6, tentacle_length) * s]), c, 2.2 * s, true)
	draw_eye(Vector2(4, -5) * s, 4.0 * s, c, alpha)

func draw_orbit_fox(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var dark := Color(color.darkened(0.62), alpha)
	var body := Vector2(-3, 5 if weak else 2) * s
	draw_circle(body, 11.0 * s, dark)
	draw_circle(Vector2(9, -5) * s, 8.5 * s, c)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(3, -10), Vector2(5, -21), Vector2(11, -12)]), s), c)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(10, -12), Vector2(17, -20), Vector2(17, -7)]), s), c)
	var tail_drop := 9.0 if weak else sin(life_time * 2.8) * 3.0
	draw_arc(Vector2(-9, 4 + tail_drop) * s, 14.0 * s, 1.8, 5.2, 24, c, 6.0 * s)
	draw_arc(Vector2(-13, 5 + tail_drop) * s, 18.0 * s, 2.0, 4.8, 22, Color(color.lightened(0.45), alpha), 2.2 * s)
	draw_eye(Vector2(12, -6) * s, 3.0 * s, c, alpha)
	var moon := Vector2.from_angle(life_time * 2.0) * 19.0 * s
	draw_circle(moon, 3.2 * s, Color(color.lightened(0.55), alpha))

func draw_hive_sprite(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var dark := Color(color.darkened(0.72), alpha)
	var hub := regular_polygon(6, 11.0 * s, PI / 6.0)
	draw_colored_polygon(hub, dark)
	draw_polyline(hub + PackedVector2Array([hub[0]]), c, 2.3 * s, true)
	var wing_x := 8.0 if weak else 15.0
	draw_circle(Vector2(-wing_x, -3) * s, (5.0 if weak else 8.0) * s, Color(color.lightened(0.5), 0.42 * alpha))
	draw_circle(Vector2(wing_x, -3) * s, (5.0 if weak else 8.0) * s, Color(color.lightened(0.5), 0.42 * alpha))
	draw_line(Vector2(-4, -9) * s, Vector2(-8, -17) * s, c, 2.0 * s)
	draw_line(Vector2(4, -9) * s, Vector2(8, -17) * s, c, 2.0 * s)
	draw_circle(Vector2(-4, -2) * s, 2.2 * s, Color.WHITE)
	draw_circle(Vector2(4, -2) * s, 2.2 * s, Color.WHITE)
	for i in 3:
		draw_line(Vector2(-7 + i * 7, 5) * s, Vector2(-5 + i * 5, 11) * s, c, 2.0 * s)

func draw_storm_eel(color: Color, alpha: float, s: float, weak: bool) -> void:
	var molten := has_molten_skin()
	var c := Color("fb923c", alpha) if molten else Color(color, alpha)
	var pale := Color("67e8f9", alpha) if molten else Color(color.lightened(0.55), alpha)
	var points := PackedVector2Array([Vector2(-17, 10), Vector2(-9, -2), Vector2(0, 7), Vector2(9, -6), Vector2(16, -3)])
	if weak:
		points = PackedVector2Array([Vector2(-17, 8), Vector2(-8, 4), Vector2(0, 8), Vector2(8, 3), Vector2(15, 5)])
	draw_polyline(scaled_points(points, s), c, 8.0 * s, true)
	draw_circle(Vector2(16, -3 if not weak else 5) * s, 7.0 * s, c)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(9, -8), Vector2(7, -17), Vector2(15, -10)]), s), pale)
	draw_eye(Vector2(19, -5 if not weak else 4) * s, 2.6 * s, c, alpha)
	if not weak:
		var bolt := scaled_points(PackedVector2Array([Vector2(-8, -14), Vector2(-2, -6), Vector2(-5, -6), Vector2(1, 1)]), s)
		draw_polyline(bolt, pale, 2.5 * s, true)
	if molten:
		draw_arc(Vector2(-4, 2) * s, 17.0 * s, 2.6, 5.4, 20, Color("fde047", alpha), 2.5 * s)

func draw_nova_lion(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var dark := Color(color.darkened(0.65), alpha)
	var mane_radius := 11.0 if weak else 16.0
	for i in 10:
		var ray := Vector2.from_angle(TAU * i / 10.0 + life_time * 0.12)
		draw_line(ray * 9.0 * s, ray * mane_radius * s, c, (2.0 if weak else 3.5) * s, true)
	draw_circle(Vector2.ZERO, 10.0 * s, dark)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(-8, -6), Vector2(-12, -16), Vector2(-2, -10)]), s), c)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(8, -6), Vector2(12, -16), Vector2(2, -10)]), s), c)
	draw_eye(Vector2(4, -2) * s, 3.0 * s, c, alpha)
	draw_circle(Vector2(-2, 4) * s, 3.0 * s, Color("fff7cf", alpha))

func draw_phase_fox(color: Color, alpha: float, s: float, weak: bool) -> void:
	var phase_alpha := alpha * (0.58 if weak else 1.0)
	var c := Color(color, phase_alpha)
	var dark := Color(color.darkened(0.70), phase_alpha)
	draw_circle(Vector2(4, -2) * s, 9.0 * s, dark)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(-2, -8), Vector2(0, -20), Vector2(7, -10)]), s), c)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(7, -10), Vector2(15, -18), Vector2(13, -5)]), s), c)
	draw_eye(Vector2(8, -3) * s, 3.0 * s, c, phase_alpha)
	var tail_sway := 2.0 if weak else sin(life_time * 3.5) * 6.0
	for i in 2:
		draw_polyline(PackedVector2Array([Vector2(-3, 3) * s, Vector2(-14, (i * 9 - 5) + tail_sway) * s, Vector2(-22, (i * 12 - 7) - tail_sway) * s]), Color(color, phase_alpha * (0.8 - i * 0.2)), 5.0 * s, true)
	if not weak:
		draw_line(Vector2(-25, -10) * s, Vector2(-15, -10) * s, Color("f0abfc", phase_alpha), 2.0 * s)
		draw_line(Vector2(-22, 13) * s, Vector2(-10, 13) * s, Color("f0abfc", phase_alpha), 2.0 * s)

func draw_storm_owl(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var dark := Color(color.darkened(0.68), alpha)
	draw_circle(Vector2.ZERO, 11.0 * s, dark)
	var wing_span := 10.0 if weak else 20.0
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(-7, -3), Vector2(-wing_span, 1), Vector2(-8, 11)]), s), c)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(7, -3), Vector2(wing_span, 1), Vector2(8, 11)]), s), c)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(-8, -7), Vector2(-5, -17), Vector2(0, -9), Vector2(5, -17), Vector2(8, -7)]), s), c)
	draw_circle(Vector2(-4, -3) * s, 4.0 * s, Color.WHITE)
	draw_circle(Vector2(4, -3) * s, 4.0 * s, Color.WHITE)
	draw_circle(Vector2(-3, -3) * s, 1.8 * s, Color("17294a"))
	draw_circle(Vector2(5, -3) * s, 1.8 * s, Color("17294a"))
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(-3, 3), Vector2(5, 3), Vector2(1, 8)]), s), Color("fde047", alpha))
	if not weak:
		draw_line(Vector2(0, 10) * s, Vector2(-4, 19) * s, Color("fde047", alpha), 2.6 * s)

func draw_void_manta(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var wing := 16.0 if weak else 25.0
	var manta := scaled_points(PackedVector2Array([Vector2(-wing, -4), Vector2(-8, -10), Vector2(0, -5), Vector2(8, -10), Vector2(wing, -4), Vector2(9, 9), Vector2(0, 13), Vector2(-9, 9)]), s)
	draw_colored_polygon(manta, Color(color.darkened(0.58), alpha))
	draw_polyline(manta + PackedVector2Array([manta[0]]), c, 2.3 * s, true)
	draw_circle(Vector2(0, 1) * s, 7.0 * s, Color("060816", alpha))
	draw_arc(Vector2(0, 1) * s, 9.0 * s, life_time, life_time + 4.8, 22, c, 2.0 * s)
	draw_circle(Vector2(-5, -5) * s, 1.8 * s, Color.WHITE)
	draw_circle(Vector2(5, -5) * s, 1.8 * s, Color.WHITE)
	draw_polyline(PackedVector2Array([Vector2(0, 12) * s, Vector2(-2, 20) * s, Vector2(4, 25) * s]), c, 2.0 * s)

func draw_blade_mantis(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var dark := Color(color.darkened(0.62), alpha)
	draw_circle(Vector2(0, -7) * s, 7.0 * s, dark)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(-6, -12), Vector2(-2, -20), Vector2(0, -12), Vector2(2, -20), Vector2(6, -12)]), s), c)
	draw_line(Vector2(0, 0) * s, Vector2(0, 17) * s, c, 6.0 * s, true)
	var arm_y := 9.0 if weak else -1.0
	var left_blade := scaled_points(PackedVector2Array([Vector2(-3, arm_y), Vector2(-11, arm_y + 4), Vector2(-22, arm_y - 7), Vector2(-14, arm_y + 9)]), s)
	var right_blade := scaled_points(PackedVector2Array([Vector2(3, arm_y), Vector2(11, arm_y + 4), Vector2(22, arm_y - 7), Vector2(14, arm_y + 9)]), s)
	draw_colored_polygon(left_blade, c)
	draw_colored_polygon(right_blade, c)
	draw_circle(Vector2(-3, -8) * s, 1.8 * s, Color("70f0ff", alpha))
	draw_circle(Vector2(3, -8) * s, 1.8 * s, Color("70f0ff", alpha))

func draw_meteor_drake(color: Color, alpha: float, s: float, weak: bool) -> void:
	var frosted := has_frost_skin()
	var fire := Color(color, alpha)
	var ice := Color("93c5fd", alpha)
	var dark := Color(color.darkened(0.64), alpha)
	draw_circle(Vector2(3, 1) * s, 10.0 * s, dark)
	draw_circle(Vector2(12, -6) * s, 7.0 * s, fire)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(7, -10), Vector2(8, -20), Vector2(13, -12)]), s), ice if frosted else fire.lightened(0.3))
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(12, -11), Vector2(18, -18), Vector2(18, -7)]), s), fire)
	draw_eye(Vector2(15, -7) * s, 2.4 * s, fire, alpha)
	var wing_height := 3.0 if weak else -14.0
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(0, -3), Vector2(-10, wing_height), Vector2(-7, 4)]), s), ice if frosted else Color("fb923c", alpha))
	var flame_size := 5.0 if weak else 13.0
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(-6, 5), Vector2(-17 - flame_size * 0.3, 1), Vector2(-11, 12)]), s), ice if frosted else Color("fde047", alpha))
	if frosted:
		draw_line(Vector2(-7, -5) * s, Vector2(5, 8) * s, Color("e0f2fe", alpha), 2.0 * s)

func draw_aegis_turtle(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var dark := Color(color.darkened(0.68), alpha)
	var shell := regular_polygon(6, 14.0 * s, PI / 6.0)
	draw_colored_polygon(shell, dark)
	draw_polyline(shell + PackedVector2Array([shell[0]]), c, 2.5 * s, true)
	draw_arc(Vector2.ZERO, 8.0 * s, 0, TAU, 18, Color(color.lightened(0.45), alpha), 2.0 * s)
	if not weak:
		draw_circle(Vector2(17, 0) * s, 6.0 * s, c)
		draw_eye(Vector2(19, -1) * s, 2.0 * s, c, alpha)
		for pos in [Vector2(-9, -11), Vector2(9, -11), Vector2(-9, 11), Vector2(9, 11)]:
			draw_circle(pos * s, 3.0 * s, c)
	else:
		draw_circle(Vector2(10, 0) * s, 3.0 * s, Color(color.darkened(0.4), alpha))

func draw_judgement_raven(color: Color, alpha: float, s: float, weak: bool) -> void:
	var c := Color(color, alpha)
	var dark := Color(color.darkened(0.75), alpha)
	draw_circle(Vector2(5, -5) * s, 8.0 * s, dark)
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(11, -7), Vector2(23, -3), Vector2(11, 0)]), s), c)
	var wing := 9.0 if weak else 21.0
	draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(1, 0), Vector2(-wing, -8), Vector2(-11, 7), Vector2(-18, 15), Vector2(3, 10)]), s), dark)
	draw_polyline(scaled_points(PackedVector2Array([Vector2(-wing, -8), Vector2(-7, 3), Vector2(-18, 15)]), s), c, 2.5 * s, true)
	draw_circle(Vector2(8, -7) * s, 2.6 * s, Color("fb7185", alpha))
	if not weak:
		draw_line(Vector2(-10, 10) * s, Vector2(12, -18) * s, Color("f8fafc", alpha), 2.2 * s)

func draw_eye(position: Vector2, radius: float, color: Color, alpha: float) -> void:
	draw_circle(position, radius, Color("ffffff", alpha))
	draw_circle(position + Vector2(radius * 0.25, 0), radius * 0.48, Color(color.darkened(0.8), alpha))

func pet_level() -> int:
	if game == null:
		return 0
	if game.has_method("core_mastery_rank"):
		return int(game.core_mastery_rank(skill_id))
	return 0

func draw_pet_growth(color: Color, alpha: float, s: float) -> void:
	var marks := mini(5, maxi(0, pet_level()))
	for i in marks:
		var pos := Vector2(-12.0 + i * 6.0, 25.5 + absf(2.0 - i) * 1.2) * s
		draw_colored_polygon(star_points(pos, 2.8 * s, 1.3 * s), Color(color.lightened(0.45), 0.75 * alpha))

func draw_modifier_attachments(alpha: float, s: float) -> void:
	if game == null:
		return
	if game.is_card_active("burn"):
		var flame := scaled_points(PackedVector2Array([Vector2(-24, 10), Vector2(-31, 2), Vector2(-29, 15), Vector2(-36, 10), Vector2(-29, 22)]), s)
		draw_colored_polygon(flame, Color("fb923c", 0.82 * alpha))
		draw_line(Vector2(-9, -5) * s, Vector2(-3, 2) * s, Color("fde047", 0.78 * alpha), 2.0 * s)
		draw_line(Vector2(-4, 3) * s, Vector2(2, 9) * s, Color("fb923c", 0.78 * alpha), 2.0 * s)
	if game.is_card_active("frost_brand"):
		var left_crystal := scaled_points(PackedVector2Array([Vector2(-12, -15), Vector2(-9, -28), Vector2(-4, -17)]), s)
		var right_crystal := scaled_points(PackedVector2Array([Vector2(4, -17), Vector2(10, -29), Vector2(13, -14)]), s)
		draw_colored_polygon(left_crystal, Color("93c5fd", 0.78 * alpha))
		draw_colored_polygon(right_crystal, Color("e0f2fe", 0.78 * alpha))
	if game.is_card_active("homing"):
		var reticle_center := Vector2(18, -18) * s
		draw_arc(reticle_center, 6.0 * s, 0, TAU, 18, Color("70f0ff", 0.82 * alpha), 1.8 * s)
		draw_line(reticle_center + Vector2(-9, 0) * s, reticle_center + Vector2(-3, 0) * s, Color("ffffff", 0.75 * alpha), 1.5 * s)
		draw_line(reticle_center + Vector2(3, 0) * s, reticle_center + Vector2(9, 0) * s, Color("ffffff", 0.75 * alpha), 1.5 * s)
	if game.is_card_active("projectile"):
		var child_count := mini(3, maxi(1, int(game.upgrade_levels.get("projectile", 1))))
		for i in child_count:
			var child_angle := life_time * 1.6 + TAU * float(i) / float(child_count)
			draw_circle(Vector2.from_angle(child_angle) * 31.0 * s, 2.8 * s, Color("c084fc", 0.76 * alpha))
	if game.is_card_active("pierce"):
		draw_line(Vector2(-24, 17) * s, Vector2(25, -13) * s, Color("d8e5f3", 0.48 * alpha), 2.2 * s, true)
		draw_colored_polygon(scaled_points(PackedVector2Array([Vector2(25, -13), Vector2(17, -14), Vector2(22, -7)]), s), Color("70f0ff", 0.72 * alpha))
	if game.is_card_active("area"):
		var pulse_radius := (30.0 + sin(life_time * 2.2) * 3.0) * s
		draw_arc(Vector2.ZERO, pulse_radius, 0, TAU, 30, Color("c084fc", 0.26 * alpha), 1.8 * s)

func has_molten_skin() -> bool:
	return skill_id == "chain" and game != null and bool(game.evolutions.get("molten_circuit", false))

func has_frost_skin() -> bool:
	return skill_id == "meteor_rain" and game != null and game.is_card_active("frost_brand")

func combo_partner_ids() -> Array[String]:
	var result: Array[String] = []
	if game == null:
		return result
	match skill_id:
		"aura":
			if game.is_card_active("orbit"): result.append("orbit")
			if game.is_card_active("satellite_engine"): result.append("satellite_engine")
		"chain":
			if game.is_card_active("thunder_orb"): result.append("thunder_orb")
		"gravity_well":
			if game.is_card_active("nova"): result.append("nova")
		"phase_step":
			if game.is_card_active("blade_dance"): result.append("blade_dance")
	return result

func visual_combo_kind() -> String:
	if game == null:
		return ""
	if skill_id in ["aura", "orbit", "satellite_engine"] and game.is_card_active("aura") and (game.is_card_active("orbit") or game.is_card_active("satellite_engine")):
		return "stellar"
	if skill_id in ["chain", "thunder_orb"] and game.is_card_active("chain") and game.is_card_active("thunder_orb"):
		return "storm"
	if skill_id in ["gravity_well", "nova"] and game.is_card_active("gravity_well") and game.is_card_active("nova"):
		return "collapse"
	if skill_id in ["phase_step", "blade_dance"] and game.is_card_active("phase_step") and game.is_card_active("blade_dance"):
		return "phase_blade"
	if skill_id == "meteor_rain" and game.is_card_active("frost_brand"):
		return "frostfire"
	if skill_id == "chain" and has_molten_skin():
		return "molten"
	return ""

func combo_color(kind: String) -> Color:
	match kind:
		"stellar": return Color("c084fc")
		"storm": return Color("fde047")
		"collapse": return Color("a78bfa")
		"phase_blade": return Color("70f0ff")
		"frostfire": return Color("93c5fd")
		"molten": return Color("fb923c")
	return entity_color()

func draw_combo_links(alpha: float) -> void:
	var partners := combo_partner_ids()
	if partners.is_empty() or game == null:
		return
	var kind := visual_combo_kind()
	var link_color := combo_color(kind)
	for partner_id in partners:
		var partner = game.skill_entities.get(partner_id)
		if not is_instance_valid(partner):
			continue
		var endpoint := to_local(partner.global_position)
		if endpoint.length() > 130.0:
			continue
		draw_dashed_line(Vector2.ZERO, endpoint, Color(link_color, 0.34 * alpha), 2.0, 6.0)
		var travel := 0.5 + 0.45 * sin(life_time * 3.2)
		draw_circle(endpoint * travel, 3.0, Color(link_color.lightened(0.45), 0.85 * alpha))

func draw_combo_rune(alpha: float, s: float) -> void:
	var kind := visual_combo_kind()
	if kind.is_empty():
		return
	var rune_color := combo_color(kind)
	match kind:
		"stellar":
			for i in 4:
				var ray := Vector2.from_angle(TAU * i / 4.0 + PI / 4.0)
				draw_line(ray * 17.0 * s, ray * 22.0 * s, Color(rune_color, 0.8 * alpha), 2.0 * s)
		"storm":
			draw_arc(Vector2.ZERO, 20.0 * s, -0.7, 0.9, 12, Color(rune_color, 0.75 * alpha), 2.2 * s)
		"collapse":
			draw_arc(Vector2.ZERO, 19.0 * s, life_time, life_time + 3.9, 20, Color(rune_color, 0.75 * alpha), 2.0 * s)
		"phase_blade":
			draw_line(Vector2(-20, -20) * s, Vector2(-15, -15) * s, Color(rune_color, 0.75 * alpha), 2.5 * s)
			draw_line(Vector2(-20, 20) * s, Vector2(-15, 15) * s, Color("f0abfc", 0.75 * alpha), 2.5 * s)
		"frostfire":
			draw_arc(Vector2.ZERO, 21.0 * s, PI, TAU, 18, Color("93c5fd", 0.8 * alpha), 2.5 * s)
			draw_arc(Vector2.ZERO, 21.0 * s, 0, PI, 18, Color("fb923c", 0.8 * alpha), 2.5 * s)
		"molten":
			draw_arc(Vector2.ZERO, 21.0 * s, 0, PI, 18, Color("fb923c", 0.8 * alpha), 2.5 * s)
			draw_arc(Vector2.ZERO, 21.0 * s, PI, TAU, 18, Color("67e8f9", 0.8 * alpha), 2.5 * s)

func scaled_points(points: PackedVector2Array, scale_value: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * scale_value)
	return result

func regular_polygon(point_count: int, radius: float, angle_offset := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in point_count:
		points.append(Vector2.from_angle(angle_offset + TAU * float(i) / float(point_count)) * radius)
	return points

func star_points(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var radius := outer_radius if i % 2 == 0 else inner_radius
		points.append(center + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 10.0) * radius)
	return points
