extends Node2D

var owner_player: Player
var game
var spin := 0.0
var pulse := 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		return
	global_position = owner_player.global_position
	if game != null and game.has_method("orbit_pet_source_id") and game.has_method("skill_entity_origin"):
		global_position = game.skill_entity_origin(game.orbit_pet_source_id())
	spin += delta * 2.2
	pulse += delta
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	if game.has_orbit and (game.is_card_active("orbit") or game.is_card_active("satellite_engine") or game.is_card_active("blade_dance")):
		var count: int = game.orbit_count
		for i in count:
			var pos := Vector2.from_angle(spin + TAU * i / count) * 74.0
			draw_circle(pos, 11.0, Color(0.25, 0.95, 1.0, 0.18))
			draw_circle(pos, 7.0, Color("a7f3ff"))
