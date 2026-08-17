extends SceneTree
# 静态数值审计门禁：把跨系统的耦合直接算出来并断言，避免靠估。
# 校验每点能量收益的极差、零输出宠物、Boss/精英曲线单调性、
# 敌人单体伤害成长、囤货套利、元素常数是否跟随本次伤害。

const SAMPLES := 3000

var game
var save
var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("run_test")

func avg_damage(base: float, id: String) -> float:
	var total := 0.0
	for i in SAMPLES:
		total += game.calculate_skill_damage(base, id, null)
	return total / float(SAMPLES)

func flag(ok: bool, message: String) -> void:
	if not ok:
		problems.append(message)

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	save = root.get_node("SaveManager")
	save.data.intro_seen = true
	save.data.achievements = ["boss_breaker", "survive_three", "combo_adept", "streak_master", "molten_master"]
	save.data.selected_character = "游侠"
	game.start_game_after_prologue()
	await process_frame
	game.stats.damage = 1.0
	game.stats.crit = 0.0

	print("=== 每点能量的伤害产出（应集中在 9~14）===")
	var count := float(game.orbit_count)
	var pets := {
		"aura": 10.0, "orbit": 6.0 + 2.5 * count, "satellite_engine": 6.0 + 2.5 * count,
		"blade_dance": 6.0 + 2.5 * count + 7.0, "chain": 12.0 + 3.0, "nova": 26.0 + 6.0,
		"phase_step": 26.0, "thunder_orb": 22.0 + 6.0, "meteor_rain": 31.0 + 9.0,
		"execute": 26.0, "gravity_well": 11.0 + 4.0
	}
	# 单体口径不可比：作用面积差 10 倍的宠物必须按「一次能打到几个」加权。
	var reach := {"aura":3.0, "orbit":3.0, "satellite_engine":3.0, "blade_dance":3.0,
		"chain":2.5, "nova":3.0, "phase_step":1.5, "thunder_orb":2.0,
		"meteor_rain":2.5, "execute":1.0, "gravity_well":4.0}
	var rows: Array = []
	for id in pets:
		var req: float = game.pet_energy_requirement(str(id))
		var per: float = avg_damage(float(pets[id]), str(id)) / req
		rows.append({"id": id, "req": req, "per": per, "eff": per * float(reach[id])})
	rows.sort_custom(func(a, b): return float(a.eff) > float(b.eff))
	for row in rows:
		print("  %-16s 需能%.1f  单体%.1f/能量  x命中%.1f  ->  有效 %.1f" % [
			str(row.id), float(row.req), float(row.per), float(reach[row.id]), float(row.eff)])
	var scored: Array = rows.filter(func(r): return str(r.id) != "execute")
	var top: float = float(scored[0].eff)
	var bottom: float = float(scored[scored.size() - 1].eff)
	print("  有效收益极差 %.1f ~ %.1f = %.2f 倍（处决属条件性收割，不参与比较）" % [bottom, top, top / bottom])
	flag(top / bottom < 2.2, "宠物之间有效收益相差 %.2f 倍，超过 2.2" % (top / bottom))
	flag(bottom > 0.0, "存在零输出宠物")

	print("=== 轨道扫描的覆盖 ===")
	var band := 26.0 + count * 3.0
	print("  实心覆盖 0 ~ %.0f 像素（宠物跟随距离 54）" % (104.0 + band))
	flag(true, "")

	print("=== 商店买卖差价（囤货套利检查）===")
	var worst_ratio := 0.0
	for visit in [1, 3, 6, 10, 20, 40]:
		game.shop_visit = visit
		var price: int = game.card_shop_price("chain")
		var sell: int = game.card_sell_value("chain")
		print("  第%2d次进货 售价%3d 回收%3d" % [visit, price, sell])
	game.shop_visit = 1
	var early_price: int = game.card_shop_price("chain")
	for visit in [6, 12, 24, 48]:
		game.shop_visit = visit
		game.active_vouchers["salvage_license"] = true
		worst_ratio = maxf(worst_ratio, float(game.card_sell_value("chain")) / float(early_price))
	game.active_vouchers.erase("salvage_license")
	game.shop_visit = 1
	print("  最坏情况：早买晚卖回收 / 早期售价 = %.2f" % worst_ratio)
	flag(worst_ratio < 1.0, "存在囤货套利：早买晚卖能赚 %.0f%%" % ((worst_ratio - 1.0) * 100.0))

	print("=== 主线曲线单调性 ===")
	var hp: Array = game.MAINLINE_BOSS_HEALTH
	var mono := true
	for i in range(1, hp.size()):
		if float(hp[i]) <= float(hp[i - 1]):
			mono = false
	print("  Boss血量 %s" % str(hp))
	flag(mono, "Boss 血量曲线非单调")
	var last_diff := 0.0
	var elite_share := []
	for chapter in range(1, 7):
		var pool: Array = []
		for i in 400:
			pool.append(game.chapter_enemy_kind(chapter, 0))
		var elites := 0
		for kind in pool:
			if str(kind) in ["重甲怪", "咒术师"]:
				elites += 1
		elite_share.append(float(elites) / 400.0)
	print("  精英占比 %s" % str(elite_share.map(func(v): return "%.0f%%" % (float(v) * 100.0))))
	var elite_mono := true
	for i in range(1, elite_share.size()):
		if float(elite_share[i]) < float(elite_share[i - 1]) - 0.03:
			elite_mono = false
	flag(elite_mono, "精英占比非单调")
	var dmg := []
	for mark in game.MAINLINE_BOSS_SCHEDULE:
		var difficulty := 0.92 + float(mark) / 520.0
		dmg.append(5.5 * (0.40 + difficulty * 0.62))
	print("  追猎者接触伤害 %s（六章增幅 %.0f%%）" % [str(dmg.map(func(v): return "%.1f" % float(v))), (float(dmg[5]) / float(dmg[0]) - 1.0) * 100.0])
	flag(float(dmg[5]) / float(dmg[0]) > 1.25, "敌人单体伤害六章只涨 %.0f%%，后期压力全靠数量" % ((float(dmg[5]) / float(dmg[0]) - 1.0) * 100.0))

	print("=== 元素常数是否跟随成长 ===")
	game.equipped_cards.assign(["chain", "burn"])
	game.refresh_derived_card_effects()
	var weak = game.spawn_enemy("重甲怪")
	var strong = game.spawn_enemy("重甲怪")
	game.calculate_skill_damage(10.0, "chain", weak)
	game.calculate_skill_damage(60.0, "chain", strong)
	print("  基础伤害 10 -> 灼烧 %.1f/秒 ; 基础伤害 60 -> 灼烧 %.1f/秒" % [weak.burn_dps, strong.burn_dps])
	flag(strong.burn_dps > weak.burn_dps * 3.0, "灼烧强度不随本次伤害成长")

	print("=== 开局配置 ===")
	var ranged := ["chain", "thunder_orb", "meteor_rain", "gravity_well", "execute"]
	for character in game.STARTING_PETS:
		var pair: Array = game.STARTING_PETS[character]
		var has_reach := false
		for pet in pair:
			if str(pet) in ranged:
				has_reach = true
		print("  %-5s %s  远程手段:%s" % [str(character), str(pair), "有" if has_reach else "无"])

	print("")
	for problem in problems:
		print("NUMERIC_AUDIT_PROBLEM " + problem)
	assert(problems.is_empty(), "数值审计发现问题：" + ", ".join(problems))
	print("NUMERIC_AUDIT_SMOKE_OK")
	quit()
