class_name Pickup
extends Node2D

var kind := "shard"
var value := 1
var velocity := Vector2.ZERO
var age := 0.0
var collected := false

func setup(pickup_kind: String, amount: int) -> void:
	kind = pickup_kind
	value = amount
	rotation = randf() * TAU
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
	position += velocity * delta
	rotation += delta * (1.5 if kind == "shard" else 0.6)
	queue_redraw()

func _draw() -> void:
	var bob := sin(age * 5.0) * 2.0
	match kind:
		"shard":
			var pts := PackedVector2Array([Vector2(0, -8 + bob), Vector2(6, bob), Vector2(0, 8 + bob), Vector2(-6, bob)])
			draw_colored_polygon(pts, Color("facc15"))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color("fff3c4"), 1.5)
		"heal":
			draw_circle(Vector2(0, bob), 9.0, Color("4ade80"))
			draw_rect(Rect2(-2, -6 + bob, 4, 12), Color.WHITE)
			draw_rect(Rect2(-6, -2 + bob, 12, 4), Color.WHITE)
