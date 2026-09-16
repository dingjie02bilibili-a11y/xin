extends SkillEntity
# 头像渲染专用：只借 SkillEntity 的宠物画法，不接游戏状态。

var tint := Color("facc15")

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _draw() -> void:
	draw_circle(Vector2.ZERO, 26.0, Color(tint, 0.10))
	draw_arc(Vector2.ZERO, 25.0, 0, TAU, 40, Color(tint, 0.55), 2.2)
	draw_pet(tint, 1.0, 1.0, false)
