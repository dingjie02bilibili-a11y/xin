extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var save = root.get_node_or_null("SaveManager")
	var original_save: Dictionary = save.data.duplicate(true)
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.equipped_cards.assign(["chain", "aura", "glass", "core_engine"])
	for id in game.equipped_cards:
		game.upgrade_levels[id] = 1
	game.card_editions = {"chain":"foil", "aura":"polychrome"}
	game.refresh_derived_card_effects()
	game.check_achievement_progress()
	assert("engine_master" in save.data.achievements, "Engine edition achievement remained unreachable")
	assert("shattered_cannon" in save.data.achievements, "Glass edition-chain achievement remained unreachable")
	assert("core_max" in save.data.achievements, "Pet edition achievement did not close")
	save.data = original_save
	save.save()
	print("EDITION_ACHIEVEMENT_CLOSURE_OK editions=", game.card_editions.size())
	quit()
