class_name SkillSlot
extends HBoxContainer

signal tooltip_requested(description: String, rarity: String)
signal tooltip_hidden

var icon_view: TextureRect
var cooldown_mask: ColorRect
var title_label: Label
var cooldown_label: Label
var description := ""
var rarity := "普通"
var hover_time := 0.0
var tooltip_sent := false
var hovered := false

func _ready() -> void:
	custom_minimum_size = Vector2(0, 64)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hovered = true; hover_time = 0.0; tooltip_sent = false)
	mouse_exited.connect(func(): hovered = false; hover_time = 0.0; tooltip_sent = false; tooltip_hidden.emit())
	add_theme_constant_override("separation", 8)
	icon_view = TextureRect.new()
	icon_view.custom_minimum_size = Vector2(58, 58)
	icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon_view)
	var overlay := Control.new()
	overlay.custom_minimum_size = Vector2(58, 58)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	icon_view.reparent(overlay)
	icon_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_mask = ColorRect.new()
	cooldown_mask.color = Color(0.0, 0.0, 0.0, 0.72)
	cooldown_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cooldown_mask)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(text_box)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color("e8f5ff"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(title_label)
	cooldown_label = Label.new()
	cooldown_label.add_theme_font_size_override("font_size", 13)
	cooldown_label.add_theme_color_override("font_color", Color("70d7ff"))
	text_box.add_child(cooldown_label)

func set_skill(texture: Texture2D, title: String, level: int, remaining: float, total: float, rarity_name := "普通", rarity_color := Color("9bb4d1"), energy_mode := false) -> void:
	if icon_view == null:
		return
	icon_view.texture = texture
	rarity = rarity_name
	title_label.text = title
	title_label.add_theme_color_override("font_color", rarity_color)
	var ratio := clampf(remaining / maxf(0.01, total), 0.0, 1.0)
	cooldown_mask.position = Vector2(0, 58.0 * (1.0 - ratio))
	cooldown_mask.size = Vector2(58, 58.0 * ratio)
	cooldown_mask.visible = ratio > 0.01
	if energy_mode:
		cooldown_label.text = "充能 %.1f/%.1f" % [total - remaining, total] if ratio > 0.01 else "能量已满"
	else:
		cooldown_label.text = "冷却 %.1fs" % remaining if ratio > 0.01 else "已就绪"

func _process(delta: float) -> void:
	if not hovered or tooltip_sent or description.is_empty():
		return
	hover_time += delta
	if hover_time >= 0.2:
		tooltip_sent = true
		tooltip_requested.emit(description, rarity)
