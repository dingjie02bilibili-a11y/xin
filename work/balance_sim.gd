extends SceneTree
# 无窗口战斗模拟：用固定步长手动驱动真实的游戏逻辑，测量每章的难度压力。
# 工程里没有任何 CollisionShape，move_and_slide 等价于纯积分，所以手动步进
# 与实机一致，且不受实时帧率影响、可复现。
#
# 用法：godot --headless --path . --script work/balance_sim.gd -- <角色|all> [种子数] [模式] [战绩画像]
#   模式：留空=跑分；verbose=逐局明细；trace=把状态轨迹写到 work/sim_trace.txt；
#         selftest=同种子跑两遍比对轨迹的确定性门禁（跑 90 秒，输出 DETERMINISM_SMOKE_OK）
#
# 战绩画像（empty/weak/median/strong）决定本次跑分假设的「历史玩家」。难度一旦
# 开始读历史，不声明画像的跑分就没有意义——它会隐式依赖本机存档。现在难度还没
# 接历史，这个参数是惰性的，但从第一天就把它写进表头，避免以后拿旧数据对新数据。

const DT := 1.0 / 40.0
const RUN_SECONDS := 470.0
const CHAPTER_MARKS := [60.0, 120.0, 180.0, 240.0, 300.0, 470.0]
const HistoryFixtures = preload("res://work/history_fixtures.gd")
const ALL_CHARACTERS := ["游侠", "骑士", "星术师", "守卫", "影舞者", "星火使"]

var game
var save
var verbose := false
var history_profile := "median"
var bot_phase := 0.0
var boss_spawn_time := {}
var boss_ttk: Array[float] = []
var chapter_rows: Array[Dictionary] = []
var died_at := -1.0
var log_file: FileAccess
# 确定性轨迹：逐秒把关键状态写成一行，两次跑分 diff 一下就能定位首次分叉点。
var trace_file: FileAccess
var trace := false
var selftest := false
var trace_lines: Array[String] = []
var run_limit := RUN_SECONDS

func emit(line: String) -> void:
	print(line)
	if log_file == null:
		log_file = FileAccess.open("res://work/sim_out.txt", FileAccess.WRITE)
	if log_file:
		log_file.store_line(line)
		log_file.flush()

func _initialize() -> void:
	call_deferred("run_batch")

