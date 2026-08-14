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
	assert(game.time_label.text.begins_with("Boss "), "Timer does not explain that it tracks the next Boss")
	game.update_skill_list()
	assert(game.deck_status_label.text.contains("宠物伤害") and game.deck_status_label.text.contains("左侧加算"), "Deck header does not show the current damage formula")
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
