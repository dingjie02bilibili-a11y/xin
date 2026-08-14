extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var ids: Array[String] = []
	for card in game.UPGRADES:
		ids.append(str(card.id))
	for id in game.ENDLESS_CARD_IDS:
		if not ids.has(str(id)):
			ids.append(str(id))
	for relic in game.BOSS_RELICS:
		if not ids.has(str(relic.id)):
			ids.append(str(relic.id))
	var fingerprints: Dictionary = {}
	for id in ids:
		var texture: Texture2D = game.make_skill_icon(id)
		assert(texture != null, "Missing icon for %s" % id)
		var fingerprint: int = hash(texture.get_image().get_data())
		assert(not fingerprints.has(fingerprint), "Duplicate icon: %s and %s" % [str(fingerprints.get(fingerprint, "")), id])
		fingerprints[fingerprint] = id
	assert(fingerprints.size() == ids.size(), "Not every card has a unique icon")
	print("UNIQUE_CARD_ICONS_SMOKE_OK cards=", ids.size())
	quit()