func arg(index: int, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	return str(args[index]) if index < args.size() else fallback

func run_batch() -> void:
	var who := arg(0, "游侠")
	var seed_count := int(arg(1, "3"))
	verbose = arg(2, "") == "verbose"
	trace = arg(2, "") == "trace"
	selftest = arg(2, "") == "selftest"
	if selftest:
		trace = true
		# 90 秒足以覆盖刷怪、第一次商店、第一个 Boss 和 Boss 奖励弹窗——
		# 已知的墙钟泄漏点全在这段里，再往后只是重复。
		run_limit = 90.0
	history_profile = arg(3, "median")
	var characters: Array = ALL_CHARACTERS if who == "all" else [who]

	var packed := load("res://scenes/main.tscn") as PackedScene
	game = packed.instantiate()
	root.add_child(game)
	await frame()
	game.test_mode = true
	save = root.get_node("SaveManager")
	emit("战绩画像：%s（每局开跑前重置存档，结论不受本机进度影响）" % history_profile)

	if selftest:
		await run_selftest(str(characters[0]))
		return
	emit("角色   存活  Boss 死亡 | 每章场均敌人        | 每章断链时长%       | 每章受伤            | 每章末HP%           | BossTTK             | 卡组/宠 星屑得/花/余")
	var grand: Array[Dictionary] = []
	for character in characters:
		var runs: Array[Dictionary] = []
		for index in seed_count:
			runs.append(await simulate_one(str(character), 1000 + index * 7717))
		grand.append(summarise(str(character), runs))
	emit("")
	verdict(grand)
	quit()

# ---------------------------------------------------------------- 单局模拟

# 每局开跑前把存档钉回已知状态：合成战绩 + 固定成就集 + 指定角色。
# 少了这一步，仿真会继承上一局写下的战绩，也会读到本机真实进度。
# 确定性门禁：同一角色、同一种子跑两遍，逐行比对状态轨迹。
# 这条一旦挂了，说明又有东西把墙钟（真实帧长 / 真实时刻）漏进了战斗逻辑，
# 此时任何平衡结论都不成立——先修复现性，再谈数值。
func run_selftest(character: String) -> void:
	await simulate_one(character, 1000)
	var first := trace_lines.duplicate()
	trace_lines.clear()
	await simulate_one(character, 1000)
	var second := trace_lines.duplicate()
	if first.is_empty():
		print("DETERMINISM_SMOKE_FAILED 没有采到任何轨迹")
		quit(1)
		return
	if first.size() != second.size():
		print("DETERMINISM_SMOKE_FAILED 轨迹长度不同 %d vs %d" % [first.size(), second.size()])
		quit(1)
		return
	for index in first.size():
		if first[index] != second[index]:
			print("DETERMINISM_SMOKE_FAILED 第 %d 行起分叉" % (index + 1))
			print("  A: %s" % first[index])
			print("  B: %s" % second[index])
			quit(1)
			return
	print("DETERMINISM_SMOKE_OK 同种子两遍共 %d 行轨迹逐行一致" % first.size())
	quit(0)

func reset_save(character: String) -> void:

	save.apply_test_fixture(HistoryFixtures.profile(history_profile, character))
	save.data.intro_seen = true
	save.data.achievements = ["boss_breaker", "survive_three", "combo_adept", "streak_master", "molten_master"]
	save.data.selected_character = character

func simulate_one(character: String, run_seed: int) -> Dictionary:
	seed(run_seed)
	bot_phase = 0.0
	boss_spawn_time.clear()
	boss_ttk.clear()
	chapter_rows.clear()
	died_at = -1.0

	reset_save(character)
	game.show_main_menu()
	await frame()
	game.start_game_after_prologue()
	# main 自己是 PROCESS_MODE_ALWAYS，停掉它也必须赶在第一个真实帧之前：晚一帧，
	# _process 就会按真实 delta 给 elapsed 加一笔随机头款，而敌人血量正比于 elapsed
	#（0.92 + elapsed / 520），于是同种子两次跑分的怪血从第一只就开始分叉。
	game.set_process(false)
	# 必须在这里冻结，不能等到 await 之后：start_game_after_prologue 是同步的，
	# 世界一建好就存在了，而 await 期间引擎会按真实 delta 推它若干个物理帧——
	# 推几帧取决于机器快慢。整局的初始状态因此每次都不一样，同种子也白搭。
	freeze_world()
	# 引擎不再驱动任何游戏节点，全部由本脚本按固定步长手动步进。
	# 帧仍然照常推进，用来刷新 queue_free / call_deferred。
	paused = true
	await frame()
	freeze_world()

	var elapsed := 0.0
	var chapter := 0
	var bucket := new_bucket(1, 0)
	var last_hands := 0
	var samples := 0
	var last_damage := 0.0
	var last_earned := 0
	var last_spent := 0

	while elapsed < run_limit:
		await frame()
		if game.state == game.GameState.GAME_OVER or not is_instance_valid(game.player):
			died_at = elapsed
			break
		if game.boss_kills >= 6:
			break
		if game.state == game.GameState.LEVEL_UP:
			await handle_modal()
			continue
		drive_bot()
		game._process(DT)
		step_world(DT)
		elapsed += DT
		track_bosses(elapsed)
		if trace:
			emit_trace(character, run_seed, elapsed)
		var alive := get_nodes_in_group("enemies").size()
		if int(game.pet_link_broken.size()) > 0:
			bucket.severed_frames += 1
		bucket.alive_sum += alive
		bucket.alive_max = maxi(int(bucket.alive_max), alive)
		samples += 1
		if chapter < CHAPTER_MARKS.size() and elapsed >= float(CHAPTER_MARKS[chapter]):
			close_bucket(bucket, samples, last_damage, last_earned, last_spent)
			bucket.hands = game.hands_played - last_hands
			last_hands = game.hands_played
			chapter_rows.append(bucket)
			last_damage = game.damage_taken_this_run
			last_earned = game.total_star_shards
			last_spent = game.spent_star_shards
			chapter += 1
			samples = 0
			bucket = new_bucket(chapter + 1, game.kills)
	if samples > 0:
		close_bucket(bucket, samples, last_damage, last_earned, last_spent)
		bucket.hands = game.hands_played - last_hands
		chapter_rows.append(bucket)

	var result := {
		"seconds": elapsed, "died": died_at >= 0.0 or game.boss_kills < 6, "boss_kills": game.boss_kills,
		"kills": game.kills, "earned": game.total_star_shards, "spent": game.spent_star_shards,
		"left": game.star_shards, "deck": game.equipped_cards.size(),
		"pets": game.equipped_pet_count(), "rows": chapter_rows.duplicate(true),
		"ttk": boss_ttk.duplicate()}
	if verbose:
		emit("   seed=%d %s %.0fs boss=%d deck=%s ttk=%s" % [run_seed, character, elapsed, game.boss_kills, str(game.equipped_cards), str(boss_ttk)])
	game.show_main_menu()
	await frame()
	return result

func emit_trace(character: String, run_seed: int, elapsed: float) -> void:
	# 开局 2 秒逐步长记录（初始化类的分叉都在这段），之后每秒一行。
	var fine := elapsed <= 2.0
	if not fine and absf(elapsed - roundf(elapsed)) > DT * 0.5:
		return
	var p = game.player
	var pet_hash := 0.0
	var pet_count := 0
	for id in game.skill_entities:
		var pet = game.skill_entities[id]
		if is_instance_valid(pet):
			pet_count += 1
			# life_time 必须进哈希：宠物多吃一个真实帧时位置偏移可能小到看不出来，
			# 但 life_time 会直接跳一整帧，是「墙钟又漏进来了」最灵敏的指示器。
			pet_hash += pet.global_position.x * 2.3 + pet.global_position.y * 5.7 + pet.life_time * 13.1
	var proj_count: int = game.projectile_root.get_child_count() if is_instance_valid(game.projectile_root) else -1
	var enemy_hash := 0.0
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			enemy_hash += e.global_position.x * 1.7 + e.global_position.y * 3.1 + e.health * 11.3
	var line := "%s/%d t=%8.4f kills=%4d hp=%8.3f alive=%3d shards=%5d hash=%14.3f px=%9.4f py=%9.4f pets=%d pethash=%14.4f proj=%3d pvx=%.9f pvy=%.9f" % [
		character, run_seed, elapsed, game.kills,
		(p.health if is_instance_valid(p) else -1.0),
		get_nodes_in_group("enemies").size(), game.total_star_shards, enemy_hash,
		(p.global_position.x if is_instance_valid(p) else 0.0),
		(p.global_position.y if is_instance_valid(p) else 0.0), pet_count, pet_hash, proj_count,
		(p.velocity.x if is_instance_valid(p) else 0.0), (p.velocity.y if is_instance_valid(p) else 0.0)]
	if selftest:
		trace_lines.append(line)
		return
	if trace_file == null:
		trace_file = FileAccess.open("res://work/sim_trace.txt", FileAccess.WRITE)
	if trace_file == null:
		return
	trace_file.store_line(line)
	trace_file.flush()

# main 在 _ready 里把自己设成 PROCESS_MODE_ALWAYS（为了让暂停菜单能动），子节点默认
# INHERIT，于是整棵战斗树都无视 get_tree().paused。这有两个后果：
#   1) 每个实体被「手动固定步长」和「引擎真实 delta」各推一次，等于双倍步进；
#   2) 推几次取决于机器快慢，同种子两次跑分能差出上百秒。
# 而且游戏自己会在开关商店时改写 get_tree().paused，光靠 paused 挡不住。
# 所以把战斗世界的几个根节点显式降回 PAUSABLE，让 paused 真正管得住它们，
# 全部由本脚本按固定步长推进。UI 弹窗自己声明了 ALWAYS，不受影响。
# 注意不能用 DISABLED：那会把物理体从物理空间里摘掉，move_and_slide 变成空转，
# 手动步进也推不动任何东西（实测整局站桩、零击杀）。
# 每推进一个真实帧，都必须把暂停压回去。游戏自己会在关闭商店/奖励弹窗时把
# get_tree().paused 改回 false（真机上这是对的），而仿真里只要漏掉一帧，
# 引擎就会按真实帧长把整个世界推一把：实测宠物的 life_time 在一步里跳了
# 0.083 秒而不是 0.025 秒，同种子两次跑分从那一刻起彻底分叉。
func frame() -> void:
	# 压回暂停必须在 await 之前：按钮回调（比如关掉奖励弹窗）会把 paused 改成 false，
	# 如果只在 await 之后补，那一帧已经按真实帧长跑掉了，补也来不及。
	paused = true
	await process_frame
	paused = true

func freeze_world() -> void:
	for holder in [game.entity_root, game.projectile_root, game.visual_root,
			game.hazard_root, game.pickup_root, game.player]:
		if is_instance_valid(holder):
			holder.process_mode = Node.PROCESS_MODE_PAUSABLE

func new_bucket(index: int, kills_so_far: int) -> Dictionary:

	return {"chapter": index, "kills": kills_so_far, "alive_sum": 0.0, "alive_avg": 0.0,
		"alive_max": 0, "damage": 0.0, "earned": 0, "spent": 0, "hp_pct": 0.0, "deck": 0, "hands": 0, "severed_frames": 0, "severed_pct": 0.0}

func close_bucket(bucket: Dictionary, samples: int, last_damage: float, last_earned: int, last_spent: int) -> void:
	bucket.alive_avg = bucket.alive_sum / maxf(1.0, float(samples))
	bucket.severed_pct = float(bucket.severed_frames) / maxf(1.0, float(samples)) * 100.0
	bucket.kills = game.kills - int(bucket.kills)
	bucket.damage = game.damage_taken_this_run - last_damage
	bucket.earned = game.total_star_shards - last_earned
	bucket.spent = game.spent_star_shards - last_spent
	bucket.hp_pct = (game.player.health / game.player.max_health * 100.0) if is_instance_valid(game.player) else 0.0
	bucket.deck = game.equipped_cards.size()

# ---------------------------------------------------------------- 世界步进

func step_world(dt: float) -> void:
	var p = game.player
	if is_instance_valid(p):
		p._physics_process(dt)
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e._physics_process(dt)
	for holder in [game.projectile_root, game.visual_root, game.hazard_root, game.pickup_root]:
		if not is_instance_valid(holder):
			continue
		for node in holder.get_children():
			if not is_instance_valid(node):
				continue
			if node.has_method("_physics_process"):
				node._physics_process(dt)
			elif node.has_method("_process"):
				node._process(dt)

# ---------------------------------------------------------------- 走位 bot

func pet_engage_radius(id: String) -> float:
	match id:
		"aura": return game.aura_radius * game.skill_area_multiplier(id)
		"orbit", "satellite_engine", "blade_dance": return 200.0
		"nova": return (115.0 + game.nova_level * 18.0) * game.skill_area_multiplier(id)
		"phase_step": return 400.0
		"execute": return 600.0
		"chain": return 700.0
		"gravity_well": return 720.0
		"thunder_orb": return 860.0
		"meteor_rain": return 900.0
		"aegis": return 300.0
	return 320.0

func drive_bot() -> void:
	var p = game.player
	if not is_instance_valid(p):
		return
	bot_phase += DT
	var here: Vector2 = p.global_position
	# 玩家 260 移速能永远甩掉 105 的追猎者，所以「无脑风筝」会让近战型宠物一次都打不中。
	# 真实玩家按自己宠物的射程控距：够不着就主动贴上去，贴太近才拉开。
	var engage := 180.0
	for id in game.active_core_skill_ids():
		engage = maxf(engage, pet_engage_radius(str(id)))
	engage = clampf(engage * 0.80, 150.0, 420.0)

	var nearest := 1e9
	var pack := Vector2.ZERO
	var pack_count := 0
	var flee := Vector2.ZERO
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: Vector2 = here - e.global_position
		var l := d.length()
		nearest = minf(nearest, l)
		if l < 700.0:
			pack += e.global_position
			pack_count += 1
		if l < 110.0 and l > 1.0:
			flee += d.normalized() * (110.0 - l) / 110.0

	# 预警圈是明示信息，正常玩家会走出去；不躲的话测的是站桩挨打而不是难度。
	var escape := Vector2.ZERO
	if is_instance_valid(game.hazard_root):
		for hazard in game.hazard_root.get_children():
			if not is_instance_valid(hazard):
				continue
			var d: Vector2 = here - hazard.global_position
			var reach: float = float(hazard.radius) + 55.0
			var l := d.length()
			if l <= 1.0:
				escape += Vector2.RIGHT.rotated(bot_phase * 3.0) * 3.0
			elif l < reach:
				escape += d.normalized() * (reach - l) / reach * 3.0
	# Boss 冲锋是有前摇的直线攻击，正解是侧身让位而不是直线后撤。
	for boss in get_nodes_in_group("bosses"):
		if not is_instance_valid(boss) or float(boss.dash_time) <= 0.0:
			continue
		var to_me: Vector2 = here - boss.global_position
		if to_me.length() < 380.0 and to_me.length() > 1.0 and Vector2(boss.dash_direction).dot(to_me.normalized()) > 0.35:
			var side: Vector2 = Vector2(boss.dash_direction).rotated(PI * 0.5)
			escape += (side if side.dot(to_me) > 0.0 else -side) * 2.5
	if is_instance_valid(game.projectile_root):
		for shot in game.projectile_root.get_children():
			if not is_instance_valid(shot) or not shot.get("enemy_shot"):
				continue
			var d: Vector2 = here - shot.global_position
			if d.length() < 110.0 and d.length() > 1.0:
				escape += d.normalized() * 1.2

	# 断链的宠物必须去接：不接的话测的是「玩家完全不管链条」的下限，没有参考价值。
	var severed_pet: Vector2 = Vector2.ZERO
	var severed_far := 1e9
	for id in game.active_core_skill_ids():
		if bool(game.pet_link_connected(str(id))):
			continue
		var entity = game.skill_entities.get(str(id))
		if not is_instance_valid(entity):
			continue
		var gap: float = here.distance_to(entity.global_position)
		if gap < severed_far:
			severed_far = gap
			severed_pet = entity.global_position

	var dir: Vector2
	if severed_pet != Vector2.ZERO and escape.length() <= 0.05:
		# 危险预警优先于捡宠物，其余情况一律先把伙伴接回来
		dir = (severed_pet - here).normalized()
	elif escape.length() > 0.05:
		dir = escape.normalized()
	elif flee.length() > 0.05:
		# 贴脸了：后撤 + 侧移脱离
		var away := flee.normalized()
		dir = (away * 0.75 + away.rotated(PI * 0.5) * 0.65).normalized()
	elif pack_count > 0 and nearest > engage:
		# 够不着：主动接近怪群，同时保持侧向绕行不要撞进去
		var toward: Vector2 = ((pack / float(pack_count)) - here).normalized()
		dir = (toward * 0.85 + toward.rotated(PI * 0.5) * 0.5).normalized()
	elif pack_count > 0:
		# 舒适圈：绕着打
		var toward2: Vector2 = ((pack / float(pack_count)) - here).normalized()
		dir = toward2.rotated(PI * 0.5)
	else:
		dir = Vector2.RIGHT.rotated(bot_phase * 0.6)
	set_axis("move_right", "move_left", dir.x)
	set_axis("move_down", "move_up", dir.y)

func set_axis(positive: String, negative: String, value: float) -> void:
	if value >= 0.0:
		Input.action_release(negative)
		Input.action_press(positive, absf(value))
	else:
		Input.action_release(positive)
		Input.action_press(negative, absf(value))

# ---------------------------------------------------------------- 弹窗处理

func handle_modal() -> void:
	if is_instance_valid(game.booster_overlay):
		press_first_button(game.booster_overlay)
		await frame()
		return
	if is_instance_valid(game.card_replace_overlay):
		resolve_replacement()
		await frame()
		return
	if is_instance_valid(game.shop_overlay):
		await do_shopping()
		return
	if is_instance_valid(game.boss_reward_overlay):
		press_first_button(game.boss_reward_overlay)
		await frame()
		return
	if is_instance_valid(game.mainline_complete_overlay):
		press_first_button(game.mainline_complete_overlay)
		await frame()
		return
	game.state = game.GameState.PLAYING
	await frame()

func press_first_button(node: Node) -> bool:
	for child in node.get_children():
		if child is Button and not child.disabled:
			child.pressed.emit()
			return true
		if press_first_button(child):
			return true
	return false

func offer_score(offer: Dictionary) -> float:
	var kind := str(offer.get("kind", "card"))
	var id := str(offer.get("id", ""))
	match kind:
		"card":
			if id in game.CORE_SKILL_CARD_IDS:
				return 100.0 - float(game.equipped_pet_count()) * 9.0
			if game.is_training_card(id):
				return 46.0
			return 58.0
		"endless": return 55.0
		"edition": return 52.0
		"pack": return 50.0
		"seal": return 30.0
		"pattern": return 30.0
		"voucher": return 34.0
		"sigil": return 20.0
		"forge": return 45.0
		"heal": return 90.0 if game.player.health < game.player.max_health * 0.6 else 4.0
		"supply": return 6.0
	return 15.0

func do_shopping() -> void:
	var wallet_before: int = game.star_shards
	var listing: Array[String] = []
	for offer in game.shop_goods:
		listing.append("%s:%s(%d)" % [str(offer.get("kind", "card")), str(offer.get("id", "")), int(offer.price)])
	var bought: Array[String] = []
	var guard := 0
	while guard < 40 and is_instance_valid(game.shop_overlay):
		guard += 1
		var best := -1
		var best_score := 0.0
		for i in game.shop_goods.size():
			var offer: Dictionary = game.shop_goods[i]
			if bool(offer.get("sold", false)) or int(offer.price) > game.star_shards:
				continue
			var score := offer_score(offer)
			if score > best_score:
				best_score = score
				best = i
		if best < 0:
			break
		bought.append(str(game.shop_goods[best].get("id", "")))
		game.purchase_shop_offer(best)
		await frame()
		if is_instance_valid(game.card_replace_overlay):
			resolve_replacement()
			await frame()
		if is_instance_valid(game.booster_overlay):
			press_first_button(game.booster_overlay)
			await frame()
			if is_instance_valid(game.card_replace_overlay):
				resolve_replacement()
				await frame()
	if is_instance_valid(game.shop_overlay):
		game.close_shop()
	if verbose:
		print("     [店%d] %d->%d 货架%s 买%s 卡组%s" % [int(game.shop_visit), wallet_before, int(game.star_shards), str(listing), str(bought), str(game.equipped_cards)])
	paused = true
	await frame()

func resolve_replacement() -> void:
	var incoming := ""
	var price := int(game.pending_shop_price)
	var index := int(game.pending_shop_offer)
	if index >= 0 and index < game.shop_goods.size():
		incoming = str(game.shop_goods[index].get("id", ""))
	var victim := ""
	for id in game.equipped_cards:
		var card_id := str(id)
		if card_id in game.CORE_SKILL_CARD_IDS or str(game.card_drawbacks.get(card_id, "")) == "eternal":
			continue
		if card_id == "card_slot" and game.equipped_cards.size() > game.STARTING_CARD_SLOTS:
			continue
		if game.spendable_after_shard_income(game.card_sell_value(card_id)) >= price:
			victim = card_id
			break
	if victim.is_empty() or incoming.is_empty():
		game.cancel_shop_replacement()
		return
	game.confirm_shop_replacement(victim, incoming, price, index)

# ---------------------------------------------------------------- Boss 计时

func track_bosses(now: float) -> void:
	var seen := {}
	for boss in get_nodes_in_group("bosses"):
		if not is_instance_valid(boss):
			continue
		var key := boss.get_instance_id()
		seen[key] = true
		if not boss_spawn_time.has(key):
			boss_spawn_time[key] = now
	for key in boss_spawn_time.keys():
		if not seen.has(key):
			boss_ttk.append(now - float(boss_spawn_time[key]))
			boss_spawn_time.erase(key)

# ---------------------------------------------------------------- 汇总

func avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / float(values.size())

func col(runs: Array, key: String) -> Array:
	var out := []
	for chapter in 6:
		var picks := []
		for run in runs:
			var rows: Array = run.rows
			if chapter < rows.size():
				picks.append(float(rows[chapter][key]))
		out.append(avg(picks))
	return out

func fmt(values: Array, pattern := "%3.0f") -> String:
	var parts: Array[String] = []
	for v in values:
		parts.append(pattern % float(v))
	return " ".join(parts)

func summarise(character: String, runs: Array) -> Dictionary:
	var deaths := 0
	var seconds := []
	var bosses := []
	for run in runs:
		if bool(run.died):
			deaths += 1
		seconds.append(float(run.seconds))
		bosses.append(float(run.boss_kills))
	var ttk_by_index := []
	for i in 6:
		var picks := []
		for run in runs:
			var list: Array = run.ttk
			if i < list.size():
				picks.append(float(list[i]))
		ttk_by_index.append(avg(picks))
	var summary := {
		"character": character, "deaths": deaths, "runs": runs.size(),
		"seconds": avg(seconds), "bosses": avg(bosses),
		"alive": col(runs, "alive_avg"), "damage": col(runs, "damage"),
		"hp": col(runs, "hp_pct"), "ttk": ttk_by_index, "hands": col(runs, "hands"), "severed": col(runs, "severed_pct"),
		"deck": avg(runs.map(func(r): return float(r.deck))),
		"pets": avg(runs.map(func(r): return float(r.pets))),
		"earned": avg(runs.map(func(r): return float(r.earned))),
		"spent": avg(runs.map(func(r): return float(r.spent))),
		"left": avg(runs.map(func(r): return float(r.left)))}
	emit("%-5s %4.0fs %4.1f  %d/%d | %s | %s | %s | %s | %s | %.1f/%.1f %.0f/%.0f/%.0f" % [
		character, summary.seconds, summary.bosses, deaths, runs.size(),
		fmt(summary.alive, "%4.1f"), fmt(summary.severed), fmt(summary.damage), fmt(summary.hp), fmt(summary.ttk),
		summary.deck, summary.pets, summary.earned, summary.spent, summary.left])
	return summary

func ttk_in_band(values: Array) -> bool:
	# 单调递增不是真正的设计要求，而且构筑强度的方差比章节趋势还大。
	# 真正要保证的是：每一关的 Boss 都打得像一场对峙——不是 3 秒融化，也不是耗着不死。
	var seen := 0
	for v in values:
		var value := float(v)
		if value <= 0.0:
			continue
		seen += 1
		if value < 8.0 or value > 45.0:
			return false
	return seen >= 3

func rising(values: Array) -> bool:
	# 逐章严格单调过于苛刻：玩家战力增长本来就会让某一章的场面暂时变干净。
	# 真正要看的是后半程压力显著高于前半程。
	var early := 0.0
	var early_n := 0
	var late := 0.0
	var late_n := 0
	for i in values.size():
		var v := float(values[i])
		if v <= 0.0:
			continue
		if i < 3:
			early += v
			early_n += 1
		else:
			late += v
			late_n += 1
	if early_n == 0 or late_n == 0:
		return false
	return (late / float(late_n)) > (early / float(early_n)) * 1.15

func verdict(all: Array) -> void:
	emit("—— 心流判定 ——")
	var clear_rate := 0.0
	var spread_low := 1e9
	var spread_high := 0.0
	for row in all:
		clear_rate += float(row.runs - row.deaths) / float(row.runs)
		spread_low = minf(spread_low, float(row.seconds))
		spread_high = maxf(spread_high, float(row.seconds))
		# 「后期有压」不能用敌人数量衡量：玩家变强本来就该把场面清干净，
		# 真正的压力是掉血。用后半程受伤总量与前半程比较。
		var early_damage: float = float(row.damage[0]) + float(row.damage[1]) + float(row.damage[2])
		var late_damage: float = float(row.damage[3]) + float(row.damage[4]) + float(row.damage[5])
		emit("%-5s 通关%s | 压力递增:%s | BossTTK在带内:%s | 开局可控:%s | 后期有压:%s | 通胀×%.1f" % [
			row.character, "√" if row.deaths == 0 else "%d/%d" % [row.runs - row.deaths, row.runs],
			# 压力可以体现为「场面更挤」或「掉血更多」，构筑清得干净时只会走后一条。
			"√" if (rising(row.alive) or rising(row.damage)) else "×",
			"√" if ttk_in_band(row.ttk) else "×",
			# 开局要的是「不失控」，不是绝对数量少：能稳住就行。
			"√" if (float(row.alive[0]) <= 12.0 and float(row.alive[2]) <= float(row.alive[0]) * 2.2) else "×",
			"√" if late_damage > maxf(1.0, early_damage) else "×",
			float(row.earned) / maxf(1.0, float(row.spent))])
	emit("整体通关率 %.0f%% | 角色间存活差 %.0fs" % [clear_rate / float(all.size()) * 100.0, spread_high - spread_low])
