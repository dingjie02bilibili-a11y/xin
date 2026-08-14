extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func collect_buttons(node: Node, output: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button:
			output.append(child)
		collect_buttons(child, output)

func collect_labels(node: Node, output: Array[Label]) -> void:
	for child in node.get_children():
		if child is Label:
			output.append(child)
		collect_labels(child, output)

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame
	game.card_slots = 7
	game.equipped_cards.assign(["core_engine", "aura", "glass", "chain", "burn", "frost_brand", "homing"])
	game.refresh_derived_card_effects()
	game.gain_star_shards(60)
	game.show_shop(true)
	for frame in 12:
		await process_frame
	var viewport_bottom: float = game.get_viewport().get_visible_rect().size.y
	var leave := game.shop_overlay.find_child("ShopLeave", true, false) as Button
	var contract := game.shop_overlay.find_child("ShopContract", true, false) as Button
	assert(leave != null and contract != null, "Shop action row is missing")
	var lowest_bottom: float = maxf(leave.get_global_rect().end.y, contract.get_global_rect().end.y)
	assert(lowest_bottom <= viewport_bottom - 8.0, "Shop action row extends below the viewport")
	assert(game.shop_overlay.find_child("ShopReroll", true, false) != null, "Shop action row is missing")
	var deck_labels: Array[Label] = []
	collect_labels(game.shop_deck_box, deck_labels)
	for label in deck_labels:
		assert(not label.text.contains("当前卡组"), "Legacy deck summary is still visible")
		assert(not label.text.contains("左到右结算"), "Legacy deck rules text is still visible")
	var deck_icons: Array[Node] = game.shop_deck_box.find_children("*", "TextureRect", true, false)
	assert(deck_icons.size() >= game.equipped_cards.size(), "Owned cards are not rendered with icons")
	for icon in deck_icons:
		assert(icon.texture != null, "An owned card icon is empty")
	var deck_buttons: Array[Button] = []
	collect_buttons(game.shop_deck_box, deck_buttons)
	var sell_count := 0
	for button in deck_buttons:
		assert(button.text != "←" and button.text != "→", "Shop sell cards must not expose deck ordering controls")
		if button.text.begins_with("出售"):
			sell_count += 1
	assert(sell_count == game.equipped_cards.size(), "Every owned card must have a card-style sell action")
	var checked_card_icon := false
	for index in game.shop_goods.size():
		var description := game.shop_goods_row.find_child("ShopOfferDescription%d" % index, true, false) as Control
		var offer_text := game.shop_goods_row.find_child("ShopOfferText%d" % index, true, false) as Label
		var purchase := game.shop_goods_row.find_child("ShopPurchase%d" % index, true, false) as Button
		assert(description != null and offer_text != null and purchase != null, "Shop offer must have a persistent description and purchase button")
		assert(not (description is BaseButton), "Clicking the shop card body must not act as a purchase button")
		assert(not offer_text.text.is_empty(), "Shop offer description is empty")
		assert(purchase.text.begins_with("购买"), "Available shop offer does not expose a purchase button")
		if str(game.shop_goods[index].get("kind", "")) != "card":
			continue
		var offer_icons := description.find_children("*", "TextureRect", true, false)
		assert(offer_icons.size() == 1 and offer_icons[0].texture != null, "Shop card offer is missing its icon")
		checked_card_icon = true
	assert(checked_card_icon, "Shop did not expose a card offer to verify")
	var all_shop_buttons: Array[Button] = []
	collect_buttons(game.shop_goods_row, all_shop_buttons)
	for button in all_shop_buttons:
		assert(not button.text.contains("锁定"), "Shop still exposes a lock control")
	game.shop_goods[0] = {"kind":"heal", "id":"field_heal", "price":3, "sold":false}
	game.refresh_shop_view()
	await process_frame
	var original_description: String = (game.shop_goods_row.find_child("ShopOfferText0", true, false) as Label).text
	var shards_before_purchase: int = game.star_shards
	var live_purchase := game.shop_goods_row.find_child("ShopPurchase0", true, false) as Button
	live_purchase.pressed.emit()
	await process_frame
	await process_frame
	var sold_description := game.shop_goods_row.find_child("ShopOfferText0", true, false) as Label
	var sold_button := game.shop_goods_row.find_child("ShopPurchase0", true, false) as Button
	assert(game.star_shards == shards_before_purchase - 3, "Shop purchase did not charge its price")
	assert(sold_description.text == original_description, "Sold offer replaced its description")
	assert(sold_button.text == "已出售" and sold_button.disabled, "Sold offer purchase button is not disabled")
	game.equipped_cards.erase("homing")
	game.card_slots = 7
	game.upgrade_levels["satellite_engine"] = 0
	game.shop_goods[0] = {"kind":"card", "id":"satellite_engine", "price":4, "sold":false}
	game.refresh_shop_view()
	await process_frame
	var card_body := game.shop_goods_row.find_child("ShopOfferDescription0", true, false) as Control
	var card_click := InputEventMouseButton.new()
	card_click.button_index = MOUSE_BUTTON_LEFT
	card_click.pressed = true
	var shards_before_card_click: int = game.star_shards
	card_body.gui_input.emit(card_click)
	await process_frame
	assert(game.star_shards == shards_before_card_click and not game.equipped_cards.has("satellite_engine"), "Clicking the shop card body purchased it")
	var card_purchase := game.shop_goods_row.find_child("ShopPurchase0", true, false) as Button
	card_purchase.pressed.emit()
	await process_frame
	await process_frame
	assert(game.equipped_cards.has("satellite_engine"), "Purchase button did not buy the card")
	assert((game.shop_goods_row.find_child("ShopPurchase0", true, false) as Button).text == "已出售", "Purchased card did not become sold")
	print("SHOP_LAYOUT_SMOKE_OK bottom=", lowest_bottom, " viewport=", viewport_bottom, " owned_cards=", game.equipped_cards.size())
	quit()
