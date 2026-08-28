extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	assert(game.active_hand_label == null and game.resonance_bar == null, "Removed auto-cast status still exists")
	assert(game.time_label.text.begins_with("下个首领"), "Timer does not explain that it tracks the next Boss")
	# 守卫/影舞者/星火使的条件被动必须有一个真的存在的标签来显示当前状态，
	# 否则那段代码会像以前挂在 active_hand_label 上一样，写了却永远不会显示。
	assert(is_instance_valid(game.passive_state_label), "Conditional passives have no live readout")
	game.update_skill_list()
	# 卡组顶栏原来是一行公式（宠物伤害＝基础值 × … × 左侧加算 × 右侧乘算），
	# 对 10 岁玩家不可读，已改成大白话。这里钉住新说法，并禁止行话回流。
	assert(game.deck_status_label.text.contains("左边的牌") and game.deck_status_label.text.contains("右边的牌"), "Deck header does not explain left/right in plain words")
	assert(not game.deck_status_label.text.contains("加算") and not game.deck_status_label.text.contains("乘算") and not game.deck_status_label.text.contains("倍率"), "Accounting jargon is back in the deck header")
	assert(not game.deck_status_label.text.contains("卡组 ") and not game.deck_status_label.text.contains("主核心") and not game.deck_status_label.text.contains("最近触发"), "Deck header still shows removed status text")
	var found_currency_hint := false
	var found_passive_badge := false
	for label in game.hud.find_children("*", "Label", true, false):
		found_currency_hint = found_currency_hint or "本局结算后清空" in label.text
		found_passive_badge = found_passive_badge or "固有特性" in label.text
	assert(not found_currency_hint, "Text under the health bar was not removed")
	assert(found_passive_badge, "Compact character passive badge is missing")
	var passive_icon := game.hud.find_child("PassiveIcon", true, false) as TextureRect
	var passive_panel := game.hud.find_child("PassivePanel", true, false) as PanelContainer
	assert(passive_icon != null and passive_icon.texture != null, "Character passive icon is missing")
	assert(passive_icon.get_global_rect().end.x <= passive_panel.get_global_rect().end.x and passive_icon.get_global_rect().end.y <= passive_panel.get_global_rect().end.y, "Character passive icon is clipped")
	for panel in game.hud.find_children("*", "PanelContainer", true, false):
		assert(not (panel.position.x >= 950.0 and panel.size.y > 180.0), "Oversized right-side passive panel still exists")
	print("HUD_CLEANUP_SMOKE_OK timer=", game.time_label.text)
	quit()
