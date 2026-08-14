class_name DeckCardView
extends PanelContainer

signal tooltip_requested(description: String, rarity: String)
signal tooltip_hidden
signal swap_requested(source_id: String, target_id: String)

var card_id := ""
var description := ""
var rarity_name := "普通"
var icon_view: TextureRect
var cooldown_mask: ColorRect
var name_label: Label
var order_label: Label
var hover_time := 0.0
var tooltip_sent := false
var hovered := false

func _ready() -> void:
	custom_minimum_size = Vector2(116, 126)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", card_style(Color("10213e"), Color("355c91")))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	var icon_holder := Control.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.custom_minimum_size = Vector2(58, 58)
	icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon_holder)
	icon_view = TextureRect.new()
	icon_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon_view)
	cooldown_mask = ColorRect.new()
	cooldown_mask.color = Color(0.0, 0.0, 0.0, 0.74)
	cooldown_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(cooldown_mask)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color("e8f5ff"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	order_label = Label.new()
	order_label.add_theme_font_size_override("font_size", 8)
	order_label.add_theme_color_override("font_color", Color("facc15"))
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(order_label)

func card_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func set_card(id: String, texture: Texture2D, title: String, level: int, order: int, remaining: float, total: float, details: String, _rule: String, rarity := "普通", rarity_color := Color("9bb4d1")) -> void:
	card_id = id
	rarity_name = rarity
	add_theme_stylebox_override("panel", card_style(Color("10213e"), rarity_color))
	icon_view.texture = texture
	name_label.text = title
	name_label.add_theme_color_override("font_color", rarity_color)
	order_label.text = "#%d · %s" % [order, rarity]
	order_label.add_theme_color_override("font_color", rarity_color)
	description = details
	var ratio := clampf(remaining / maxf(0.01, total), 0.0, 1.0)
	cooldown_mask.position = Vector2(0, 58.0 * (1.0 - ratio))
	cooldown_mask.size = Vector2(58, 58.0 * ratio)
	cooldown_mask.visible = ratio > 0.01

func update_hover_from_pointer(pointer: Vector2, delta: float) -> void:
	var pointer_inside := is_visible_in_tree() and get_global_rect().has_point(pointer)
	if pointer_inside != hovered:
		hovered = pointer_inside
		hover_time = 0.0
		tooltip_sent = false
		if not hovered:
			tooltip_hidden.emit()
	if not hovered or tooltip_sent or description.is_empty():
		return
	hover_time += delta
	if hover_time >= 0.2:
		tooltip_sent = true
		tooltip_requested.emit(description, rarity_name)

func _process(delta: float) -> void:
	update_hover_from_pointer(get_global_mouse_position(), delta)

func _get_drag_data(_at_position: Vector2):
	if card_id.is_empty():
		return null
	var preview := TextureRect.new()
	preview.texture = icon_view.texture
	preview.custom_minimum_size = Vector2(54, 54)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.82)
	set_drag_preview(preview)
	return {"type":"deck_card", "id":card_id}

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("type", "") == "deck_card" and str(data.get("id", "")) != card_id

func _drop_data(_at_position: Vector2, data) -> void:
	swap_requested.emit(str(data.get("id", "")), card_id)
