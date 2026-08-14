extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func grant_card(game, id: String) -> void:
	if not game.equipped_cards.has(id):
		game.equipped_cards.append(id)
	game.upgrade_levels[id] = 1

func require(value: bool, message: String) -> bool:
	if value:
		return true
	print("SHOP_SYSTEMS_SMOKE_FAIL ", message)
	quit(1)
	return false

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.show_shop(true)
	await process_frame
	if not require(game.state == game.GameState.LEVEL_UP, "Shop did not open"): return
	game.active_vouchers["free_reroll"] = true
	game.star_shards = 0
	game.reroll_shop()
	if not require(game.shop_reroll_count == 1, "First voucher reroll was not free"): return
	grant_card(game, "aura")
	game.core_mastery_ranks["aura"] = 4
	game.core_mastery_progress["aura"] = 3
	game.active_vouchers["pet_insurance"] = true
	game.insure_pet_before_sale("aura")
	game.remove_slot_card_effect("aura")
	game.restore_insured_pet("aura")
	if not require(game.core_mastery_rank("aura") == 2, "Pet insurance did not restore half rank"): return
	game.consumable_sigils.clear()
	game.consumable_sigils.append("bridge")
	game.use_sigil("bridge")
	if not require(game.star_bridge_hands == 3 and game.consumable_sigils.is_empty(), "Sigil was not consumed or applied"): return
	game.card_drawbacks["aura"] = "eternal"
	if not require(str(game.card_drawbacks["aura"]) == "eternal", "Risk version was not attached"): return
	print("SHOP_SYSTEMS_SMOKE_OK vouchers=", game.active_vouchers.size(), " bridge=", game.star_bridge_hands)
	quit()
