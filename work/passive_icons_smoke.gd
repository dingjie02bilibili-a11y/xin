extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func image_hash(texture: Texture2D) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(texture.get_image().get_data())
	return context.finish().hex_encode()

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var hashes: Array[String] = []
	for character in ["游侠", "骑士", "魔法师", "守卫", "影舞者", "星火使"]:
		var icon: Texture2D = game.make_character_passive_icon(character)
		assert(icon != null, "Passive icon failed to render: " + character)
		var hash := image_hash(icon)
		assert(not hashes.has(hash), "Passive icons are not visually unique: " + character)
		hashes.append(hash)
	print("PASSIVE_ICONS_SMOKE_OK unique=", hashes.size())
	quit()
