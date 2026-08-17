extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func close_enough(left: Color, right: Color) -> bool:
	return absf(left.r - right.r) < 0.01 and absf(left.g - right.g) < 0.01 and absf(left.b - right.b) < 0.01

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.equipped_cards.append("chain")
	game.upgrade_levels["chain"] = 1
	game.refresh_derived_card_effects()
	game.update_skill_list()
	await process_frame
	var rare_color: Color = game.CARD_RARITY_COLORS["稀有"]
	game.show_skill_tooltip(game.skill_description("chain"), "稀有")
	await process_frame
	var tip_label := game.skill_tooltip.get_node("TooltipText") as Label
	assert(close_enough(tip_label.get_theme_color("font_color"), rare_color), "Tooltip text does not use rarity color")
	game.update_deck_card_row()
	await process_frame
	var card = game.deck_card_cache["chain"]
	assert(close_enough(card.name_label.get_theme_color("font_color"), rare_color), "Deck card name does not use rarity color")
	print("RARITY_COLOR_SMOKE_OK rare=", rare_color.to_html(false))
	quit()
