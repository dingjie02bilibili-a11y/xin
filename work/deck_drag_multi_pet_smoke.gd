extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.equipped_cards.assign(["core_engine", "aura", "glass", "chain"])
	game.stats.crit = 0.0
	game.bonus_crit_damage = 0.0
	game.card_editions.clear()
	for id in game.equipped_cards:
		game.upgrade_levels[id] = 1
	game.refresh_derived_card_effects()
	game.update_deck_card_row()
	await process_frame
	var aura_card = game.deck_card_cache["aura"]
	assert(not contains_button(aura_card), "Deck card still contains arrow or primary-pet buttons")
	assert(aura_card.icon_view.get_parent().custom_minimum_size.x >= 58.0, "Card icon does not use the freed card area")
	aura_card._drop_data(Vector2.ZERO, {"type":"deck_card", "id":"chain"})
	assert(game.equipped_cards == ["core_engine", "chain", "glass", "aura"], "Drag/drop did not swap deck cards")
	game.equipped_cards.assign(["core_engine", "aura", "glass", "chain"])
	game.update_deck_card_row()
	var aura_damage: float = game.resolve_core_card_chain(10.0, "aura")
	var chain_damage: float = game.resolve_core_card_chain(10.0, "chain")
	assert(aura_damage > chain_damage, "Core pets are not independently resolving modifiers around their own positions")
	print("DECK_DRAG_MULTI_PET_SMOKE_OK order=", game.equipped_cards, " aura=", aura_damage, " chain=", chain_damage)
	quit()

func contains_button(node: Node) -> bool:
	for child in node.get_children():
		if child is Button or contains_button(child):
			return true
	return false
