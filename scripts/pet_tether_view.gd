class_name PetTetherView
extends Node2D
# 玩家与每只宠物之间的供能链条。用一个节点画出全部链条，
# 避免每条链一个节点带来的额外开销。

var game
var owner_player: Player
var flow := 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(owner_player) or game == null:
		return
	global_position = Vector2.ZERO
	flow += delta
	queue_redraw()

func _draw() -> void:
	if game == null or not is_instance_valid(owner_player):
		return
	var here: Vector2 = owner_player.global_position
	for id in game.active_core_skill_ids():
		var entity = game.skill_entities.get(id)
		if not is_instance_valid(entity):
			continue
		if not bool(game.pet_link_connected(str(id))):
			continue
		draw_tether(here, entity.global_position, entity.entity_color(), float(game.pet_energy_ratio(str(id))))

func draw_tether(from: Vector2, to: Vector2, color: Color, charge: float) -> void:
	var span: Vector2 = to - from
	var length := span.length()
	if length < 6.0:
		return
	var direction := span / length
	var normal := direction.orthogonal()
	# 链身：一条低亮度的底线，保证远距离也看得见通道存在
	draw_line(from, to, Color(color, 0.16), 5.0, true)
	# 链节：等间距的菱形，节与节之间留缝，读起来才像「链条」而不是「光束」
	var step := 15.0
	var count := maxi(2, int(length / step))
	for i in range(1, count):
		var t := float(i) / float(count)
		var at: Vector2 = from + span * t
		var wobble: float = sin(flow * 5.0 + t * 9.0) * 2.4
		var half := 4.6
		draw_colored_polygon(PackedVector2Array([
			at + direction * half, at + normal * (2.6 + wobble * 0.15),
			at - direction * half, at - normal * (2.6 + wobble * 0.15)]),
			Color(color, 0.72))
	# 能量流：沿链条向宠物推进的亮点，充能越满推得越密
	var pulses := 1 + int(charge * 3.0)
	for i in pulses:
		var phase: float = fmod(flow * 0.85 + float(i) / float(pulses), 1.0)
		var at: Vector2 = from + span * phase
		draw_circle(at, 4.2, Color(color.lightened(0.5), 0.85))
		draw_circle(at, 7.5, Color(color, 0.20))
