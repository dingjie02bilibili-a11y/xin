extends SceneTree

# 文案门禁：这一版把全部界面文本改成 10 岁能读懂的说法，并修掉了一批
# 「描述写的和代码做的不一样」。这些结论很容易在后续改动里悄悄漂回去，
# 所以在这里钉死：术语黑名单 + 逐条复查那几处曾经对不上的描述。

const JARGON := ["加算", "乘算", "结算", "词条", "构筑", "牌型", "星式", "供能", "倍率",
	"处决", "灼烧", "寒霜", "虚空", "裂隙", "蜡封", "星象符", "精通", "养成", "索敌", "遗物"]

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game_after_prologue()
	await process_frame

	# ---- 1. 界面文案里不该再出现行话 ----
	for upgrade in game.UPGRADES:
		for field in ["name", "desc"]:
			for word in JARGON:
				assert(not str(upgrade[field]).contains(word),
					"Jargon '%s' still in card %s.%s" % [word, str(upgrade.id), field])
	for table in [game.BOSS_AFFIXES, game.STAR_SIGILS, game.CARD_SEALS, game.CARD_EDITIONS, game.BOSS_RELICS, game.EXPEDITION_VOUCHERS]:
		for entry in table:
			for word in JARGON:
				assert(not str(entry.desc).contains(word), "Jargon '%s' still in %s" % [word, str(entry.name)])

	# ---- 2. 曾经描述与实现不符的几处，逐条钉住 ----
	var desc := {}
	for upgrade in game.UPGRADES:
		desc[str(upgrade.id)] = str(upgrade.desc)

	# 首位回响从来没有「重演首次伤害判定」，只有 ×1.22
	assert(not desc["hanging_echo"].contains("重演"), "hanging_echo still promises a replay it never performs")
	assert(desc["hanging_echo"].contains("1.22"), "hanging_echo lost its multiplier")

	# 四元素加成实际要的是 gravity_well（黑潮），不是暮环的星空光环
	assert(desc["four_elements"].contains("黑潮"), "four_elements must name the pet it actually requires")

	# 雷鸣只做「有首领打首领，否则打最近」，不认识精英
	assert(not desc["thunder_orb"].contains("精英"), "thunder_orb does not actually target elites")

	# 黑羽的第二个身份（放在别的宠物右边给残血目标 ×2）必须写出来
	assert(desc["execute"].contains("右边"), "execute never documents its modifier role")

	# 位置只在「怎么放」那一行说一次，卡面不再重复。这里查的是玩家最终看到的整段，
	# 而不是原始 desc——否则一去重就会误报。

	# 不买变强是右侧生效牌，而且卖掉会清零，不是「永久」「所有宠物」
	assert(not desc["red_contract"].contains("永久"), "red_contract is not permanent")
	assert(game.skill_description("red_contract").contains("右边"),
		"red_contract must state it is a right-side card")

	# 分光镜与穿透镜效果完全相同，描述必须互相点名，不能让人以为是两种机制
	assert(desc["projectile"].contains("穿透镜") and desc["pierce"].contains("分光镜"),
		"projectile/pierce are identical and must say so")

	# ---- 2b. 「哪些宠物吃范围」这条规则不许用文字讲：
	#          用不上的时候商店不出这张牌，买下之后用范围圈当场变大来告诉玩家。----
	for pet_id in game.CORE_SKILL_CARD_IDS:
		var note: String = game.skill_description(str(pet_id))
		assert(not note.contains("范围："),
			"Pet %s is explaining the area rule in prose again" % pet_id)
	assert(desc["area"].contains("画圈") and not desc["area"].contains("陨石雨"),
		"area card should stay one short line")

	# 卡组里一只画圈宠物都没有时，加范围的卡不该出现在商店里
	game.equipped_cards.assign(["orbit", "blade_dance"])
	game.upgrade_levels["orbit"] = 1
	game.upgrade_levels["blade_dance"] = 1
	var no_exclusions: Array[String] = []
	var pool_without: Array = game.available_shop_cards(no_exclusions)
	assert(not pool_without.any(func(item): return str(item.id) == "area"),
		"area card is offered to a deck it cannot help")
	assert(not game.directed_partner_ids().has("area"),
		"the shop recommender still pushes area at orbit pets")

	# 有画圈宠物时它必须回来，否则就是把牌整个封死了
	game.equipped_cards.assign(["orbit", "aura"])
	game.upgrade_levels["aura"] = 1
	assert(game.available_shop_cards(no_exclusions).any(func(item): return str(item.id) == "area"),
		"area card vanished even though the deck has a circle pet")

	# 范围圈必须真的会变大，否则买下之后闪的那一下没有意义
	var before: float = game.pet_effect_radius("aura")
	game.stats.area = float(game.stats.area) * 1.5
	var after: float = game.pet_effect_radius("aura")
	assert(after > before, "aura radius does not react to stats.area")
	assert(is_equal_approx(game.pet_effect_radius("orbit"), 0.0),
		"orbit must not report a scalable radius")
	game.stats.area = float(game.stats.area) / 1.5

	for check_id in ["red_contract", "campfire", "green_momentum", "bull_reserve", "astronomer", "lucky_doubler"]:
		assert(not desc[check_id].begins_with("放在宠物"),
			"%s repeats the placement hint that the scope line already shows" % check_id)

	# ---- 3. 屏幕上的数字必须是真的，不靠文字解释封顶 ----
	# 飘字显示的是削顶之后的实际伤害，HUD 的倍数也是软上限之后的值，
	# 没有任何东西在骗玩家。再用一段抽象规则去解释，只是给大人看的。
	var aura_tip: String = game.skill_description("aura")
	assert(not aura_tip.contains("8倍") and not aura_tip.contains("小提示"),
		"the soft cap is back as prose in a pet tooltip")

	# ---- 4. 六个角色的开局宠物都要写进选人文案 ----
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var pet_names := {"aura":"暮环", "chain":"弧牙", "aegis":"星垒", "thunder_orb":"雷鸣",
		"orbit":"环尾", "gravity_well":"黑潮", "blade_dance":"刃舞", "phase_step":"瞬影",
		"meteor_rain":"坠火"}
	for character in game.STARTING_PETS:
		var line: String = ""
		for raw_line in source.split("\n"):
			if raw_line.contains('["%s"' % str(character)) and raw_line.contains("开局："):
				line = raw_line
				break
		assert(not line.is_empty(), "Character select row missing for " + str(character))
		for pet_id in game.STARTING_PETS[character]:
			assert(line.contains(str(pet_names[str(pet_id)])),
				"Character %s starts with %s but the select screen never says so" % [character, pet_id])

	# ---- 5. 照抄第一张要跳过照抄类的牌，而不是撞上就整局罢工 ----
	# 卡组最左边故意放一张照抄牌（照抄右边）。旧实现只看第 0 张，撞上它就直接放弃；
	# 正确行为是继续往右找到第一张能抄的牌，这里是「存钱变强」。
	# 照抄第一张本身必须放在宠物右边才进入结算，所以排在暮环之后。
	game.stats.crit = 0.0
	game.star_shards = 100
	game.upgrade_levels["brainstorm"] = 1
	game.upgrade_levels["bull_reserve"] = 1
	game.upgrade_levels["aura"] = 1
	game.equipped_cards.assign(["blueprint", "bull_reserve", "aura", "brainstorm"])
	var with_copy: float = game.resolve_core_card_chain(100.0, "aura", null)
	game.equipped_cards.assign(["blueprint", "bull_reserve", "aura"])
	var without_copy: float = game.resolve_core_card_chain(100.0, "aura", null)
	assert(with_copy > without_copy,
		"brainstorm still refuses to look past a copy card at slot 0")

	print("TEXT_AUDIT_SMOKE_OK cards=", game.UPGRADES.size())
	quit()
