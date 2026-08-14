extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	for upgrade in game.UPGRADES:
		var id := str(upgrade.id)
		assert(not str(upgrade.name).contains("核心宠物") and not str(upgrade.desc).contains("核心宠物"), "Legacy core-pet terminology remains: " + id)
		if id in game.CORE_SKILL_CARD_IDS:
			assert(not game.skill_description(id).contains("核心宠物"), "Pet tooltip still uses legacy core-pet terminology: " + id)
			continue
		if game.is_training_card(id):
			assert(game.skill_description(id).contains("购买后立即使用，不占卡槽"), "Training card is not clearly disposable: " + id)
		else:
			assert(game.skill_description(id).contains("作用范围：【"), "Card is missing an effect scope: " + id)
	game.equipped_cards.assign(["core_engine", "aura", "glass"])
	game.upgrade_levels["core_engine"] = 1
	game.upgrade_levels["aura"] = 1
	game.upgrade_levels["glass"] = 1
	game.update_deck_card_row()
	await process_frame
	var card = game.deck_card_cache["core_engine"]
	var tooltip_events: Array[String] = []
	card.tooltip_requested.connect(func(description: String, _rarity: String): tooltip_events.append(description))
	card.update_hover_from_pointer(card.get_global_rect().get_center(), 0.21)
	assert(tooltip_events.size() == 1, "Hovering the card body did not request a tooltip")
	assert(tooltip_events[0].contains("作用范围：【对应宠物左侧全部】"), "Tooltip does not expose the card scope")
	card.update_hover_from_pointer(card.get_global_rect().end + Vector2(20, 20), 0.01)
	assert(not card.hovered, "Card hover did not end outside the full card rect")
	print("CARD_SCOPE_TOOLTIP_SMOKE_OK cards=", game.UPGRADES.size())
	quit()
