extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const WeaponVisualScript = preload("res://scripts/weapon_visual.gd")
const HitEffectScript = preload("res://scripts/hit_effect.gd")
const BossHazardScript = preload("res://scripts/boss_hazard.gd")
const DeckCardViewScript = preload("res://scripts/deck_card_view.gd")
const SkillEffectScript = preload("res://scripts/skill_effect.gd")
const SkillEntityScript = preload("res://scripts/skill_entity.gd")
const PetTetherViewScript = preload("res://scripts/pet_tether_view.gd")
const StoryArchiveData = preload("res://scripts/story_archive.gd")

enum GameState { MENU, PLAYING, LEVEL_UP, PAUSED, GAME_OVER }

const WORLD_DRAW_RADIUS := Vector2(1900, 1300)
const MAINLINE_BOSS_SCHEDULE := [60, 120, 180, 240, 300, 355]
# 逐章显式指定，保证 Boss 血量曲线单调递增（每章约 +33%）
const MAINLINE_BOSS_HEALTH := [560.0, 830.0, 1180.0, 1620.0, 2140.0, 2760.0]
const ENDLESS_WAVE_DURATION := 45.0
const FIRST_SHOP_TIME := 38.0
const SHOP_INTERVAL := 60.0
const SHOP_ITEM_COUNT := 3
const STARTING_CARD_SLOTS := 5
const MAX_CARD_SLOTS := 7
const MAX_RESONANCE := 100.0
# 单次释放只抽取固定额度，多宠构筑不再互相抽干共鸣池
const RESONANCE_SPEND := 30.0
const PHASE_STEP_COOLDOWN := 0.75
const PHASE_STEP_INVULNERABILITY := 0.28
const MAX_CLEANSE_WARD_CHARGES := 2
# 一局 6 分钟、满血 100，而过去除了商店随机出现的战地修复之外没有任何续航，
# 损血是永久的：打完第一只 Boss 掉一半血就再也回不来，整局退化成一次性淘汰赛。
# 脱战微量回复负责抹平小怪的擦伤，击败 Boss 的大额回复负责制造「紧张—释放」的关卡节奏。
const OUT_OF_COMBAT_REGEN := 0.010
const OUT_OF_COMBAT_DELAY := 4.0
const BOSS_CLEAR_HEAL := 0.75
const BOSS_CLEAR_MAX_HEALTH := 18.0
const BOSS_CLEAR_ARMOR := 1.0
const BOSS_SHOP_LOCK_LIMIT := 30.0
# 视口 1280x720、相机 zoom 1，所以从玩家出发竖直方向只能看到 360——这是紧的那一轴。
# 过去坠火索敌 950、鸣霄 900，宠物在打玩家根本看不见的东西。所有索敌在这里统一夹紧，
# 任何新技能都不可能再飘出屏幕。
const MAX_ENGAGE_RANGE := 360.0
const PET_DAMAGE_SCALE := 1.18
# 供能链条：玩家与每只宠物之间是一条持续的能量通道，能量沿它连续流入。
# 敌人挤到玩家和宠物中间会把链条切断，宠物随即停摆，必须走过去重新接上。
const TETHER_CUT_COOLDOWN := 3.0
const TETHER_RECONNECT_GRACE := 1.5
const TETHER_RECONNECT_RANGE := 44.0
const TETHER_DRIFT_SPEED := 46.0
const TETHER_SNAP_RECOIL := 165.0
const ELITE_CUTTER_KINDS := ["重甲怪", "咒术师"]
const TRAINING_CARD_IDS := ["damage", "cooldown", "speed", "health", "armor", "regen", "crit", "magnet"]
const PET_ENERGY_REQUIREMENTS := {
	"aura":0.9, "orbit":1.1, "satellite_engine":1.1, "chain":2.0,
	"nova":3.0, "phase_step":2.2, "thunder_orb":2.8, "gravity_well":2.2,
	"blade_dance":1.6, "meteor_rain":4.0, "aegis":3.0, "execute":2.5
}
const CHARACTER_UNLOCK_ACHIEVEMENTS := {
	"游侠": "",
	"骑士": "boss_breaker",
	"守卫": "survive_three",
	"星术师": "combo_adept",
	"影舞者": "streak_master",
	"星火使": "molten_master"
}
const CORE_SKILL_CARD_IDS := [
	"aura", "orbit", "satellite_engine", "chain", "nova", "phase_step", "thunder_orb",
	"gravity_well", "blade_dance", "meteor_rain", "aegis", "execute"
]
# 卡组只有 5~7 格，钱很快就没处花（实测一局赚 554 只花得掉 32）。
# 星屑熔炉是不占卡槽、可反复购买、直接转成战力的沉淀口，价格随次数递增。
const FORGE_BASE_PRICE := 9
const FORGE_STEP_PRICE := 3
const FORGE_ENERGY_GAIN := 0.03
const FORGE_ENERGY_CAP := 2.40
const STARTING_PETS := {
	"游侠": ["chain", "aura"],
	"骑士": ["aura", "aegis"],
	"星术师": ["aura", "thunder_orb"],
	"守卫": ["orbit", "gravity_well"],
	"影舞者": ["blade_dance", "phase_step"],
	"星火使": ["aura", "meteor_rain"]
}
const CORE_MASTERY_MAX_RANK := 5
const CORE_MASTERY_RULES := {
	"aura": {"condition":"单次光环命中至少4名敌人", "base":3, "gap":1.2, "bonus":"每阶伤害+8%、范围+4%"},
	"orbit": {"condition":"单次轨道扫描命中至少3名敌人", "base":4, "gap":2.0, "bonus":"每阶伤害+8%；第3、5阶各增加1枚卫星"},
	"satellite_engine": {"condition":"单次蜂巢扫描命中至少2名敌人", "base":4, "gap":2.0, "bonus":"每阶伤害+8%；第2、4阶各增加1枚卫星"},
	"chain": {"condition":"一次磁暴电弧命中至少3个目标", "base":3, "gap":1.0, "bonus":"每阶伤害+8%；第2、4阶各增加1次跳跃"},
	"nova": {"condition":"一次星核爆破命中至少4名敌人", "base":3, "gap":1.0, "bonus":"每阶伤害+8%、范围+4%"},
	"phase_step": {"condition":"一次相位突进穿过至少2名敌人", "base":2, "gap":0.2, "bonus":"每阶伤害+8%、所需能量降低0.1"},
	"thunder_orb": {"condition":"一次雷暴命中Boss、精英或至少3名敌人", "base":3, "gap":1.0, "bonus":"每阶伤害+8%、范围+4%"},
	"gravity_well": {"condition":"一次引力奇点牵引至少5名敌人", "base":3, "gap":1.0, "bonus":"每阶伤害+8%、范围+5%、牵引力+10%"},
	"blade_dance": {"condition":"单次星刃回环命中至少3名敌人", "base":4, "gap":1.6, "bonus":"每阶伤害+8%、回环半径+3"},
	"meteor_rain": {"condition":"一次陨星坠落命中至少4名敌人", "base":3, "gap":1.0, "bonus":"每阶伤害+8%、范围+4%"},
	"aegis": {"condition":"星辉壁垒成功抵消一次伤害", "base":2, "gap":0.1, "bonus":"每阶所需能量降低0.2；第5阶额外获得1层护盾"},
	"execute": {"condition":"断罪成功处决一名敌人", "base":3, "gap":0.45, "bonus":"每阶处决线+1.5%、伤害+8%"}
}
const ENDLESS_CARD_IDS := ["endless_damage", "endless_vitality", "endless_haste"]
const CARD_EDITIONS := [
	{"id":"foil", "name":"闪箔", "desc":"该技能的伤害与状态强度提高15%"},
	{"id":"holographic", "name":"镭射", "desc":"该技能暴击时额外提高25%伤害"},
	{"id":"polychrome", "name":"多彩", "desc":"该技能最终伤害乘以1.20"},
	{"id":"echo", "name":"回响", "desc":"技能释放后延迟0.28秒，在目标处复制一次55%威力的攻击波"}
]
const EXPEDITION_VOUCHERS := [
	{"id":"wide_shelf", "name":"扩建货架", "desc":"每家商店额外展示1件商品", "price":12},
	{"id":"free_reroll", "name":"批量采购", "desc":"每家商店第一次刷新免费", "price":9},
	{"id":"salvage_license", "name":"星屑回收", "desc":"卡牌出售返还由50%提高到65%", "price":9},
	{"id":"pet_insurance", "name":"宠物保险", "desc":"首次出售宠物时保留一半条件养成进度", "price":11},
	{"id":"edition_license", "name":"版本许可", "desc":"版本改造商品价格降低2星屑", "price":9},
	{"id":"rare_license", "name":"稀有许可", "desc":"史诗与传奇商品出现概率提高", "price":12},
	{"id":"deep_freight", "name":"深层货运", "desc":"每家商店保证出现一个补充包", "price":10},
	{"id":"counter_license", "name":"破咒执照", "desc":"Boss出现时有35%概率少获得一个词条", "price":12}
]
const STAR_SIGILS := [
	{"id":"swap", "name":"换位符", "desc":"交换卡组最左与最右卡牌"},
	{"id":"polish", "name":"抛光符", "desc":"随机一只宠物获得闪箔或镭射版本"},
	{"id":"melt", "name":"熔解符", "desc":"出售最右侧可出售的非宠物牌并获得双倍回收价"},
	{"id":"cleanse", "name":"净化符", "desc":"部署一次净化屏障，抵消下一次Boss卡牌干扰"},
	{"id":"sacrifice", "name":"献祭符", "desc":"最大生命-15，随机一只宠物立刻提升1星"},
	{"id":"bridge", "name":"星桥符", "desc":"接下来3次宠物技能结算视为激活双核式"},
	{"id":"fortune", "name":"守财符", "desc":"立即获得当前星屑20%的利息，最多8"},
	{"id":"reforge", "name":"重铸符", "desc":"免费刷新当前商店商品"}
]
const CARD_SEALS := [
	{"id":"red", "name":"红蜡封", "desc":"该宠物每第5次技能结算使本次伤害规则额外强化20%"},
	{"id":"blue", "name":"蓝蜡封", "desc":"击败Boss后使关联星式获得1次研究"},
	{"id":"gold", "name":"金蜡封", "desc":"完成该卡条件养成时获得2星屑"},
	{"id":"white", "name":"白蜡封", "desc":"从Boss干扰恢复时获得20共鸣"}
]
const CARD_RARITY_COLORS := {
	"普通": Color("9bb4d1"), "稀有": Color("70d7ff"),
	"史诗": Color("c084fc"), "传奇": Color("facc15"), "专属": Color("fb7185")
}
const DECK_COMBOS := [
	{"name":"熔雷回路", "cards":["burn", "chain"]},
	{"name":"星环矩阵", "cards":["aura", "orbit"]},
	{"name":"极寒天火", "cards":["frost_brand", "meteor_rain"]},
	{"name":"坍缩爆心", "cards":["gravity_well", "nova"]},
	{"name":"瞬身刃舞", "cards":["phase_step", "blade_dance"]},
	{"name":"风暴导体", "cards":["thunder_orb", "chain"]}
]
const BOSS_AFFIXES := [
	{"id":"rapid_pattern", "name":"急袭脉冲", "desc":"特殊行动更频繁、更具压迫感"},
	{"id":"riftfield", "name":"裂隙蔓延", "desc":"周期生成可预警的小型陷阱"},
	{"id":"exposed_core", "name":"暴露核心", "desc":"特殊行动频率+14%；行动后暴露2.2秒，受到伤害+75%"},
	{"id":"prism_shield", "name":"棱镜屏障", "desc":"蓝盾期间供能弹仅提供50%能量；等待蓝盾结束可完整供能"},
	{"id":"sealed_hand", "name":"封印契约", "desc":"周期封印一张非关键卡4.2秒；击败5名敌人可提前解除，结束后自动归还"},
	{"id":"pet_thief", "name":"星渊窃宠", "desc":"周期偷走一只宠物5.2秒；靠近Boss身边的宠物可提前夺回，且不会夺走最后战力"},
	{"id":"pet_charm", "name":"倒戈魅惑", "desc":"周期魅惑一只宠物4.5秒；靠近宠物可净化，且不会魅惑最后战力"},
	{"id":"reverse_shuffle", "name":"逆序洗牌", "desc":"周期将卡牌结算顺序反转5.5秒；结束后完整恢复原顺序"}
]
const ACHIEVEMENTS := [
	{"id":"first_expedition", "name":"启程", "desc":"完成任意一次远征", "source":"结算一局游戏"},
	{"id":"first_blood", "name":"第一滴星血", "desc":"在一局中击败第一个敌人", "source":"单局击败1名敌人"},
	{"id":"fifty_fallen", "name":"清扫者", "desc":"在一局中击败50名敌人", "source":"单局击败50名敌人"},
	{"id":"hundred_fallen", "name":"百敌斩", "desc":"在一局中击败100名敌人", "source":"单局击败100名敌人"},
	{"id":"swarm_breaker", "name":"星潮粉碎者", "desc":"在一局中击败250名敌人", "source":"单局击败250名敌人"},
	{"id":"level_five", "name":"第一桶星屑", "desc":"单局累计收集20星屑", "source":"累计获得20星屑"},
	{"id":"level_ten", "name":"构筑资金", "desc":"单局累计收集50星屑", "source":"累计获得50星屑"},
	{"id":"level_twenty", "name":"星屑商人", "desc":"单局累计收集120星屑", "source":"累计获得120星屑"},
	{"id":"level_thirty", "name":"星渊财库", "desc":"单局累计收集250星屑", "source":"累计获得250星屑"},
	{"id":"survive_minute", "name":"站稳脚跟", "desc":"生存1分钟", "source":"单局生存01:00"},
	{"id":"survive_three", "name":"潮中砥柱", "desc":"生存3分钟，并解锁守卫", "source":"单局生存03:00"},
	{"id":"survive_six", "name":"六分钟防线", "desc":"生存6分钟", "source":"单局生存06:00"},
	{"id":"untouchable_minute", "name":"无伤序曲", "desc":"开局1分钟内不受伤", "source":"前01:00保持零受伤"},
	{"id":"boss_breaker", "name":"首领终结者", "desc":"击败第一名Boss，并解锁骑士", "source":"单局首次击败Boss"},
	{"id":"chaser_breaker", "name":"找回路线", "desc":"帮助赫巡摆脱故障指令", "source":"击败追击型Boss"},
	{"id":"warden_breaker", "name":"打开城门", "desc":"帮助弥垣关闭失控陷阱", "source":"击败控场型Boss"},
	{"id":"judge_breaker", "name":"新的答案", "desc":"提醒零号灯塔的真正任务", "source":"击败爆发型Boss"},
	{"id":"boss_trio", "name":"三重破局", "desc":"在一局中击败3名Boss", "source":"单局Boss击败数达到3"},
	{"id":"fourth_seal", "name":"第十三号路线", "desc":"让赫巡想起岚和新路线", "source":"单局击败4名Boss"},
	{"id":"fifth_seal", "name":"有出口的新城", "desc":"帮助弥垣打开城市大门", "source":"单局击败5名Boss"},
	{"id":"six_seals", "name":"灯塔重亮", "desc":"完成六关主线并修好灯塔", "source":"单局击败6名主线Boss"},
	{"id":"flawless_boss", "name":"完美猎杀", "desc":"无伤击败一名Boss", "source":"Boss战期间不受伤"},
	{"id":"last_stand_boss", "name":"绝境反杀", "desc":"低生命击败Boss", "source":"生命低于25%时击败Boss"},
	{"id":"healthy_boss", "name":"毫发无损", "desc":"高生命击败Boss", "source":"生命高于95%时击败Boss"},
	{"id":"first_relic", "name":"遗物持有者", "desc":"获得第一件Boss遗物", "source":"单局获得1件遗物"},
	{"id":"relic_trinity", "name":"三圣遗珍", "desc":"在一局中持有3件Boss遗物", "source":"单局持有3件遗物"},
	{"id":"relic_master", "name":"遗物博物馆", "desc":"在一局中集齐6种Boss遗物", "source":"单局持有6种遗物"},
	{"id":"endless_walker", "name":"无尽行者", "desc":"踏入无尽挑战", "source":"完成主线第六关"},
	{"id":"endless_three", "name":"无尽初潮", "desc":"抵达无尽第3波", "source":"无尽模式第3波"},
	{"id":"endless_six", "name":"循环适应", "desc":"抵达无尽第6波", "source":"无尽模式第6波"},
	{"id":"endless_nine", "name":"九重星潮", "desc":"抵达无尽第9波", "source":"无尽模式第9波"},
	{"id":"endless_twelve", "name":"漫长守夜", "desc":"抵达无尽第12波", "source":"无尽模式第12波"},
	{"id":"endless_fifteen", "name":"深渊常客", "desc":"抵达无尽第15波", "source":"无尽模式第15波"},
	{"id":"endless_twenty", "name":"没有终点", "desc":"抵达无尽第20波", "source":"无尽模式第20波"},
	{"id":"combo_adept", "name":"共鸣学徒", "desc":"解锁任意武器进化，并解锁星术师", "source":"完成进化条件"},
	{"id":"molten_master", "name":"熔雷掌控者", "desc":"进化熔雷回路，并解锁星火使", "source":"余烬弹头 + 磁暴线圈"},
	{"id":"stellar_master", "name":"星环编织者", "desc":"进化星环矩阵", "source":"虚空光环 + 卫星系宠物"},
	{"id":"combo_duet", "name":"双重共鸣", "desc":"同时激活2组卡牌联动", "source":"单局联动数达到2"},
	{"id":"combo_quartet", "name":"组合大师", "desc":"同时激活4组卡牌联动", "source":"单局联动数达到4"},
	{"id":"elemental_trinity", "name":"元素三相", "desc":"同时装配火、冰、雷卡牌", "source":"灼烧、寒霜、雷暴同时生效"},
	{"id":"deck_full", "name":"满手好牌", "desc":"装满当前全部卡牌槽", "source":"至少5格且无空槽"},
	{"id":"slot_six", "name":"额外口袋", "desc":"把卡牌槽扩展到6格", "source":"获得扩展卡匣"},
	{"id":"slot_seven", "name":"七格卡匣", "desc":"把卡牌槽扩展到上限", "source":"卡牌槽达到7格"},
	{"id":"deck_curator", "name":"卡组整理师", "desc":"完成第一次卡牌替换", "source":"满槽时换下一张卡牌"},
	{"id":"shop_first", "name":"第一笔交易", "desc":"在星屑商店购买一件商品", "source":"完成一次商店购买"},
	{"id":"shop_reroll", "name":"货架重排", "desc":"刷新一次商店", "source":"支付星屑刷新商品"},
	{"id":"shop_sale", "name":"断舍离", "desc":"出售一张卡牌", "source":"在商店出售卡牌"},
	{"id":"shop_spree", "name":"星屑采购员", "desc":"单局累计消费30星屑", "source":"单局商店消费达到30星屑"},
	{"id":"engine_master", "name":"引擎全开", "desc":"装备星律引擎，并拥有2只异版宠物", "source":"星律引擎生效时让2只宠物获得特殊版本"},
	{"id":"catalyst_master", "name":"催化完成", "desc":"组合催化器同时增幅两组联动", "source":"持有催化器并激活2组联动"},
	{"id":"core_max", "name":"异版王牌", "desc":"让任意宠物获得特殊版本", "source":"宠物获得闪箔、镭射、多彩或回响版本"},
	{"id":"five_core", "name":"五核齐鸣", "desc":"同时装配5张卡牌", "source":"卡组达到5张"},
	{"id":"glass_edge", "name":"玻璃锋刃", "desc":"选择玻璃超频", "source":"获得玻璃超频"},
	{"id":"shattered_cannon", "name":"破碎巨炮", "desc":"让异版宠物受到玻璃超频增幅", "source":"把玻璃超频放在异版宠物右侧"},
	{"id":"gamblers_oath", "name":"赌徒誓约", "desc":"选择赌命协议", "source":"获得赌命协议"},
	{"id":"double_or_nothing", "name":"孤注一掷", "desc":"同时持有玻璃超频与赌命协议", "source":"两种高风险卡同时生效"},
	{"id":"crit_half", "name":"宠物弱点猎手", "desc":"任一宠物暴击率达到50%", "source":"单局宠物暴击率达到50%"},
	{"id":"crit_cap", "name":"宠物精准极限", "desc":"任一宠物暴击率达到上限85%", "source":"单局宠物暴击率达到85%"},
	{"id":"last_stand", "name":"命悬一线", "desc":"生命降到20%以下仍存活", "source":"存活时生命低于20%"},
	{"id":"streak_master", "name":"节拍大师", "desc":"触发一次连杀号令，并解锁影舞者", "source":"4秒内击败10名敌人"},
	{"id":"phase_traveler", "name":"相位旅人", "desc":"首次使用相位突进", "source":"瞬影自动发动相位突进"},
	{"id":"aegis_bearer", "name":"星辉护体", "desc":"获得星辉壁垒", "source":"购买星辉壁垒"},
	{"id":"soul_master", "name":"灵魂牧者", "desc":"获得灵魂汲取", "source":"购买灵魂汲取"},
	{"id":"meet_aura", "name":"暮光相逢", "desc":"首次让暮环加入队伍", "source":"获得暮环·虚空光环"},
	{"id":"meet_orbit", "name":"环尾归队", "desc":"首次让环尾加入队伍", "source":"获得环尾·轨道卫星"},
	{"id":"meet_satellite_engine", "name":"蜂巢点灯", "desc":"首次让枢核加入队伍", "source":"获得枢核·卫星引擎"},
	{"id":"meet_chain", "name":"听见弧牙", "desc":"首次让弧牙加入队伍", "source":"获得弧牙·磁暴线圈"},
	{"id":"meet_nova", "name":"第一声咆哮", "desc":"首次让爆星加入队伍", "source":"获得爆星·星核爆破"},
	{"id":"meet_phase_step", "name":"闪光小狐", "desc":"首次让瞬影加入队伍", "source":"获得瞬影·相位突进"},
	{"id":"meet_thunder_orb", "name":"猫头鹰的雷", "desc":"首次让鸣霄加入队伍", "source":"获得鸣霄·雷暴法球"},
	{"id":"meet_gravity_well", "name":"黯潮靠近", "desc":"首次让黯潮加入队伍", "source":"获得黯潮·引力奇点"},
	{"id":"meet_blade_dance", "name":"飞刃护卫", "desc":"首次让刃舞加入队伍", "source":"获得刃舞·星刃回环"},
	{"id":"meet_meteor_rain", "name":"流星伙伴", "desc":"首次让坠火加入队伍", "source":"获得坠火·陨星坠落"},
	{"id":"meet_aegis", "name":"星龟的盾", "desc":"首次让星垒加入队伍", "source":"获得星垒·星辉壁垒"},
	{"id":"meet_execute", "name":"渡鸦观察员", "desc":"首次让断罪加入队伍", "source":"获得断罪·终结印记"},
	{"id":"combo_frostfire", "name":"迟到但未失约", "desc":"首次激活极寒天火", "source":"寒霜印记与陨星坠落同时入组"},
	{"id":"combo_collapse", "name":"恒星一生", "desc":"首次激活坍缩爆心", "source":"引力奇点与星核爆破同时入组"},
	{"id":"combo_blade", "name":"门后的刀光", "desc":"首次激活瞬身刃舞", "source":"相位突进与星刃回环同时入组"},
	{"id":"combo_storm", "name":"雷声抵达", "desc":"首次激活风暴导体", "source":"雷暴法球与磁暴线圈同时入组"},
	{"id":"relic_predator_boots", "name":"旧航靴", "desc":"带回追猎者的步伐", "source":"Boss奖励选择追猎者的步伐"},
	{"id":"relic_rift_compass", "name":"出口指针", "desc":"带回裂隙罗盘", "source":"Boss奖励选择裂隙罗盘"},
	{"id":"relic_judge_spark", "name":"零点七秒", "desc":"带回裁决火花", "source":"Boss奖励选择裁决火花"},
	{"id":"relic_ember_vessel", "name":"城市火种", "desc":"带回余烬容器", "source":"Boss奖励选择余烬容器"},
	{"id":"relic_aegis_fragment", "name":"错误一侧", "desc":"带回壁垒碎片", "source":"Boss奖励选择壁垒碎片"},
	{"id":"relic_storm_relay", "name":"风暴回信", "desc":"带回风暴继电器", "source":"Boss奖励选择风暴继电器"},
	{"id":"affix_field", "name":"看清危险地面", "desc":"首次遭遇急袭或裂隙词条", "source":"遭遇急袭脉冲或裂隙蔓延"},
	{"id":"affix_counter", "name":"抓住反击机会", "desc":"首次遭遇弱点或屏障词条", "source":"遭遇暴露核心或棱镜屏障"},
	{"id":"affix_deck", "name":"救回休息卡", "desc":"首次遭遇封印契约", "source":"Boss携带封印契约"},
	{"id":"affix_pet", "name":"宠物救援员", "desc":"首次遭遇窃宠或魅惑", "source":"Boss携带星渊窃宠或倒戈魅惑"},
	{"id":"affix_shuffle", "name":"倒过来也能战斗", "desc":"首次遭遇逆序洗牌", "source":"Boss携带逆序洗牌"},
	{"id":"achievement_ten", "name":"成就新秀", "desc":"累计解锁10项成就", "source":"成就墙达到10项"},
	{"id":"seasoned", "name":"远征老兵", "desc":"累计解锁20项成就", "source":"成就墙达到20项"},
	{"id":"archivist", "name":"星渊档案员", "desc":"累计解锁40项成就", "source":"成就墙达到40项"},
	{"id":"achievement_fifty", "name":"传奇收藏家", "desc":"累计解锁50项成就", "source":"成就墙达到50项"},
	{"id":"ranger_journey", "name":"疾风启程", "desc":"使用游侠开始远征", "source":"选择游侠进入一局"},
	{"id":"knight_journey", "name":"圣壁启程", "desc":"使用骑士开始远征", "source":"选择骑士进入一局"},
	{"id":"mage_journey", "name":"双星启程", "desc":"使用星术师开始远征", "source":"选择星术师进入一局"},
	{"id":"guardian_journey", "name":"堡垒启程", "desc":"使用守卫开始远征", "source":"选择守卫进入一局"},
	{"id":"dancer_journey", "name":"暗影启程", "desc":"使用影舞者开始远征", "source":"选择影舞者进入一局"},
	{"id":"fire_journey", "name":"余烬启程", "desc":"使用星火使开始远征", "source":"选择星火使进入一局"}
]
const BOSS_RELICS := [
	{"id":"predator_boots", "name":"追猎者的步伐", "type":"角色遗物", "desc":"每级：角色移速+12%；基础供能间隔-8%", "icon":"➤"},
	{"id":"aegis_fragment", "name":"壁垒碎片", "type":"角色遗物", "desc":"每级：最大生命+12、护甲+1；立刻获得1层护盾", "icon":"⬢"},
	{"id":"rift_compass", "name":"裂隙罗盘", "type":"宠物遗物", "desc":"每级：全部宠物范围+15%；黯潮引力范围再+35%", "icon":"◎"},
	{"id":"judge_spark", "name":"裁决火花", "type":"宠物遗物", "desc":"每级：全部宠物暴击+10%；宠物暴击伤害+20%", "icon":"!"},
	{"id":"ember_vessel", "name":"余烬容器", "type":"宠物遗物", "desc":"每级强化宠物命中的灼烧；灼烧敌人倒下时小范围爆燃", "icon":"♨"},
	{"id":"storm_relay", "name":"风暴继电器", "type":"宠物遗物", "desc":"每级：弧牙多跳2次；鸣霄雷暴范围+25%", "icon":"⚡"}
]
const UPGRADES := [
	{"id":"damage", "name":"能量压缩训练", "desc":"立即提高每枚供能弹的能量；游侠与星火使收益更高", "max":8, "icon":"◆"},
	{"id":"cooldown", "name":"供能校准训练", "desc":"立即缩短基础供能间隔；星术师收益更高", "max":8, "icon":"◴"},
	{"id":"speed", "name":"步法训练", "desc":"立即提高基础移动速度；影舞者收益更高", "max":8, "icon":"➤"},
	{"id":"health", "name":"体魄训练", "desc":"立即提高最大生命；骑士与守卫收益更高", "max":8, "icon":"♥"},
	{"id":"armor", "name":"星钢淬体", "desc":"立即提高基础护甲；骑士收益更高", "max":6, "icon":"⬢"},
	{"id":"regen", "name":"静息训练", "desc":"立即提高基础生命恢复；守卫收益更高", "max":6, "icon":"✚"},
	{"id":"projectile", "name":"群敌分裂棱镜", "desc":"密集敌群中：位于宠物左侧提供6%加算，右侧提供5%乘算", "max":1, "icon":"✦"},
	{"id":"pierce", "name":"密阵穿透射线", "desc":"密集敌群中：位于宠物左侧提供6%加算，右侧提供5%乘算", "max":1, "icon":"⇥"},
	{"id":"area", "name":"拥挤空间扩张", "desc":"宠物附近至少2名敌人时，使该技能范围+12%", "max":1, "icon":"◎"},
	{"id":"crit", "name":"宠物弱点训练", "desc":"立即提高全部宠物基础暴击率与幸运；影舞者暴击收益更高", "max":8, "icon":"!"},
	{"id":"magnet", "name":"引力校准训练", "desc":"立即提高基础拾取范围", "max":6, "icon":"∩"},
	{"id":"aura", "name":"暮环·虚空光环", "desc":"召唤虚空水母暮环，持续伤害周围敌人；配合卫星宠物进化星环矩阵", "max":1, "icon":"◉"},
	{"id":"orbit", "name":"环尾·轨道卫星", "desc":"召唤星轨狐环尾，释放并增加环绕卫星", "max":1, "icon":"☄"},
	{"id":"chain", "name":"弧牙·磁暴线圈", "desc":"自动释放连锁电弧，最多弹跳多个目标", "max":1, "icon":"⚡"},
	{"id":"nova", "name":"爆星·星核爆破", "desc":"召唤星核幼狮爆星，周期咆哮并释放近身新星冲击", "max":1, "icon":"✹"},
	{"id":"homing", "name":"追踪星瞳", "desc":"作为技能改造参与邻接牌型；位于宠物右侧时伤害+4%", "max":1, "icon":"◌"},
	{"id":"burn", "name":"余烬弹头", "desc":"宠物命中附加持续灼烧；配合磁暴线圈进化熔雷回路", "max":1, "icon":"♨"},
	{"id":"satellite_engine", "name":"枢核·卫星引擎", "desc":"召唤机械蜂巢精灵枢核，生产并强化卫星；可组成星环矩阵", "max":1, "icon":"☄"},
	{"id":"glass", "name":"玻璃超频", "desc":"最大生命-20；放在宠物之后时，使该宠物伤害×1.40", "max":1, "icon":"◇"},
	{"id":"gamble", "name":"赌命协议", "desc":"护甲-2；放在宠物之后时，为该宠物增加25%暴击率", "max":1, "icon":"!"},
	{"id":"momentum", "name":"连杀号令", "desc":"4秒内击败10名敌人：恢复8生命，接下来2枚供能弹能量+50%", "max":1, "icon":"✹"},
	{"id":"ranger_focus", "name":"游侠·弧牙共振", "desc":"专属：磁暴线圈强度+1级，连锁次数与伤害提高", "max":1, "icon":"➤", "character":"游侠"},
	{"id":"knight_bulwark", "name":"骑士·圣壁光环", "desc":"专属：光环半径+32，护甲+2", "max":1, "icon":"⬢", "character":"骑士"},
	{"id":"mage_prism", "name":"星术师·双星导流", "desc":"专属：虚空光环范围+20，所需能量-20%", "max":1, "icon":"◌", "character":"星术师"},
	{"id":"guardian_bastion", "name":"守卫·堡垒编队", "desc":"专属：卫星+2，最大生命+18", "max":1, "icon":"☄", "character":"守卫"},
	{"id":"dancer_execution", "name":"影舞者·收割节拍", "desc":"专属：全部宠物暴击+12%，解锁连杀号令", "max":1, "icon":"!", "character":"影舞者"},
	{"id":"fire_rite", "name":"星火使·余烬仪式", "desc":"专属：光环命中附加灼烧，范围+12%", "max":1, "icon":"♨", "character":"星火使"},
	{"id":"phase_step", "name":"瞬影·相位突进", "desc":"自动冲向附近敌群，沿途造成伤害并短暂无敌", "max":1, "icon":"➤"},
	{"id":"thunder_orb", "name":"鸣霄·雷暴法球", "desc":"召唤风暴猫头鹰鸣霄，周期锁定精英与Boss投下雷暴法球", "max":1, "icon":"⚡"},
	{"id":"frost_brand", "name":"寒霜印记", "desc":"宠物命中使敌人短暂减速；对Boss也有效", "max":1, "icon":"❄"},
	{"id":"soul_siphon", "name":"灵魂汲取", "desc":"击败敌人有8%概率回复3生命", "max":1, "icon":"✚"},
	{"id":"gravity_well", "name":"黯潮·引力奇点", "desc":"召唤黑洞蝠鲼黯潮，周期制造牵引场把附近敌人拉向中心并造成范围伤害", "max":1, "icon":"◎"},
	{"id":"blade_dance", "name":"刃舞·星刃回环", "desc":"召唤星刃螳螂刃舞，释放高速旋转星刃贴身持续切割", "max":1, "icon":"☄"},
	{"id":"meteor_rain", "name":"坠火·陨星坠落", "desc":"召唤陨星幼龙坠火，周期锁定敌群降下范围陨星", "max":1, "icon":"✹"},
	{"id":"aegis", "name":"星垒·星辉壁垒", "desc":"召唤晶甲星龟星垒，周期展开护盾抵消下一次伤害", "max":1, "icon":"⬢"},
	{"id":"execute", "name":"断罪·终结印记", "desc":"召唤裁决渡鸦断罪，处决生命低于20%的非Boss敌人", "max":1, "icon":"!"},
	{"id":"card_slot", "name":"扩展卡匣", "desc":"占用1格，直接启用第6与第7卡牌槽；卡组超过5张时不可移除", "max":1, "icon":"▣"},
	{"id":"core_engine", "name":"星律引擎", "desc":"放在宠物之前：按卡组数量为该宠物追加基础伤害，最高+30%；不增加宠物能量", "max":1, "icon":"◆"},
	{"id":"combo_catalyst", "name":"组合催化器", "desc":"放在宠物之后：按已激活联动数量乘算该宠物伤害，最高×1.30", "max":1, "icon":"✦"},
	{"id":"empty_stencil", "name":"留白星律", "desc":"放在宠物之后：每个空卡槽使该宠物本次伤害×1.10", "max":1, "icon":"□"},
	{"id":"loyalty_cycle", "name":"第六契约", "desc":"放在宠物之后：该宠物每第6次有效伤害结算×2.20", "max":1, "icon":"⑥"},
	{"id":"misprint", "name":"故障刻印", "desc":"放在宠物之后：该宠物每次伤害在×0.85～×1.35之间波动", "max":1, "icon":"?"},
	{"id":"pair_protocol", "name":"同律双生", "desc":"放在宠物之后：存在两张同构筑标签牌时该宠物伤害×1.15", "max":1, "icon":"Ⅱ"},
	{"id":"trio_protocol", "name":"三相合唱", "desc":"放在宠物之后：存在三张同构筑标签牌时该宠物伤害×1.25", "max":1, "icon":"Ⅲ"},
	{"id":"sequence_protocol", "name":"顺序回路", "desc":"放在宠物左侧第3格：它、后续两张牌与该宠物组成连续四牌，追加20%基础伤害", "max":1, "icon":"↠"},
	{"id":"four_elements", "name":"四象花庭", "desc":"放在宠物之后：同时持有灼烧、寒霜、雷霆与虚空牌时伤害×1.45", "max":1, "icon":"✤"},
	{"id":"hanging_echo", "name":"首位回响", "desc":"紧邻宠物右侧时，重演其首次伤害判定并使伤害×1.22", "max":1, "icon":"↻"},
	{"id":"blueprint", "name":"蓝图投影", "desc":"放在宠物之后：复制右邻非复制牌的伤害规则", "max":1, "icon":"▧"},
	{"id":"brainstorm", "name":"首因风暴", "desc":"放在宠物之后：复制卡组最左侧非复制牌的伤害规则", "max":1, "icon":"⌁"},
	{"id":"red_contract", "name":"拒选红契", "desc":"持有它且整家商店不购物时永久成长；每层使所有宠物伤害×1.05，最多6层", "max":1, "icon":"R"},
	{"id":"green_momentum", "name":"无伤绿律", "desc":"连续击杀且不受伤时成长；每层伤害+4%，受击清空，最多10层", "max":1, "icon":"G"},
	{"id":"campfire", "name":"焚牌营火", "desc":"出售或替换卡牌时成长；每层伤害×1.08，击败Boss后清空，最多6层", "max":1, "icon":"♨"},
	{"id":"bull_reserve", "name":"星屑公牛", "desc":"放在宠物之后：每持有10星屑追加5%基础伤害，最多25%", "max":1, "icon":"◆"},
	{"id":"low_deck", "name":"侵蚀留白", "desc":"少于5张卡时，每少一张使伤害×1.12", "max":1, "icon":"▽"},
	{"id":"lucky_doubler", "name":"六面偏差", "desc":"放在宠物之后：33%概率使本次伤害×1.50，概率受幸运加成但上限80%", "max":1, "icon":"⚄"},
	{"id":"boss_matador", "name":"斗牛反证", "desc":"Boss特殊行动后的暴露窗口中，伤害×1.50", "max":1, "icon":"⚑"},
	{"id":"luchador", "name":"破咒面具", "desc":"下一场Boss出现时献祭自身，永久取消该Boss随机一个词条", "max":1, "icon":"◈"},
	{"id":"juggler", "name":"杂耍货架", "desc":"商店额外展示1件商品；本卡仍占用1个卡槽", "max":1, "icon":"✥"},
	{"id":"astronomer", "name":"星图学者", "desc":"放在宠物之后：至少激活1组卡牌联动时伤害×1.12", "max":1, "icon":"✧"},
	{"id":"rocket", "name":"远征火箭", "desc":"击败Boss时额外获得星屑，奖励随本局Boss击杀数平滑增长", "max":1, "icon":"➤"},
	{"id":"moon_interest", "name":"月息账户", "desc":"离开商店时按现有星屑获得10%利息，每次最多5星屑", "max":1, "icon":"☾"}
]

var state := GameState.MENU
var ui_layer: CanvasLayer
var hud: Control
var player: Player
var camera: Camera2D
var entity_root: Node2D
var projectile_root: Node2D
var pickup_root: Node2D
var visual_root: Node2D
var hazard_root: Node2D
var weapon_visual: Node2D
var skill_entities: Dictionary = {}
var pet_energy: Dictionary = {}
var last_energy_pet := ""
var guardian_stationary_time := 0.0
var fire_energy_heat := 0.0
var card_editions: Dictionary = {}
var card_runtime_values: Dictionary = {}
var last_chain_multiplier := 1.0
var last_hurt_elapsed := -99.0
var conditional_speed_bonus := 0.0
var conditional_armor_bonus := 0.0
var echo_pending: Dictionary = {}
var echo_damage_captures: Dictionary = {}
var boss_card_disruptions: Dictionary = {}
var boss_shuffle_original: Array[String] = []
var boss_shuffle_remaining := 0.0
var boss_shuffle_source
var boss_affix_pending := false
var directed_shop_pending := false
var test_mode := false
var run_new_story_ids: Array[String] = []
var narrative_seen: Dictionary = {}
var archive_category := "主线纪事"
var pending_story_toast := ""

var elapsed := 0.0
var spawn_timer := 0.0
var pulse_timer := 0.0
var hud_timer := 0.0
var star_shards := 0
var total_star_shards := 0
var spent_star_shards := 0
var kills := 0
var boss_kills := 0
var damage_taken_this_run := 0.0
var pending_boss_rewards: Array[Dictionary] = []
var mainline_completion_pending := false
var mainline_complete_overlay: Control
var run_achievement_start_count := 0
var boss_spawned: Dictionary = {}
var boss_warned: Dictionary = {}
var endless_mode := false
var endless_elapsed := 0.0
var endless_wave := 1
var next_endless_boss_wave := 3
var upgrade_levels: Dictionary = {}
var card_slots := STARTING_CARD_SLOTS
var equipped_cards: Array[String] = []
var core_engine_level := 0
var combo_catalyst_level := 0
var stats: Dictionary = {}
var icon_cache: Dictionary = {}
var portrait_cache: Dictionary = {}
var has_aura := false
var has_orbit := false
var aura_radius := 105.0
var orbit_count := 1
var chain_level := 0
var nova_level := 0
var evolutions: Dictionary = {}
var aura_ignite := false
var momentum_enabled := false
var streak_count := 0
var streak_timer := 0.0
var surge_pulses := 0
var phase_step_enabled := false
var phase_step_cooldown := 0.0
var thunder_level := 0
var soul_siphon_level := 0
var gravity_level := 0
var blade_level := 0
var meteor_level := 0
var aegis_level := 0
var aegis_timer := 0.0
var execute_enabled := false
var active_relics: Dictionary = {}
var boss_reward_overlay: Control
var bonus_crit_damage := 0.0
var burn_burst := false
var finished_run := false
var next_shop_time := FIRST_SHOP_TIME
var shop_pending := false
var queued_shops := 0
var boss_engaged_since := -1.0
var last_damage_color := Color("e8f5ff")
var effect_pool: Array[SkillEffect] = []
var pet_link_broken: Dictionary = {}
var pet_link_grace: Dictionary = {}
var enemy_cut_cooldown: Dictionary = {}
var shop_visit := 0
var shop_goods: Array = []
var shop_reroll_count := 0
var shop_overlay: Control
var shop_goods_row: HBoxContainer
var shop_refresh_pending := false
var shop_wallet_label: Label
var shop_deck_box: VBoxContainer
var pending_shop_offer := -1
var pending_shop_price := 0
var red_contract_stacks := 0
var green_momentum_stacks := 0
var campfire_stacks := 0
var core_hit_counts: Dictionary = {}
var core_mastery_ranks: Dictionary = {}
var core_mastery_progress: Dictionary = {}
var core_mastery_last_event: Dictionary = {}
var shop_purchases_this_visit := 0
var forge_purchases := 0
var active_hand_multiplier := 1.0
var resonance := 0.0
var wave_resonance_generated := 0.0
var last_hand_energy := 0
var last_hand_patterns: Array[String] = []
var hands_played := 0
var card_cast_counts: Dictionary = {}
var active_vouchers: Dictionary = {}
var consumable_sigils: Array[String] = []
var card_seals: Dictionary = {}
var card_drawbacks: Dictionary = {}
var pattern_mastery: Dictionary = {}
var star_bridge_hands := 0
var pet_insurance_used := false
var insured_pet_mastery: Dictionary = {}
var pending_drawback_id := ""
var rental_debt := 0
var cleanse_ward_charges := 0
var wave_goal: Dictionary = {}
var danger_contract: Dictionary = {}
var guaranteed_reward_pack := false
var booster_overlay: Control

var hp_bar: ProgressBar
var hp_lag_bar: ProgressBar
var time_label: Label
var level_label: Label
var kill_label: Label
var boss_label: Label
var mode_label: Label
var toast_label: Label
var displayed_health := 0.0
var skill_tooltip: PanelContainer
var deck_status_label: Label
var deck_card_row: HBoxContainer
var deck_card_cache: Dictionary = {}
var deck_empty_slots: Array[Control] = []
var card_replace_overlay: Control
var resonance_bar: ProgressBar
var active_hand_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	queue_redraw()
	show_main_menu()

func _draw() -> void:
	var focus := player.global_position if is_instance_valid(player) else Vector2.ZERO
	var visible_world := Rect2(focus - WORLD_DRAW_RADIUS, WORLD_DRAW_RADIUS * 2.0)
	draw_rect(visible_world, Color("071129"), true)
	var grid_color := Color(0.13, 0.25, 0.42, 0.22)
	var left := int(floor(visible_world.position.x / 100.0)) * 100
	var top := int(floor(visible_world.position.y / 100.0)) * 100
	for x in range(left, int(visible_world.end.x) + 101, 100):
		draw_line(Vector2(x, visible_world.position.y), Vector2(x, visible_world.end.y), grid_color, 1.0)
	for y in range(top, int(visible_world.end.y) + 101, 100):
		draw_line(Vector2(visible_world.position.x, y), Vector2(visible_world.end.x, y), grid_color, 1.0)
	for x in range(left, int(visible_world.end.x) + 101, 200):
		for y in range(top, int(visible_world.end.y) + 101, 200):
			var hash_value: int = absi((x / 200) * 73856093 + (y / 200) * 19349663)
			if hash_value % 5 == 0:
				draw_circle(Vector2(x + hash_value % 73, y + hash_value % 59), 1.5 + hash_value % 3, Color(0.45, 0.75, 1.0, 0.18))

func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	queue_redraw()
	elapsed += delta
	update_boss_card_disruptions(delta)
	update_pet_tethers(delta)
	update_conditional_card_effects(delta)
	if endless_mode:
		endless_elapsed += delta
		var target_wave := 1 + int(endless_elapsed / ENDLESS_WAVE_DURATION)
		if target_wave > endless_wave:
			endless_wave = target_wave
			queued_shops += 1
			shop_pending = true
			show_toast("无尽挑战 · 第 %d 波开始" % endless_wave, Color("f472b6"))
			show_endless_story_beat(endless_wave)
			var is_boss_wave := endless_wave >= next_endless_boss_wave
			if not is_boss_wave:
				play_tone(520.0 + endless_wave * 8.0, 0.12, 0.18)
			if is_boss_wave:
				spawn_endless_boss()
				next_endless_boss_wave += 3
	spawn_timer -= delta
	pulse_timer -= delta
	aegis_timer -= delta
	phase_step_cooldown = maxf(0.0, phase_step_cooldown - delta)
	if is_instance_valid(player) and player.character_name == "守卫":
		guardian_stationary_time = minf(3.0, guardian_stationary_time + delta) if player.velocity.length() < 28.0 else maxf(0.0, guardian_stationary_time - delta * 2.0)
	if is_instance_valid(player) and player.character_name == "星火使":
		fire_energy_heat = maxf(0.0, fire_energy_heat - delta * 0.07)
	process_weapons()
	streak_timer = maxf(0.0, streak_timer - delta)
	if streak_timer <= 0.0:
		streak_count = 0
	hud_timer -= delta
	if spawn_timer <= 0.0:
		spawn_wavelet()
		spawn_timer = maxf(0.58, 1.12 - elapsed / 680.0)
	process_pickups(delta)
	check_boss_timing()
	if not endless_mode and elapsed >= next_shop_time:
		# 错过的商店必须累计。Boss 在场时商店被锁，过去这里只把时间戳推到未来、
		# 而 shop_pending 又只是布尔量，于是卡 Boss 期间错过的每一家商店都被永久
		# 吞掉、最后只补开一次，直接构成「打不动 Boss → 买不到强化 → 更打不动」。
		while elapsed >= next_shop_time:
			next_shop_time += SHOP_INTERVAL
			queued_shops += 1
		shop_pending = true
	if shop_pending and shop_window_open() and not is_instance_valid(boss_reward_overlay):
		show_shop()
	if hud_timer <= 0.0:
		update_hud()
		hud_timer = 0.12

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == GameState.PLAYING:
			show_pause()
		elif state == GameState.PAUSED:
			resume_game()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2 and state == GameState.PLAYING and (OS.has_feature("editor") or test_mode):
		gain_star_shards(10)

func clear_ui() -> void:
	card_replace_overlay = null
	shop_overlay = null
	shop_goods_row = null
	shop_wallet_label = null
	shop_deck_box = null
	resonance_bar = null
	active_hand_label = null
	booster_overlay = null
	boss_reward_overlay = null
	mainline_complete_overlay = null
	deck_status_label = null
	deck_card_row = null
	deck_card_cache = {}
	deck_empty_slots.clear()
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)

func clear_game() -> void:
	get_tree().paused = false
	boss_card_disruptions.clear()
	boss_shuffle_original.clear()
	boss_shuffle_remaining = 0.0
	boss_shuffle_source = null
	boss_affix_pending = false
	pending_boss_rewards.clear()
	mainline_completion_pending = false
	# 必须按引用释放，不能按节点名匹配。queue_free 要到帧末才生效，而
	# 「再次远征」会在同一帧里清场并重建根节点；此时旧的同名兄弟还在树上，
	# Godot 会直接丢弃新节点的名字换成内部名，之后任何按名字的清场都会漏掉
	# 整个世界（上一局的敌人会占满 enemy_cap 导致新一局不刷怪，残留 Boss 还会
	# 永久阻塞商店）。remove_child 是同步的，能让节点立刻退出分组并停止处理。
	for node in [player, entity_root, projectile_root, pickup_root, visual_root, hazard_root]:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	# 兜底：任何仍留在树上的战斗单位都立刻脱离场景树，避免污染新一局的分组查询。
	for group_name in ["enemies", "bosses"]:
		for stale in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(stale):
				if stale.get_parent() != null:
					stale.get_parent().remove_child(stale)
				stale.queue_free()
	skill_entities.clear()
	pet_energy.clear()
	player = null
	camera = null
	entity_root = null
	projectile_root = null
	pickup_root = null
	visual_root = null
	hazard_root = null
	weapon_visual = null

func full_rect_control() -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control

func panel_style(color: Color, radius: int = 16, border_color: Color = Color.TRANSPARENT, border: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.border_color = border_color
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func make_label(text_value: String, size: int = 22, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func make_button(text_value: String, min_size := Vector2(320, 58)) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_stylebox_override("normal", panel_style(Color("17294a"), 12, Color("355c91"), 2))
	button.add_theme_stylebox_override("hover", panel_style(Color("244778"), 12, Color("70d7ff"), 2))
	button.add_theme_stylebox_override("pressed", panel_style(Color("10213e"), 12, Color("facc15"), 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): play_tone(520.0, 0.05, 0.18))
	return button

func compact_panel_style(color: Color, radius := 8, border_color := Color.TRANSPARENT, border := 0) -> StyleBoxFlat:
	var style := panel_style(color, radius, border_color, border)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func make_compact_button(text_value: String, min_size := Vector2(0, 36)) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", compact_panel_style(Color("17294a"), 8, Color("355c91"), 2))
	button.add_theme_stylebox_override("hover", compact_panel_style(Color("244778"), 8, Color("70d7ff"), 2))
	button.add_theme_stylebox_override("pressed", compact_panel_style(Color("10213e"), 8, Color("facc15"), 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): play_tone(520.0, 0.05, 0.18))
	return button

func make_skill_icon(id: String) -> Texture2D:
	if icon_cache.has(id):
		return icon_cache[id]
	var shapes := {
		"damage": '<path d="M50 14l9 24 25 3-19 16 6 25-21-13-21 13 6-25-19-16 25-3z" fill="#ff6b85"/>',
		"cooldown": '<circle cx="50" cy="50" r="29" fill="none" stroke="#70d7ff" stroke-width="8"/><path d="M50 30v22l17 10" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round"/>',
		"speed": '<path d="M18 62h34l-12 17 44-34H51l10-18z" fill="#70f0ff"/><path d="M15 37h25M10 49h29" stroke="#fff" stroke-width="5" stroke-linecap="round"/>',
		"health": '<path d="M50 81C17 61 17 38 30 27c10-8 20-3 20 7 0-10 10-15 20-7 13 11 13 34-20 54z" fill="#ef476f"/><path d="M50 43v22M39 54h22" stroke="#fff" stroke-width="6"/>',
		"armor": '<path d="M50 14l30 11v23c0 19-12 31-30 39-18-8-30-20-30-39V25z" fill="#8b9fc3"/><path d="M50 27v44M33 45h34" stroke="#e8fbff" stroke-width="6"/>',
		"regen": '<path d="M43 16h14v27h27v14H57v27H43V57H16V43h27z" fill="#4ade80"/><path d="M23 23a39 39 0 017-6M77 77a39 39 0 01-7 6" stroke="#fff" stroke-width="5"/>',
		"projectile": '<path d="M17 50l18-18 18 18-18 18zM47 50l18-18 18 18-18 18z" fill="#c084fc"/><path d="M10 79h80" stroke="#70d7ff" stroke-width="5"/>',
		"pierce": '<circle cx="25" cy="50" r="12" fill="none" stroke="#8b9fc3" stroke-width="5"/><circle cx="55" cy="50" r="12" fill="none" stroke="#8b9fc3" stroke-width="5"/><path d="M10 50h70l-12-12m12 12L68 62" fill="none" stroke="#70f0ff" stroke-width="6"/>',
		"area": '<circle cx="50" cy="50" r="32" fill="none" stroke="#c084fc" stroke-width="6"/><circle cx="50" cy="50" r="17" fill="none" stroke="#70d7ff" stroke-width="5"/><circle cx="50" cy="50" r="5" fill="#fff"/>',
		"crit": '<circle cx="50" cy="50" r="25" fill="none" stroke="#ffbd69" stroke-width="7"/><path d="M50 10v22M50 68v22M10 50h22M68 50h22" stroke="#fff" stroke-width="6"/><circle cx="50" cy="50" r="7" fill="#ef476f"/>',
		"magnet": '<path d="M22 19v37c0 35 56 35 56 0V19H61v37c0 13-22 13-22 0V19z" fill="#ef476f"/><path d="M22 19h17M61 19h17" stroke="#70d7ff" stroke-width="10"/>',
		"aura": '<path d="M22 52c0-24 12-37 28-37s28 13 28 37l-10 9H32z" fill="#5b2a86" stroke="#c084fc" stroke-width="5"/><path d="M31 59v23m13-23c-7 12 6 13-1 25m14-25c7 12-5 13 2 25m10-25v23" fill="none" stroke="#c084fc" stroke-width="5" stroke-linecap="round"/><ellipse cx="57" cy="39" rx="9" ry="11" fill="#fff"/><circle cx="60" cy="40" r="4" fill="#25133f"/><path d="M15 50h8m54 0h8M50 8v8" stroke="#70d7ff" stroke-width="4"/>',
		"orbit": '<path d="M24 65c-7-15 5-30 24-29 13-14 34-5 31 13-2 14-17 21-31 15-4 11-17 19-26 11 14 1 18-5 2-10z" fill="#226b83" stroke="#67e8f9" stroke-width="4"/><path d="M50 38l-4-20 15 14m7 5 15-12-5 22" fill="#67e8f9"/><circle cx="67" cy="44" r="5" fill="#fff"/><circle cx="69" cy="44" r="2" fill="#17294a"/><ellipse cx="50" cy="51" rx="39" ry="23" fill="none" stroke="#c084fc" stroke-width="3"/><circle cx="16" cy="62" r="7" fill="#facc15"/>',
		"chain": '<path d="M18 68c13 16 19-12 31 0s18-13 31-4" fill="none" stroke="#fde047" stroke-width="13" stroke-linecap="round"/><circle cx="78" cy="61" r="12" fill="#eab308"/><path d="M74 48l4-18 10 14M34 54l9-18 5 16" fill="#67e8f9"/><circle cx="82" cy="58" r="4" fill="#fff"/><path d="M29 13L18 37h13l-4 18 20-29H34l6-13z" fill="#fde047" stroke="#fff" stroke-width="2"/>',
		"nova": '<path d="M50 9l6 15 15-6-4 16 17 1-12 12 12 11-17 2 4 16-15-7-6 16-7-16-15 7 5-16-17-2 12-11-12-12 17-1-5-16 15 6z" fill="#fb923c"/><circle cx="50" cy="49" r="22" fill="#6b2b18"/><path d="M33 40l-8-14 17 6m16 0 17-6-8 14" fill="#fb923c"/><circle cx="43" cy="46" r="4" fill="#fff"/><circle cx="60" cy="46" r="4" fill="#fff"/><circle cx="51" cy="57" r="7" fill="#fff3c4"/>',
		"homing": '<path d="M18 55c0-28 39-39 53-14 12 23-12 42-31 27" fill="none" stroke="#70f0ff" stroke-width="7"/><path d="M58 66l-18 4 8-17" fill="#70f0ff"/><circle cx="57" cy="43" r="9" fill="#c084fc"/>',
		"burn": '<path d="M50 12c-22 25-27 38-16 59 9 17 38 17 47 0C90 50 68 35 61 23c1 15-9 18-11 8z" fill="#fb923c"/><path d="M50 48c-9 12-6 25 4 29 11-6 11-18 3-27" fill="#fff3c4"/>',
		"satellite_engine": '<path d="M50 20l21 12v36L50 80 29 68V32z" fill="#173f57" stroke="#22d3ee" stroke-width="5"/><ellipse cx="20" cy="48" rx="14" ry="23" fill="#67e8f9" opacity=".45"/><ellipse cx="80" cy="48" rx="14" ry="23" fill="#67e8f9" opacity=".45"/><circle cx="42" cy="48" r="5" fill="#fff"/><circle cx="59" cy="48" r="5" fill="#fff"/><path d="M39 28l-7-15m29 15 8-15M36 65l-10 14m38-14 10 14" stroke="#facc15" stroke-width="5" stroke-linecap="round"/>',
		"glass": '<path d="M50 11l28 28-28 50-28-50z" fill="#bde9ff" stroke="#70d7ff" stroke-width="5"/><path d="M50 11v78M22 39h56" stroke="#fff" stroke-width="3"/>',
		"gamble": '<rect x="23" y="23" width="54" height="54" rx="8" fill="#ef476f"/><circle cx="39" cy="39" r="5" fill="#fff"/><circle cx="61" cy="61" r="5" fill="#fff"/><circle cx="39" cy="61" r="5" fill="#fff"/>',
		"momentum": '<path d="M14 63h18l9-28 13 42 10-26h22" fill="none" stroke="#facc15" stroke-width="7" stroke-linejoin="round"/><circle cx="20" cy="26" r="8" fill="#fb7185"/>',
		"phase_step": '<path d="M38 69c-16 14-28 2-20-12 5-9 17-14 30-13 8-17 31-16 37 0 5 15-10 27-27 22-9 13-23 17-34 9" fill="#1f6f84" stroke="#70f0ff" stroke-width="4"/><path d="M48 44l-2-23 15 17m8 1 15-15-4 24" fill="#70f0ff"/><circle cx="68" cy="49" r="5" fill="#fff"/><path d="M9 34h25M5 48h27M14 61h18" stroke="#f0abfc" stroke-width="5" stroke-linecap="round"/>',
		"thunder_orb": '<path d="M50 18c18 0 30 14 28 33-2 22-15 34-28 39-13-5-26-17-28-39-2-19 10-33 28-33z" fill="#243a70" stroke="#60a5fa" stroke-width="5"/><path d="M30 35L16 18l5 29m49-12 14-17-5 29" fill="#60a5fa"/><circle cx="39" cy="46" r="10" fill="#fff"/><circle cx="62" cy="46" r="10" fill="#fff"/><circle cx="42" cy="47" r="4" fill="#17294a"/><circle cx="65" cy="47" r="4" fill="#17294a"/><path d="M53 57l-10 15h9l-3 13 15-20h-9l5-8z" fill="#fde047"/>',
		"frost_brand": '<path d="M50 12v76M17 31l66 38M17 69l66-38" stroke="#93c5fd" stroke-width="6"/><circle cx="50" cy="50" r="11" fill="#e0f2fe"/>',
		"soul_siphon": '<path d="M50 84C23 67 20 43 32 29c10-11 24-5 18 8 9-13 24-6 18 8 10-7 16 7 5 20-7 9-14 13-23 19z" fill="#a78bfa"/><path d="M30 70c18-3 26-12 39-29" stroke="#fff" stroke-width="4" fill="none"/>',
		"gravity_well": '<path d="M9 47L36 25l14 10 14-10 27 22-25 19-16 22-16-22z" fill="#312e81" stroke="#a78bfa" stroke-width="4"/><circle cx="50" cy="52" r="17" fill="#070b24"/><path d="M50 35c19 9 16 27 0 34-16-7-19-25 0-34z" fill="none" stroke="#c084fc" stroke-width="4"/><circle cx="35" cy="42" r="4" fill="#fff"/><circle cx="65" cy="42" r="4" fill="#fff"/><path d="M50 67c-3 12 9 11 5 21" fill="none" stroke="#a78bfa" stroke-width="4"/>',
		"blade_dance": '<path d="M50 14l10 14-4 17H44l-4-17z" fill="#26354c" stroke="#70d7ff" stroke-width="4"/><circle cx="46" cy="31" r="3" fill="#70f0ff"/><circle cx="55" cy="31" r="3" fill="#70f0ff"/><path d="M46 45L24 76 8 65l25-30m21 10 22 31 16-11-25-30" fill="#d8e5f3" stroke="#70d7ff" stroke-width="4"/><path d="M50 45v39M37 56l-12 26m38-26 12 26" stroke="#c084fc" stroke-width="6"/>',
		"meteor_rain": '<path d="M23 68c8-25 17-37 35-34 18 4 25 20 17 35-9 17-39 20-52-1z" fill="#6b2634" stroke="#ef476f" stroke-width="4"/><circle cx="68" cy="40" r="13" fill="#fb923c"/><path d="M59 31l-2-18 12 13m7 5 12-11-4 19" fill="#facc15"/><circle cx="72" cy="38" r="4" fill="#fff"/><path d="M29 52L10 31l24 6m-10 36L8 85l28-3" fill="#fb923c"/><path d="M20 60L6 52l12-9" fill="#fde047"/>',
		"aegis": '<path d="M18 51c0-22 13-34 34-34s34 12 34 34-14 36-34 36-34-14-34-36z" fill="#173f79" stroke="#70d7ff" stroke-width="5"/><path d="M52 19l12 15-12 16-12-16zM31 42l12 12-10 17m42-29L63 54l10 17" fill="none" stroke="#bde9ff" stroke-width="4"/><circle cx="88" cy="55" r="10" fill="#3b82f6"/><circle cx="91" cy="53" r="3" fill="#fff"/><circle cx="15" cy="65" r="6" fill="#3b82f6"/>',
		"ranger_focus": '<path d="M15 72L78 28" stroke="#70f0ff" stroke-width="8"/><path d="M53 18l28 10-10 28" fill="none" stroke="#fff" stroke-width="5"/><circle cx="24" cy="66" r="8" fill="#66d9ff"/>',
		"knight_bulwark": '<path d="M50 13l30 11v26c0 19-13 31-30 38-17-7-30-19-30-38V24z" fill="#ffbd69"/><circle cx="50" cy="49" r="14" fill="#fff3c4"/>',
		"mage_prism": '<path d="M50 12l25 38-25 38-25-38z" fill="#c084fc"/><path d="M50 12v76M25 50h50" stroke="#fff" stroke-width="4"/>',
		"guardian_bastion": '<rect x="22" y="25" width="56" height="50" rx="8" fill="#4ade80"/><path d="M30 57h40M38 43h24" stroke="#eafff1" stroke-width="6"/>',
		"dancer_execution": '<path d="M18 72c25-43 38-43 64 0" fill="none" stroke="#f472b6" stroke-width="8"/><path d="M23 31l12 12M65 43l12-12" stroke="#fff" stroke-width="6"/>',
		"fire_rite": '<path d="M50 12c-21 25-24 45-10 64 12 15 34 10 39-4 6-17-10-29-17-42 0 13-10 18-12 6z" fill="#fb923c"/><circle cx="50" cy="67" r="10" fill="#fef08a"/>',
		"execute": '<path d="M22 72c12-32 29-44 48-36 11 4 17 16 12 26-6 14-25 13-38 7-9 13-18 17-28 12z" fill="#25152f" stroke="#f472b6" stroke-width="4"/><circle cx="70" cy="42" r="11" fill="#351b3b"/><path d="M78 42l17 7-18 5z" fill="#d8e5f3"/><circle cx="73" cy="39" r="4" fill="#fb7185"/><path d="M47 55L18 26M31 79L75 20" stroke="#f8fafc" stroke-width="4"/><path d="M14 18h24M14 18v24" stroke="#fb7185" stroke-width="6"/>',
		"card_slot": '<rect x="17" y="24" width="66" height="52" rx="8" fill="#17294a" stroke="#70d7ff" stroke-width="5"/><path d="M50 34v32M34 50h32" stroke="#facc15" stroke-width="7" stroke-linecap="round"/>',
		"core_engine": '<circle cx="50" cy="50" r="29" fill="#243a70" stroke="#facc15" stroke-width="6"/><path d="M50 17v15M50 68v15M17 50h15M68 50h15" stroke="#70d7ff" stroke-width="7"/><circle cx="50" cy="50" r="12" fill="#fff3c4"/>',
		"combo_catalyst": '<path d="M22 30h23l10 17h23M22 70h23l10-17h23" fill="none" stroke="#c084fc" stroke-width="7" stroke-linecap="round"/><circle cx="22" cy="30" r="8" fill="#70d7ff"/><circle cx="22" cy="70" r="8" fill="#fb923c"/><circle cx="78" cy="50" r="10" fill="#facc15"/>',
		"empty_stencil": '<rect x="22" y="18" width="56" height="68" rx="7" fill="none" stroke="#bde9ff" stroke-width="5" stroke-dasharray="9 6"/><path d="M36 35h28M36 50h18M36 65h25" stroke="#607086" stroke-width="4"/>',
		"loyalty_cycle": '<path d="M50 12l31 18v40L50 88 19 70V30z" fill="#312e81" stroke="#c084fc" stroke-width="5"/><circle cx="50" cy="50" r="19" fill="none" stroke="#facc15" stroke-width="6"/><path d="M39 35l11 31 11-31" fill="none" stroke="#fff" stroke-width="6"/>',
		"misprint": '<path d="M18 24h58v13H28v12h57v13H22v14h61" fill="none" stroke="#f472b6" stroke-width="8"/><path d="M31 17v67M67 17v67" stroke="#70f0ff" stroke-width="3" stroke-dasharray="5 8"/>',
		"pair_protocol": '<circle cx="36" cy="50" r="23" fill="#173f79" stroke="#70d7ff" stroke-width="5"/><circle cx="64" cy="50" r="23" fill="#3b2164" stroke="#c084fc" stroke-width="5"/><path d="M44 50h12" stroke="#fff" stroke-width="7"/>',
		"trio_protocol": '<circle cx="50" cy="27" r="15" fill="#70d7ff"/><circle cx="31" cy="65" r="15" fill="#c084fc"/><circle cx="69" cy="65" r="15" fill="#fb923c"/><path d="M50 42L37 56m26 0L50 42M46 65h8" stroke="#fff" stroke-width="5"/>',
		"sequence_protocol": '<path d="M15 72h18V57h17V42h17V27h18" fill="none" stroke="#70d7ff" stroke-width="8"/><path d="M72 16l14 11-14 11" fill="none" stroke="#facc15" stroke-width="6"/><circle cx="24" cy="72" r="6" fill="#fff"/>',
		"four_elements": '<circle cx="50" cy="50" r="13" fill="#fff"/><circle cx="50" cy="22" r="14" fill="#fb923c"/><circle cx="78" cy="50" r="14" fill="#fde047"/><circle cx="50" cy="78" r="14" fill="#93c5fd"/><circle cx="22" cy="50" r="14" fill="#a78bfa"/><path d="M50 35v6m15 9h-6m-9 15v-6m-15-9h6" stroke="#17294a" stroke-width="5"/>',
		"hanging_echo": '<path d="M29 17v43c0 19 23 27 36 14 10-10 3-27-11-25-10 1-13 14-5 19" fill="none" stroke="#c084fc" stroke-width="7" stroke-linecap="round"/><path d="M18 17h22M22 27h14" stroke="#70d7ff" stroke-width="5"/><circle cx="54" cy="59" r="5" fill="#fff"/>',
		"blueprint": '<path d="M21 16h48l12 13v55H21z" fill="#183b61" stroke="#70d7ff" stroke-width="5"/><path d="M69 16v15h12M31 42h40M31 57h40M43 32v40M59 32v40" stroke="#bde9ff" stroke-width="3"/><circle cx="51" cy="50" r="8" fill="#c084fc"/>',
		"brainstorm": '<path d="M28 62c-14-3-15-24 0-29 3-17 27-19 35-6 17-3 26 17 14 28-4 5-10 7-17 7z" fill="#7c3aed" stroke="#e9d5ff" stroke-width="5"/><path d="M51 57L39 76h12l-5 14 20-24H54l6-9z" fill="#fde047"/>',
		"red_contract": '<path d="M24 18h53v64H24z" fill="#4a1824" stroke="#ef476f" stroke-width="5"/><path d="M34 32h33M34 44h24M34 56h31" stroke="#fca5a5" stroke-width="4"/><circle cx="60" cy="69" r="13" fill="#b91c1c" stroke="#facc15" stroke-width="3"/><path d="M54 69h12" stroke="#fff" stroke-width="4"/>',
		"green_momentum": '<path d="M17 76l19-20 13 10 25-32" fill="none" stroke="#4ade80" stroke-width="8"/><path d="M62 31h17v17" fill="none" stroke="#fff" stroke-width="6"/><circle cx="21" cy="75" r="7" fill="#22c55e"/><circle cx="49" cy="66" r="7" fill="#86efac"/>',
		"campfire": '<path d="M27 78l46-20M27 58l46 20" stroke="#8b5a2b" stroke-width="9" stroke-linecap="round"/><path d="M50 17c-18 19-22 31-13 44 7 11 24 9 30-2 7-13-3-23-10-33 0 10-7 14-7 3z" fill="#fb923c"/><path d="M50 42c-8 9-7 17 0 22 8-5 9-13 3-21" fill="#fde047"/>',
		"bull_reserve": '<path d="M27 38C12 27 12 16 14 13c8 12 17 12 28 12h16c11 0 20 0 28-12 2 3 2 14-13 25" fill="#8b5a2b" stroke="#facc15" stroke-width="5"/><path d="M27 38c0 32 12 45 23 45s23-13 23-45L50 28z" fill="#6b3f25"/><circle cx="40" cy="49" r="5" fill="#fff"/><circle cx="60" cy="49" r="5" fill="#fff"/><circle cx="50" cy="67" r="10" fill="#facc15"/>',
		"low_deck": '<rect x="17" y="24" width="42" height="55" rx="5" fill="#17294a" stroke="#70d7ff" stroke-width="4"/><rect x="31" y="17" width="42" height="55" rx="5" fill="#263b61" stroke="#c084fc" stroke-width="4"/><path d="M72 64v24M62 78l10 10 10-10" fill="none" stroke="#ef476f" stroke-width="6"/>',
		"lucky_doubler": '<rect x="14" y="20" width="34" height="34" rx="7" fill="#f8fafc" stroke="#70d7ff" stroke-width="4"/><rect x="48" y="47" width="38" height="38" rx="7" fill="#facc15" stroke="#fb923c" stroke-width="4"/><circle cx="25" cy="31" r="4" fill="#17294a"/><circle cx="38" cy="44" r="4" fill="#17294a"/><circle cx="59" cy="58" r="4" fill="#6b2b18"/><circle cx="75" cy="74" r="4" fill="#6b2b18"/><path d="M47 31l11-10m-5 0h5v5" stroke="#c084fc" stroke-width="4"/>',
		"boss_matador": '<path d="M19 76c12-42 32-59 60-52-8 8-13 20-10 34 3 12 10 19 17 26-26-8-45-2-67-8z" fill="#b91c1c" stroke="#ef476f" stroke-width="5"/><path d="M48 39h33M67 25v30" stroke="#facc15" stroke-width="5"/><circle cx="67" cy="39" r="11" fill="none" stroke="#fff" stroke-width="4"/>',
		"luchador": '<path d="M23 24l27-12 27 12v39c0 17-12 25-27 28-15-3-27-11-27-28z" fill="#312e81" stroke="#facc15" stroke-width="5"/><path d="M31 35l14 5-5 13-13-4m42-14-14 5 5 13 13-4" fill="#ef476f"/><path d="M40 70h20M50 56v24" stroke="#fff" stroke-width="5"/>',
		"juggler": '<path d="M26 73c13-25 35-25 48 0" fill="none" stroke="#c084fc" stroke-width="6"/><circle cx="24" cy="35" r="11" fill="#ef476f"/><circle cx="50" cy="20" r="11" fill="#70d7ff"/><circle cx="76" cy="35" r="11" fill="#facc15"/><path d="M31 49c11 8 27 8 38 0" fill="none" stroke="#fff" stroke-width="4" stroke-dasharray="5 5"/>',
		"astronomer": '<path d="M26 71l29-38 19 14-29 38z" fill="#183b61" stroke="#70d7ff" stroke-width="5"/><circle cx="67" cy="31" r="16" fill="#312e81" stroke="#c084fc" stroke-width="5"/><path d="M41 78l-10 12m17-8 8 8" stroke="#facc15" stroke-width="5"/><path d="M20 24l4 8 8 4-8 4-4 8-4-8-8-4 8-4z" fill="#fff"/>',
		"rocket": '<path d="M50 12c18 13 25 31 18 50L50 78 32 62c-7-19 0-37 18-50z" fill="#e8f5ff" stroke="#70d7ff" stroke-width="5"/><circle cx="50" cy="43" r="10" fill="#17294a" stroke="#c084fc" stroke-width="4"/><path d="M32 57L18 72l17-2m33-13 14 15-17-2M43 76l7 14 7-14" fill="#fb923c" stroke="#facc15" stroke-width="3"/>',
		"moon_interest": '<path d="M65 17c-25 5-33 38-13 54 9 7 20 9 30 5-13 14-38 15-54-2-20-22-8-57 21-64 6-1 12 1 16 7z" fill="#fde68a"/><circle cx="64" cy="58" r="20" fill="#facc15" stroke="#fff3c4" stroke-width="4"/><path d="M64 45v26m-8-20h13c8 0 8 9 0 9H56" fill="none" stroke="#6b4b12" stroke-width="4"/>',
		"endless_damage": '<path d="M18 50c9-22 25-22 32 0s23 22 32 0-7-31-20-16" fill="none" stroke="#ef476f" stroke-width="8"/><path d="M42 20l16 16-25 38-9 3 2-10z" fill="#e8f5ff" stroke="#facc15" stroke-width="4"/>',
		"endless_vitality": '<path d="M13 53c10-23 26-23 37 0s27 23 37 0-7-33-23-17" fill="none" stroke="#4ade80" stroke-width="8"/><path d="M50 82C25 67 25 48 36 40c7-5 14-1 14 6 0-7 7-11 14-6 11 8 11 27-14 42z" fill="#ef476f"/>',
		"endless_haste": '<path d="M12 51c10-22 26-22 38 0s28 22 38 0-8-31-24-16" fill="none" stroke="#70f0ff" stroke-width="8"/><path d="M26 29h29L44 45h31L39 79l9-23H20z" fill="#fde047"/>',
		"predator_boots": '<path d="M29 17h27v34c0 9 9 15 25 17l-5 17H27c-11 0-14-14-5-20l12-8z" fill="#7c2d12" stroke="#fb923c" stroke-width="5"/><path d="M27 72h50" stroke="#facc15" stroke-width="5"/>',
		"rift_compass": '<circle cx="50" cy="50" r="34" fill="#17294a" stroke="#c084fc" stroke-width="6"/><path d="M50 15v12M50 73v12M15 50h12M73 50h12" stroke="#70d7ff" stroke-width="5"/><path d="M61 34L53 55 34 66l10-23z" fill="#ef476f"/><circle cx="50" cy="50" r="6" fill="#fff"/>',
		"judge_spark": '<path d="M24 24h36v20H24zM50 44l30 30-12 12-30-30z" fill="#facc15" stroke="#fff3c4" stroke-width="4"/><path d="M16 82h45" stroke="#c084fc" stroke-width="8"/><path d="M76 17L64 37h11l-7 17 20-25H77l7-12z" fill="#70d7ff"/>',
		"ember_vessel": '<path d="M31 23h38l-5 12v42c0 10-28 10-28 0V35z" fill="#6b2634" stroke="#fb923c" stroke-width="5"/><path d="M28 23h44M37 16h26" stroke="#facc15" stroke-width="5"/><path d="M50 42c-12 14-9 29 1 33 12-7 10-19 4-28" fill="#fde047"/>',
		"aegis_fragment": '<path d="M18 24l33-11 30 16-13 23 5 29-25-10-22 14 2-30z" fill="#173f79" stroke="#70d7ff" stroke-width="6"/><path d="M51 14l-3 57m-20-16 40-3" stroke="#fff" stroke-width="4"/>',
		"storm_relay": '<path d="M22 73V35m56 38V35" stroke="#70d7ff" stroke-width="8"/><circle cx="22" cy="26" r="11" fill="#c084fc"/><circle cx="78" cy="26" r="11" fill="#c084fc"/><path d="M31 35c12 8 26 8 38 0M30 52c13 8 27 8 40 0M29 69c14 8 28 8 42 0" fill="none" stroke="#fde047" stroke-width="5"/><path d="M48 22l-8 17h9l-5 15 18-23h-9l6-9z" fill="#fff"/>'
	}
	var body: String
	if shapes.has(id):
		body = str(shapes[id])
	else:
		# 新构筑牌使用ID生成稳定且互不相同的星律纹章，绝不回退成同一图标。
		var icon_hash := absi(id.hash())
		var accent := Color.from_hsv(float(icon_hash % 360) / 360.0, 0.66, 0.96).to_html(false)
		var offset_a := 18 + icon_hash % 22
		var offset_b := 62 + (icon_hash / 7) % 20
		var ring := 15 + (icon_hash / 13) % 13
		body = '<path d="M50 13L82 32 76 70 50 88 22 70 18 33z" fill="#14274a" stroke="#%s" stroke-width="5"/><circle cx="%d" cy="38" r="%d" fill="none" stroke="#fff" stroke-width="4"/><path d="M18 76L%d 22 82 76M28 58h44" fill="none" stroke="#%s" stroke-width="5" stroke-linecap="round"/>' % [accent, offset_a, ring, offset_b, accent]
	var svg := '<svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><circle cx="50" cy="50" r="47" fill="#0b1834" stroke="#355c91" stroke-width="3"/>' + body + '</svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	icon_cache[id] = texture
	return texture

func make_character_portrait(character: String) -> Texture2D:
	if portrait_cache.has(character):
		return portrait_cache[character]
	var accent := "#66d9ff"
	var figure := '<path d="M76 159l8-47h52l8 47z" fill="#328aab"/><circle cx="110" cy="77" r="31" fill="#66d9ff"/><path d="M83 74c12-29 42-36 58-5l-11-34-45 12z" fill="#19375b"/><path d="M128 98l38 22-9 13-39-19z" fill="#70f0ff"/><rect x="151" y="113" width="35" height="15" rx="5" fill="#e8fbff"/>'
	match character:
		"骑士":
			accent = "#ffbd69"
			figure = '<path d="M70 160l11-57h58l12 57z" fill="#9a6630"/><circle cx="110" cy="70" r="33" fill="#ffbd69"/><path d="M75 70a35 35 0 0170 0v20H75z" fill="#d8e5f3"/><path d="M84 72h52v10H84z" fill="#17294a"/><path d="M148 94l39 16-8 47-42 8-10-45z" fill="#d89b45" stroke="#fff2c7" stroke-width="5"/><path d="M158 111l17 14-20 19z" fill="#fff2c7"/>'
		"星术师":
			accent = "#c084fc"
			figure = '<path d="M72 161l18-62h41l22 62z" fill="#7546a5"/><circle cx="110" cy="78" r="28" fill="#c084fc"/><path d="M67 61l45-49 43 54z" fill="#4c2777"/><path d="M72 62h85v13H72z" fill="#a86ee4"/><circle cx="110" cy="78" r="7" fill="#fff"/><path d="M155 62v93" stroke="#ffdc73" stroke-width="7"/><circle cx="155" cy="50" r="15" fill="#70f0ff"/><path d="M90 113l-38 21" stroke="#c084fc" stroke-width="14" stroke-linecap="round"/>'
		"守卫":
			accent = "#4ade80"
			figure = '<path d="M68 160l15-58h55l14 58z" fill="#27734d"/><circle cx="110" cy="75" r="31" fill="#4ade80"/><path d="M77 61h66v29H77z" fill="#d1fae5"/><path d="M86 75h48" stroke="#183b32" stroke-width="8"/><path d="M145 100l37 17-7 43-42 3-8-45z" fill="#3aa96f" stroke="#d1fae5" stroke-width="5"/><circle cx="154" cy="132" r="9" fill="#d1fae5"/>'
		"影舞者":
			accent = "#f472b6"
			figure = '<path d="M73 160l14-55h45l16 55z" fill="#a8326f"/><circle cx="110" cy="77" r="29" fill="#f472b6"/><path d="M78 65c8-36 50-36 65 0l-17-22-38 5z" fill="#491b49"/><path d="M72 111l-42 24" stroke="#f9a8d4" stroke-width="7"/><path d="M145 111l42 24" stroke="#f9a8d4" stroke-width="7"/><path d="M30 135l20-11M170 124l20 11" stroke="#fff" stroke-width="3"/>'
		"星火使":
			accent = "#fb923c"
			figure = '<path d="M70 160l17-57h47l17 57z" fill="#b84d26"/><circle cx="110" cy="76" r="29" fill="#fb923c"/><path d="M78 75c6-40 56-44 64 0l-12-37-46 8z" fill="#7c2d12"/><path d="M154 64v92" stroke="#fde68a" stroke-width="7"/><path d="M154 42c-18 19 0 29 0 29s18-10 0-29z" fill="#fef08a"/><circle cx="74" cy="130" r="15" fill="#fb923c" opacity=".7"/>'
	var svg := '<svg width="220" height="180" viewBox="0 0 220 180" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="g"><stop stop-color="' + accent + '" stop-opacity=".28"/><stop offset="1" stop-color="#071129" stop-opacity="0"/></radialGradient></defs><rect width="220" height="180" rx="18" fill="#0a1730"/><circle cx="110" cy="91" r="80" fill="url(#g)"/><circle cx="110" cy="91" r="69" fill="none" stroke="' + accent + '" stroke-opacity=".35" stroke-width="3"/><path d="M22 36h28M170 36h28M15 145h42M163 145h42" stroke="' + accent + '" stroke-width="3" stroke-linecap="round"/>' + figure + '</svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	portrait_cache[character] = texture
	return texture

func make_character_passive_icon(character: String) -> Texture2D:
	var cache_id := "passive_" + character
	if icon_cache.has(cache_id):
		return icon_cache[cache_id]
	var accent := "#66d9ff"
	var symbol := '<path d="M16 62h39l-11 14 40-31H49l10-14z" fill="#70f0ff"/><path d="M18 34h28M12 47h30" stroke="#e8fbff" stroke-width="5" stroke-linecap="round"/>'
	match character:
		"骑士":
			accent = "#ffbd69"
			symbol = '<path d="M50 15l29 11v22c0 19-12 31-29 39-17-8-29-20-29-39V26z" fill="#b97932" stroke="#fff2c7" stroke-width="5"/><path d="M50 31v36M32 49h36" stroke="#fff2c7" stroke-width="7" stroke-linecap="round"/>'
		"星术师":
			accent = "#c084fc"
			symbol = '<path d="M50 14l31 58H19z" fill="#573181" stroke="#d8b4fe" stroke-width="5"/><path d="M50 28L35 63h30z" fill="#70f0ff"/><circle cx="25" cy="28" r="8" fill="#fff"/><circle cx="77" cy="31" r="7" fill="#facc15"/>'
		"守卫":
			accent = "#4ade80"
			symbol = '<path d="M50 22l23 13v30L50 78 27 65V35z" fill="#267451" stroke="#d1fae5" stroke-width="5"/><circle cx="50" cy="50" r="9" fill="#d1fae5"/><circle cx="17" cy="50" r="8" fill="#70f0ff"/><circle cx="83" cy="50" r="8" fill="#70f0ff"/><path d="M25 50h16M59 50h16" stroke="#d1fae5" stroke-width="4"/>'
		"影舞者":
			accent = "#f472b6"
			symbol = '<path d="M21 75l18-41 9 5-17 42zM79 75L61 34l-9 5 17 42z" fill="#f9a8d4"/><path d="M28 29l13-13 8 20-9 5zM72 29L59 16l-8 20 9 5z" fill="#fff"/><path d="M50 42l5 9 10 2-8 7 2 11-9-5-9 5 2-11-8-7 10-2z" fill="#facc15"/>'
		"星火使":
			accent = "#fb923c"
			symbol = '<path d="M51 12c7 18-8 20 0 34 4-10 14-13 15-25 15 15 20 31 12 45-10 19-42 24-55 3-9-16-1-34 15-45-2 14 2 20 8 25 3-13 13-21 5-37z" fill="#fb923c" stroke="#fde68a" stroke-width="4"/><circle cx="51" cy="64" r="12" fill="#fef08a"/>'
	var svg := '<svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="3" width="94" height="94" rx="22" fill="#0a1730" stroke="' + accent + '" stroke-width="4"/><circle cx="50" cy="50" r="40" fill="' + accent + '" opacity=".10"/>' + symbol + '</svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	icon_cache[cache_id] = texture
	return texture

func add_dim_background(parent: Control, opacity := 0.72) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.06, opacity)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)

func story_entry_unlocked(entry: Dictionary) -> bool:
	var requirement := str(entry.get("unlock", ""))
	return requirement.is_empty() or requirement in SaveManager.data.achievements

func unlocked_story_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in StoryArchiveData.ENTRIES:
		if story_entry_unlocked(entry):
			result.append(str(entry.id))
	return result

func unread_story_count() -> int:
	var count := 0
	for id in unlocked_story_ids():
		if not id in SaveManager.data.story_read:
			count += 1
	return count

func newly_unlocked_story_ids(previous_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for id in unlocked_story_ids():
		if not previous_ids.has(id):
			result.append(id)
	return result

func story_ids_for_achievement(achievement_id: String) -> Array[String]:
	var result: Array[String] = []
	for entry in StoryArchiveData.ENTRIES:
		if str(entry.get("unlock", "")) == achievement_id:
			result.append(str(entry.id))
	return result

func open_story_from_achievement(achievement_id: String) -> void:
	var ids := story_ids_for_achievement(achievement_id)
	if ids.is_empty():
		return
	var entry: Dictionary = StoryArchiveData.get_entry(ids[0])
	show_story_archive(str(entry.category), str(entry.id))

func character_opening_line(character: String) -> String:
	match character:
		"游侠": return "岚：弧牙，接好能量！我们一起把路找回来。"
		"骑士": return "洛恩：暮环放心，我会挡住前面的危险。"
		"星术师": return "弥星：先排好队形，再让星光出发。"
		"守卫": return "砾：卫星准备好，我们去修好那扇门。"
		"影舞者": return "绯：刃舞跟紧我，我们比风暴更快。"
		"星火使": return "烬歌：坠火，带上火种一起回家！"
	return "远征者：把能量交给星灵，一起点亮星渊。"

func chapter_story_profile(chapter: int) -> Dictionary:
	var profiles := {
		1:{"title":"第一关 · 迷路的领航员", "boss":"赫巡：离开旧路线很危险！快回去！"},
		2:{"title":"第二关 · 关得太紧的城门", "boss":"弥垣：外面还有风暴，我不能开门！"},
		3:{"title":"第三关 · 算错的守护机器", "boss":"天秤·零号：发现闯入者，启动大灯塔防卫。"},
		4:{"title":"第四关 · 赫巡想起名字", "boss":"赫巡：岚，如果你真的准备好了，就躲开我的冲刺！"},
		5:{"title":"第五关 · 弥垣打开大门", "boss":"弥垣：让我看看，你们能不能安全穿过这些陷阱。"},
		6:{"title":"第六关 · 一起修好灯塔", "boss":"天秤·零号：交出全部星灵能量，这是最快的修复办法。"}
	}
	return profiles.get(chapter, {"title":"无尽巡逻", "boss":"新的故障能量正在靠近。"})

func boss_character_reply(chapter: int, character: String) -> String:
	if chapter in [1, 4] and character == "游侠": return "岚：老师，我会看路，也会自己选择方向！"
	if chapter in [2, 5] and character == "骑士": return "洛恩：我们已经会保护自己，请把门打开！"
	if chapter in [2, 5] and character == "守卫": return "砾：弥垣，我带来了有出口的新图纸！"
	if chapter in [3, 6] and character == "星火使": return "烬歌：空灯塔保护不了任何人，我们要一起回家！"
	if chapter in [3, 6] and character == "影舞者": return "绯：星灵是伙伴，不是机器里的零件。"
	if chapter == 6 and character == "星术师": return "弥星：合作也能修好灯塔，让我们试一次。"
	return "远征者：我们会保护彼此，也会一起修好这里。"

func boss_half_story_line(boss_name: String, chapter: int) -> String:
	match boss_name:
		"星渊追猎者": return "赫巡：岚，你真的学会看路了……" if chapter >= 4 else "赫巡：为什么你们总能找到我留下的空隙？"
		"星渊禁锢者": return "弥垣：也许，这扇门真的该打开了……" if chapter >= 5 else "弥垣：你们竟然躲开了所有陷阱。"
		"星渊裁决者": return "天秤·零号：新答案成立——伙伴合作可以修复灯塔。" if chapter >= 6 else "天秤·零号：防卫失败，重新检查任务。"
	return "Boss身上的故障光芒变弱了。"

func boss_memory_for_chapter(chapter: int) -> Dictionary:
	var memories := {
		1:{"title":"《赫巡的手画地图》", "text":"护甲里藏着一张通往月港的地图。赫巡一直记得岚和回家的路。"},
		2:{"title":"《请在安全时开门》", "text":"城里的人留下许多纸条。他们想和弥垣一起走出大门。"},
		3:{"title":"《灯塔的真正任务》", "text":"旧说明书写着：灯塔要帮助大家回家，而不是把大家挡在外面。"},
		4:{"title":"《第十三号路线》", "text":"赫巡交出自己的秘密地图，并承认岚已经能独自带路。"},
		5:{"title":"《有两个出口的新图纸》", "text":"弥垣和砾决定一起修城。每座新房子都要留出安全出口。"},
		6:{"title":"《伙伴供能计划》", "text":"远征者给星灵供能，星灵再为灯塔供能。大家一起完成了修复。"}
	}
	return memories.get(chapter, {"title":"《巡逻记录》", "text":"远征队又修好了一小段星路。"})

func show_endless_story_beat(wave: int) -> void:
	var lines := {
		3:"敌人学会观察卡组了。留意Boss词条，及时改变战法。",
		6:"六名远征者寄出了家书：巡逻结束后，我们一起回家。",
		9:"赫巡点亮新路灯：道路会提醒危险，也会帮助朋友见面。",
		12:"弥垣种下第一棵树：真正的保护，是一起面对风雨。",
		20:"一路上的星灵点起小灯，新的星路已经连到远方。"
	}
	if lines.has(wave):
		show_toast("新记忆浮现\n%s" % str(lines[wave]), Color("c084fc"), 3.2)

func pet_first_meeting_line(id: String) -> String:
	var lines := {
		"aura":"暮环加入队伍：给它能量，它会展开近身光环。",
		"orbit":"环尾加入队伍：给它能量，它会召唤轨道卫星。",
		"satellite_engine":"枢核加入队伍：它能制造更多小卫星。",
		"chain":"弧牙加入队伍：它的雷电会在敌人之间跳跃。",
		"nova":"爆星加入队伍：敌人靠近时，它会发动星核爆破。",
		"phase_step":"瞬影加入队伍：它会冲过敌人并留下相位印记。",
		"thunder_orb":"鸣霄加入队伍：它会把雷球投向重要目标。",
		"gravity_well":"黯潮加入队伍：它能把附近敌人拉到一起。",
		"blade_dance":"刃舞加入队伍：它会用飞刃守住身边区域。",
		"meteor_rain":"坠火加入队伍：它会召唤陨星轰击一片区域。",
		"aegis":"星垒加入队伍：它会展开护盾挡住危险。",
		"execute":"断罪加入队伍：它会击倒生命很低的普通敌人。"
	}
	return str(lines.get(id, ""))

func relic_story_line(id: String) -> String:
	var lines := {
		"predator_boots":"赫巡留下的领航靴，让角色移动和供能都更快。",
		"rift_compass":"弥垣的修理罗盘，指针会寻找最近的安全出口。",
		"judge_spark":"零号停下来思考时，核心里掉出的一颗小火花。",
		"ember_vessel":"烬歌保存家乡炉火的容器，里面还有温暖的火种。",
		"aegis_fragment":"星垒留下的晶甲会提高角色生命、护甲并提供护盾。",
		"storm_relay":"它能让弧牙和鸣霄的雷声传得更远。"
	}
	return str(lines.get(id, ""))

func relic_rank(id: String) -> int:
	if not active_relics.has(id):
		return 0
	var stored = active_relics[id]
	# 兼容本轮开发前使用 true 记录“已拥有”的旧运行状态。
	if stored is bool:
		return 1 if bool(stored) else 0
	return clampi(int(stored), 0, 3)

func announce_new_combo_stories() -> void:
	var lines := {
		"熔雷回路":"火焰碰到连锁雷电，敌群发生熔雷爆燃。",
		"星环矩阵":"暮环、环尾和枢核组成更大的卫星队形。",
		"极寒天火":"寒霜锁住敌人，坠火的陨星把印记一起引爆。",
		"坍缩爆心":"黯潮先把敌人拉拢，爆星再从中心发动爆破。",
		"瞬身刃舞":"瞬影留下路线，刃舞的飞刃紧跟着穿过敌群。",
		"风暴导体":"鸣霄标记目标，弧牙让雷电跳向更多敌人。"
	}
	for combo_name in active_combo_names():
		var key := "combo_story_" + combo_name
		if narrative_seen.has(key):
			continue
		narrative_seen[key] = true
		var combo_achievement: String = str({"极寒天火":"combo_frostfire", "坍缩爆心":"combo_collapse", "瞬身刃舞":"combo_blade", "风暴导体":"combo_storm"}.get(combo_name, ""))
		if not combo_achievement.is_empty():
			award_achievement(combo_achievement)
		pending_story_toast = "宠物组合 · %s\n%s" % [combo_name, str(lines.get(combo_name, "两只宠物配合出了新的攻击。"))]

func award_pet_meeting_achievement(id: String) -> void:
	if id in CORE_SKILL_CARD_IDS:
		award_achievement("meet_" + id)

func award_boss_affix_achievements(ids: Array[String]) -> void:
	for id in ids:
		match id:
			"rapid_pattern", "riftfield": award_achievement("affix_field")
			"exposed_core", "prism_shield": award_achievement("affix_counter")
			"sealed_hand": award_achievement("affix_deck")
			"pet_thief", "pet_charm": award_achievement("affix_pet")
			"reverse_shuffle": award_achievement("affix_shuffle")

func start_game() -> void:
	if not bool(SaveManager.data.intro_seen):
		show_story_prologue()
		return
	start_game_after_prologue()

func show_story_prologue() -> void:
	state = GameState.MENU
	clear_game()
	clear_ui()
	var root := full_rect_control()
	ui_layer.add_child(root)
	add_dim_background(root, 0.82)
	var panel := PanelContainer.new()
	panel.position = Vector2(155, 48)
	panel.size = Vector2(970, 624)
	panel.add_theme_stylebox_override("panel", panel_style(Color("09162f"), 24, Color("70d7ff"), 2))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var eyebrow := make_label("序章 · 星渊救援队", 18, Color("70d7ff"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eyebrow)
	var title := make_label("把能量交给星灵，一起修好大灯塔", 38, Color("e8f5ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var story := make_label("天空中有许多星光岛。可爱的星灵住在岛上，帮助大家照明、送信、修路和赶走怪物。\n\n有一天，能量风暴让天穹大灯塔出了故障。道路被撕成不断变化的星渊，三位守门人也被错误指令控制。\n\n你是一名远征者。你的光弹不会伤害敌人，而会为星灵宠物补充能量。星灵吸满能量后，就会用自己的技能战斗。\n\n购买卡牌、排好宠物和规则的顺序，穿过六道安全门。和伙伴一起修好灯塔，让大家重新找到回家的路！", 21, Color("c7d7eb"))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(story)
	var begin := make_button("出发救援", Vector2(0, 58))
	begin.pressed.connect(func(): SaveManager.data.intro_seen = true; SaveManager.save(); start_game_after_prologue())
	box.add_child(begin)
	var back := make_button("暂时返回", Vector2(0, 46))
	back.pressed.connect(show_main_menu)
	box.add_child(back)

func show_story_archive(category := "主线纪事", selected_id := "") -> void:
	archive_category = category if category in StoryArchiveData.CATEGORIES else "主线纪事"
	if selected_id.is_empty():
		for candidate in StoryArchiveData.entries_for_category(archive_category):
			if story_entry_unlocked(candidate):
				selected_id = str(candidate.id)
				break
	if not selected_id.is_empty():
		var requested_entry: Dictionary = StoryArchiveData.get_entry(selected_id)
		if not requested_entry.is_empty() and story_entry_unlocked(requested_entry):
			SaveManager.mark_story_read(selected_id)
	state = GameState.MENU
	clear_game()
	clear_ui()
	var root := full_rect_control()
	ui_layer.add_child(root)
	add_dim_background(root, 0.88)
	var title := make_label("星渊故事书 · %d/%d 已解锁 · %d 未读" % [unlocked_story_ids().size(), StoryArchiveData.ENTRIES.size(), unread_story_count()], 29, Color("facc15"))
	title.position = Vector2(24, 10)
	title.size = Vector2(990, 42)
	root.add_child(title)
	var back := make_compact_button("返回主菜单", Vector2(216, 42))
	back.name = "ArchiveBack"
	back.position = Vector2(1040, 10)
	back.pressed.connect(show_main_menu)
	root.add_child(back)
	var tabs := HBoxContainer.new()
	tabs.name = "ArchiveTabs"
	tabs.position = Vector2(24, 68)
	tabs.size = Vector2(1232, 54)
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	var category_labels := {
		"主线纪事":"冒险故事",
		"人物志":"伙伴故事",
		"星灵谱":"宠物图鉴",
		"异象录":"怪物与规则",
		"遗物馆":"宝物图鉴"
	}
	for category_name in StoryArchiveData.CATEGORIES:
		var category_button := make_compact_button(str(category_labels.get(str(category_name), category_name)), Vector2(0, 42))
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.add_theme_font_size_override("font_size", 14)
		if str(category_name) == archive_category:
			category_button.add_theme_stylebox_override("normal", compact_panel_style(Color("3a2a50"), 10, Color("facc15"), 2))
		category_button.pressed.connect(show_story_archive.bind(str(category_name), ""))
		tabs.add_child(category_button)
	var list_panel := PanelContainer.new()
	list_panel.name = "ArchiveList"
	list_panel.anchor_bottom = 1.0
	list_panel.offset_left = 24
	list_panel.offset_top = 130
	list_panel.offset_right = 424
	list_panel.offset_bottom = -12
	list_panel.add_theme_stylebox_override("panel", panel_style(Color("0b1730"), 16, Color("355c91"), 2))
	root.add_child(list_panel)
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(list_scroll)
	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 7)
	list_scroll.add_child(list_box)
	var entries: Array = StoryArchiveData.entries_for_category(archive_category)
	var first_unlocked_id := ""
	for entry in entries:
		var unlocked: bool = story_entry_unlocked(entry)
		var id := str(entry.id)
		if unlocked and first_unlocked_id.is_empty():
			first_unlocked_id = id
		var unread: bool = unlocked and not id in SaveManager.data.story_read
		var label := ("● " if unread else "") + (str(entry.title) if unlocked else "未解锁记录")
		if not unlocked:
			label += "\n条件：%s" % str(entry.hint)
		else:
			label += "\n%s" % str(entry.subtitle)
		var entry_button := make_button(label, Vector2(340, 68))
		entry_button.disabled = not unlocked
		entry_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry_button.add_theme_font_size_override("font_size", 15)
		if unread:
			entry_button.add_theme_stylebox_override("normal", panel_style(Color("241c35"), 10, Color("c084fc"), 2))
		if unlocked:
			entry_button.pressed.connect(show_story_archive.bind(archive_category, id))
		list_box.add_child(entry_button)
	var detail_panel := PanelContainer.new()
	detail_panel.name = "ArchiveDetail"
	detail_panel.anchor_right = 1.0
	detail_panel.anchor_bottom = 1.0
	detail_panel.offset_left = 434
	detail_panel.offset_top = 130
	detail_panel.offset_right = -24
	detail_panel.offset_bottom = -12
	detail_panel.add_theme_stylebox_override("panel", panel_style(Color("0c1830"), 18, Color("244e78"), 2))
	root.add_child(detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(detail_box)
	var target_id := selected_id if not selected_id.is_empty() else first_unlocked_id
	var selected_entry: Dictionary = StoryArchiveData.get_entry(target_id)
	if selected_entry.is_empty() or not story_entry_unlocked(selected_entry):
		detail_box.add_child(make_label("继续完成成就，就能解锁这一篇冒险故事。", 23, Color("718bad")))
	else:
		var detail_title := make_label(str(selected_entry.title), 34, Color("e8f5ff"))
		detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_box.add_child(detail_title)
		detail_box.add_child(make_label(str(selected_entry.subtitle), 18, Color("70d7ff")))
		var separator := HSeparator.new()
		detail_box.add_child(separator)
		var content_scroll := ScrollContainer.new()
		content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		detail_box.add_child(content_scroll)
		var content := make_label(str(selected_entry.content), 20, Color("c7d7eb"))
		content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_scroll.add_child(content)
		detail_box.add_child(make_label("解锁条件：%s" % str(selected_entry.hint), 15, Color("718bad")))
		if target_id == "chronicle_origin":
			var replay := make_button("重看序章", Vector2(0, 42))
			replay.pressed.connect(show_story_prologue)
			detail_box.add_child(replay)

func show_main_menu() -> void:
	ensure_selected_character_unlocked()
	state = GameState.MENU
	clear_game()
	clear_ui()
	var root := full_rect_control()
	ui_layer.add_child(root)
	add_dim_background(root, 0.35)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_top", 54)
	margin.add_theme_constant_override("margin_bottom", 48)
	root.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 70)
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	var eyebrow := make_label("ROGUELITE  •  SURVIVOR", 17, Color("70d7ff"))
	left.add_child(eyebrow)
	var title := make_label("星渊\n幸存者", 76, Color("e8f5ff"))
	title.add_theme_constant_override("line_spacing", -12)
	left.add_child(title)
	var subtitle := make_label("给星灵宠物补充能量，一起穿过六关并修好大灯塔。", 21, Color("9bb4d1"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(subtitle)
	left.add_spacer(false)
	var stats_text := "成就 %d / %d   ·   每次远征都从零开始" % [SaveManager.data.achievements.size(), ACHIEVEMENTS.size()]
	left.add_child(make_label(stats_text, 18, Color("718bad")))
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(430, 0)
	right_panel.add_theme_stylebox_override("panel", panel_style(Color(0.035, 0.075, 0.14, 0.94), 22, Color("244e78"), 2))
	row.add_child(right_panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	right_panel.add_child(menu)
	menu.add_child(make_label("准备远征", 30, Color("f8fbff")))
	menu.add_child(make_label("当前角色：%s" % SaveManager.data.selected_character, 18, Color("70d7ff")))
	var start := make_button("开始游戏", Vector2(380, 66))
	start.pressed.connect(start_game)
	menu.add_child(start)
	var chars := make_button("选择角色")
	chars.pressed.connect(show_character_select)
	menu.add_child(chars)
	var help := make_button("玩法说明")
	help.pressed.connect(show_help)
	menu.add_child(help)
	var unread := unread_story_count()
	var archive := make_button("星渊故事书  ·  %d/%d%s" % [unlocked_story_ids().size(), StoryArchiveData.ENTRIES.size(), "  ·  %d篇新故事" % unread if unread > 0 else ""])
	archive.pressed.connect(show_story_archive)
	menu.add_child(archive)
	var achievements_button := make_button("成就墙  ·  %d/%d" % [SaveManager.data.achievements.size(), ACHIEVEMENTS.size()])
	achievements_button.pressed.connect(show_achievement_menu)
	menu.add_child(achievements_button)
	var sound := CheckButton.new()
	sound.text = "音效"
	sound.button_pressed = bool(SaveManager.data.settings.sound)
	sound.add_theme_font_size_override("font_size", 18)
	sound.toggled.connect(func(on: bool): SaveManager.data.settings.sound = on; SaveManager.save())
	menu.add_child(sound)
	menu.add_child(make_label("WASD / 方向键移动  ·  ESC 暂停", 15, Color("718bad")))

func show_character_select() -> void:
	clear_ui()
	var root := full_rect_control()
	ui_layer.add_child(root)
	add_dim_background(root, 0.86)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 70
	box.offset_right = -70
	box.offset_top = 8
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	var title := make_label("选择远征者", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var cards := GridContainer.new()
	cards.columns = 3
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 8)
	box.add_child(cards)
	var data := [
		["游侠", "精准供能", "供能弹更强更快\n开局弧牙，全部宠物伤害+10%", "66d9ff", "默认"],
		["骑士", "守护供能", "生命 +45、护甲 +3\n受击会为防御宠物补充能量", "ffbd69", "可用"],
		["星术师", "分流供能", "每枚供能弹携带更多能量\n开局拥有微弱光环", "c084fc", "可用"],
		["守卫", "阵地供能", "生命 +30、护甲 +2\n站稳后供能强度提高", "4ade80", "默认可用"],
		["影舞者", "移动供能", "高速移动时供能更频繁\n宠物暴击+20%，开局刃舞", "f472b6", "默认可用"],
		["星火使", "过热供能", "连续供能逐渐提高强度\n宠物伤害+5%、范围+15%", "fb923c", "默认可用"]
	]
	for info in data:
		var unlocked := is_character_unlocked(str(info[0]))
		var selected: bool = info[0] == SaveManager.data.selected_character
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(350, 210)
		var border_color := Color(info[3]) if unlocked else Color("344154")
		card.add_theme_stylebox_override("panel", compact_panel_style(Color("101d35"), 14, border_color, 3 if selected else 2))
		cards.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 3)
		card.add_child(content)
		var portrait := TextureRect.new()
		portrait.texture = make_character_portrait(info[0])
		portrait.custom_minimum_size = Vector2(250, 66)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.modulate = Color.WHITE if unlocked else Color(0.35, 0.4, 0.48, 1.0)
		content.add_child(portrait)
		var name_label := make_label("%s  ·  %s" % [info[0], info[1]], 14, Color(info[3]) if unlocked else Color("607086"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(name_label)
		var desc := make_label(info[2], 10, Color("b9cae0") if unlocked else Color("607086"))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(desc)
		var choose_text := "使用中" if selected else ("选择" if unlocked else character_unlock_text(str(info[0])))
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		content.add_child(actions)
		var choose := make_compact_button(choose_text, Vector2(216, 30))
		choose.add_theme_font_size_override("font_size", 11)
		choose.disabled = not unlocked or selected
		choose.pressed.connect(select_character.bind(info[0]))
		actions.add_child(choose)
		var journey_achievement: String = str({"游侠":"ranger_journey", "骑士":"knight_journey", "星术师":"mage_journey", "守卫":"guardian_journey", "影舞者":"dancer_journey", "星火使":"fire_journey"}.get(str(info[0]), ""))
		var lore := make_compact_button("档案", Vector2(68, 30))
		lore.add_theme_font_size_override("font_size", 11)
		lore.disabled = str(journey_achievement).is_empty() or not str(journey_achievement) in SaveManager.data.achievements
		if not lore.disabled:
			lore.pressed.connect(open_story_from_achievement.bind(str(journey_achievement)))
		actions.add_child(lore)
	var back := make_compact_button("返回", Vector2(250, 38))
	back.name = "CharacterBack"
	back.add_theme_font_size_override("font_size", 11)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_main_menu)
	box.add_child(back)

func select_character(character: String) -> void:
	if not is_character_unlocked(character):
		return
	SaveManager.data.selected_character = character
	SaveManager.save()
	show_main_menu()

func is_character_unlocked(character: String) -> bool:
	var achievement_id := str(CHARACTER_UNLOCK_ACHIEVEMENTS.get(character, "missing"))
	return achievement_id == "" or achievement_id in SaveManager.data.achievements

func character_unlock_text(character: String) -> String:
	var achievement_id := str(CHARACTER_UNLOCK_ACHIEVEMENTS.get(character, ""))
	for achievement in ACHIEVEMENTS:
		if achievement.id == achievement_id:
			return "成就解锁：%s" % achievement.name
	return "尚未解锁"

func character_unlocked_by_achievement(achievement_id: String) -> String:
	for character in CHARACTER_UNLOCK_ACHIEVEMENTS:
		if str(CHARACTER_UNLOCK_ACHIEVEMENTS[character]) == achievement_id:
			return str(character)
	return ""

func ensure_selected_character_unlocked() -> void:
	var selected := str(SaveManager.data.selected_character)
	if not is_character_unlocked(selected):
		SaveManager.data.selected_character = "游侠"
		SaveManager.save()

func show_help() -> void:
	clear_ui()
	var root := full_rect_control()
	ui_layer.add_child(root)
	add_dim_background(root, 0.9)
	var panel := PanelContainer.new()
	panel.position = Vector2(250, 65)
	panel.size = Vector2(780, 590)
	panel.add_theme_stylebox_override("panel", panel_style(Color("0c1830"), 22, Color("355c91"), 2))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(make_label("远征指南", 40, Color("70d7ff")))
	var guide := "移动：使用 WASD 或方向键。主角不会直接攻击敌人，而会自动向宠物发射供能弹。\n\n战斗：宠物吸收足够能量且攻击范围内有目标时释放技能；大多数宠物没有独立技能冷却。每次宠物释技都按卡组从左到右结算，相邻位置、标签与元素组合会形成星式。\n\n成长：蓝色星屑是商店货币。宠物与规则卡进入卡组；角色训练购买后立即消耗，只提高基础属性且不占卡槽，角色专精属性收益更高。\n\n威胁：敌群会随时间变强；完成六关主线后，可以胜利结算，也可以继续进入无尽挑战。\n\n构筑：卡组卡牌最多7张；槽满时可出售替换，也可以放弃购买。组合、进化、训练与Boss遗物只在本局生效。\n\n公平远征：没有局外属性养成；成就负责解锁角色与故事档案。"
	var text := make_label(guide, 20, Color("c7d7eb"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	var back := make_button("明白了", Vector2(720, 58))
	back.pressed.connect(show_main_menu)
	box.add_child(back)

func show_achievement_menu() -> void:
	clear_ui()
	var root := full_rect_control()
	ui_layer.add_child(root)
	add_dim_background(root, 0.88)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 110
	panel.offset_right = -110
	panel.offset_top = 30
	panel.offset_bottom = -30
	panel.add_theme_stylebox_override("panel", panel_style(Color("0c1830"), 22, Color("facc15"), 2))
	root.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	outer.add_child(make_label("星渊成就墙  ·  已解锁 %d/%d" % [SaveManager.data.achievements.size(), ACHIEVEMENTS.size()], 28, Color("facc15")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(make_label("所有成就只记录挑战，不提供永久属性加成。", 18, Color("70d7ff")))
	for achievement in ACHIEVEMENTS:
		var earned: bool = achievement.id in SaveManager.data.achievements
		var linked_stories := story_ids_for_achievement(str(achievement.id))
		var link_note := "  ·  点击查看档案" if earned and not linked_stories.is_empty() else ""
		var badge := make_button(("★ " if earned else "☆ ") + (achievement.name if earned else "未解锁成就") + link_note + "\n" + (achievement.desc if earned else "条件：" + achievement.source), Vector2(0, 68))
		badge.disabled = not earned or linked_stories.is_empty()
		badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		badge.add_theme_font_size_override("font_size", 16)
		var badge_style := panel_style(Color("221944") if earned else Color("101827"), 12, Color("c084fc") if earned else Color("344154"), 2)
		badge.add_theme_stylebox_override("normal", badge_style)
		badge.add_theme_stylebox_override("disabled", badge_style)
		badge.add_theme_color_override("font_disabled_color", Color("f1eaff") if earned else Color("718bad"))
		if earned and not linked_stories.is_empty():
			badge.pressed.connect(open_story_from_achievement.bind(str(achievement.id)))
		box.add_child(badge)
	var back := make_button("返回主菜单", Vector2(0, 48))
	back.pressed.connect(show_main_menu)
	outer.add_child(back)

func start_game_after_prologue() -> void:
	ensure_selected_character_unlocked()
	clear_game()
	state = GameState.PLAYING
	finished_run = false
	elapsed = 0.0
	spawn_timer = 0.2
	pulse_timer = 0.0
	star_shards = 0
	total_star_shards = 0
	spent_star_shards = 0
	kills = 0
	boss_kills = 0
	damage_taken_this_run = 0.0
	pending_boss_rewards.clear()
	mainline_completion_pending = false
	run_achievement_start_count = SaveManager.data.achievements.size()
	run_new_story_ids.clear()
	narrative_seen.clear()
	pending_story_toast = ""
	boss_spawned.clear()
	boss_warned.clear()
	endless_mode = false
	endless_elapsed = 0.0
	endless_wave = 1
	next_endless_boss_wave = 3
	upgrade_levels.clear()
	card_slots = STARTING_CARD_SLOTS
	equipped_cards.clear()
	core_engine_level = 0
	combo_catalyst_level = 0
	next_shop_time = FIRST_SHOP_TIME
	shop_pending = false
	queued_shops = 0
	boss_engaged_since = -1.0
	shop_visit = 0
	shop_goods.clear()
	shop_reroll_count = 0
	pending_shop_offer = -1
	pending_shop_price = 0
	red_contract_stacks = 0
	green_momentum_stacks = 0
	campfire_stacks = 0
	core_hit_counts.clear()
	core_mastery_ranks.clear()
	core_mastery_progress.clear()
	core_mastery_last_event.clear()
	shop_purchases_this_visit = 0
	forge_purchases = 0
	active_hand_multiplier = 1.0
	resonance = 0.0
	wave_resonance_generated = 0.0
	last_hand_energy = 0
	last_hand_patterns.clear()
	hands_played = 0
	card_cast_counts.clear()
	active_vouchers.clear()
	consumable_sigils.clear()
	card_seals.clear()
	card_drawbacks.clear()
	pattern_mastery.clear()
	star_bridge_hands = 0
	pet_insurance_used = false
	insured_pet_mastery.clear()
	pending_drawback_id = ""
	rental_debt = 0
	cleanse_ward_charges = 0
	wave_goal.clear()
	danger_contract.clear()
	guaranteed_reward_pack = false
	booster_overlay = null
	pet_energy.clear()
	effect_pool.clear()
	pet_link_broken.clear()
	pet_link_grace.clear()
	enemy_cut_cooldown.clear()
	last_energy_pet = ""
	guardian_stationary_time = 0.0
	fire_energy_heat = 0.0
	stats = {
		"damage": 1.0,
		"cooldown": 1.0,
		"area": 1.0,
		"crit": 0.05,
		"magnet": 150.0,
		"luck": 0.0,
		"energy_power": 1.0
	}
	has_aura = false
	has_orbit = false
	aura_radius = 105.0
	orbit_count = 1
	chain_level = 0
	nova_level = 0
	evolutions = {}
	aura_ignite = false
	momentum_enabled = false
	streak_count = 0
	streak_timer = 0.0
	surge_pulses = 0
	phase_step_enabled = false
	phase_step_cooldown = 0.0
	thunder_level = 0
	soul_siphon_level = 0
	gravity_level = 0
	blade_level = 0
	meteor_level = 0
	aegis_level = 0
	aegis_timer = 0.0
	execute_enabled = false
	active_relics = {}
	skill_entities = {}
	card_editions = {}
	card_runtime_values = {}
	last_chain_multiplier = 1.0
	last_hurt_elapsed = -99.0
	conditional_speed_bonus = 0.0
	conditional_armor_bonus = 0.0
	echo_pending = {}
	echo_damage_captures = {}
	boss_card_disruptions = {}
	boss_shuffle_original = []
	boss_shuffle_remaining = 0.0
	boss_shuffle_source = null
	boss_affix_pending = false
	directed_shop_pending = false
	boss_reward_overlay = null
	mainline_complete_overlay = null
	bonus_crit_damage = 0.0
	burn_burst = false
	entity_root = Node2D.new()
	entity_root.name = "Entities"
	entity_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(entity_root)
	projectile_root = Node2D.new()
	projectile_root.name = "Projectiles"
	projectile_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(projectile_root)
	pickup_root = Node2D.new()
	pickup_root.name = "Pickups"
	pickup_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pickup_root)
	visual_root = Node2D.new()
	visual_root.name = "Visuals"
	visual_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(visual_root)
	hazard_root = Node2D.new()
	hazard_root.name = "Hazards"
	hazard_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hazard_root)
	player = PlayerScript.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector2.ZERO
	add_child(player)
	player.setup(str(SaveManager.data.selected_character))
	player.died.connect(end_run.bind(false))
	player.health_changed.connect(on_health_changed)
	player.hurt.connect(on_player_hurt)
	player.healed.connect(on_player_healed)
	player.shield_blocked.connect(on_player_shield_blocked)
	# 单只宠物撑不住 360 度的压力：它只覆盖一个距离段，玩家一转身就空转。
	# 每个角色开局配两只互补的宠物，既是开局强度的正解，也让「组队」从第一秒成立。
	match player.character_name:
		"游侠": stats.damage *= 1.1
		"影舞者":
			stats.crit += 0.20
			stats.cooldown *= 0.9
		"星火使":
			stats.area *= 1.15
			stats.damage *= 1.05
	for starting_pet_id in STARTING_PETS.get(player.character_name, ["aura"]):
		var pet_id := str(starting_pet_id)
		upgrade_levels[pet_id] = 1
		equipped_cards.append(pet_id)
	for starting_pet_id in active_core_skill_ids():
		award_pet_meeting_achievement(starting_pet_id)
	stats.crit = minf(0.85, float(stats.crit))
	award_character_achievement(player.character_name)
	refresh_derived_card_effects()
	weapon_visual = WeaponVisualScript.new()
	weapon_visual.owner_player = player
	weapon_visual.game = self
	visual_root.add_child(weapon_visual)
	var tether_view: PetTetherView = PetTetherViewScript.new()
	tether_view.owner_player = player
	tether_view.game = self
	tether_view.z_index = 2
	visual_root.add_child(tether_view)
	refresh_skill_entities()
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	build_hud()
	show_toast("第一关 · 迷路的领航员\n%s" % character_opening_line(player.character_name), Color("70d7ff"), 3.0)
	play_tone(440, 0.12, 0.2)

func build_hud() -> void:
	clear_ui()
	skill_tooltip = null
	deck_card_cache = {}
	deck_empty_slots.clear()
	deck_card_row = null
	hud = full_rect_control()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud)
	var top := PanelContainer.new()
	top.position = Vector2(24, 20)
	top.size = Vector2(1232, 78)
	top.add_theme_stylebox_override("panel", panel_style(Color(0.025, 0.055, 0.11, 0.88), 15, Color(0.18, 0.38, 0.62, 0.75), 2))
	hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	top.add_child(row)
	time_label = make_label("下个Boss 01:00", 22, Color("f8fbff"))
	time_label.custom_minimum_size.x = 170
	row.add_child(time_label)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bars)
	var health_stack := Control.new()
	health_stack.custom_minimum_size.y = 24
	bars.add_child(health_stack)
	hp_lag_bar = ProgressBar.new()
	hp_lag_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_lag_bar.max_value = player.max_health
	hp_lag_bar.value = player.health
	hp_lag_bar.show_percentage = false
	hp_lag_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_lag_bar.add_theme_stylebox_override("background", panel_style(Color("291a35"), 6))
	hp_lag_bar.add_theme_stylebox_override("fill", panel_style(Color("ff9f43"), 6))
	health_stack.add_child(hp_lag_bar)
	hp_bar = ProgressBar.new()
	hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.max_value = player.max_health
	if is_instance_valid(hp_lag_bar):
		hp_lag_bar.max_value = player.max_health
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	hp_bar.add_theme_stylebox_override("fill", panel_style(Color("ef476f"), 6))
	health_stack.add_child(hp_bar)
	displayed_health = player.health
	active_hand_label = null
	resonance_bar = null
	level_label = make_label("◆ 星屑 0", 20, Color("facc15"))
	level_label.custom_minimum_size.x = 126
	row.add_child(level_label)
	kill_label = make_label("击败 0", 20, Color("c7d7eb"))
	kill_label.custom_minimum_size.x = 100
	row.add_child(kill_label)
	boss_label = make_label("", 20, Color("facc15"))
	boss_label.position = Vector2(220, 112)
	boss_label.size = Vector2(840, 66)
	boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var passive_panel := PanelContainer.new()
	passive_panel.name = "PassivePanel"
	passive_panel.position = Vector2(922, 112)
	passive_panel.size = Vector2(258, 86)
	passive_panel.add_theme_stylebox_override("panel", compact_panel_style(Color(0.025, 0.055, 0.11, 0.92), 12, player.color, 2))
	hud.add_child(passive_panel)
	var passive_row := HBoxContainer.new()
	passive_row.add_theme_constant_override("separation", 8)
	passive_panel.add_child(passive_row)
	var passive_icon := TextureRect.new()
	passive_icon.name = "PassiveIcon"
	passive_icon.texture = make_character_passive_icon(player.character_name)
	passive_icon.custom_minimum_size = Vector2(58, 58)
	passive_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	passive_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	passive_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	passive_row.add_child(passive_icon)
	var passive_box := VBoxContainer.new()
	passive_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passive_box.alignment = BoxContainer.ALIGNMENT_CENTER
	passive_box.add_theme_constant_override("separation", 0)
	passive_row.add_child(passive_box)
	passive_box.add_child(make_label("%s · 固有特性" % player.character_name, 13, player.color))
	var passive_descriptions := {
		"游侠":"高效供能 · 宠物伤害+10% · 初始弧牙",
		"骑士":"受击补能 · 生命+45 护甲+3",
		"星术师":"高密度供能 · 微光环",
		"守卫":"站稳后供能+35% · 双卫星",
		"影舞者":"移动供能加快 · 宠物暴击+20% · 初始刃舞",
		"星火使":"连续供能升温 · 宠物伤害+5% 范围+15%"
	}
	var passive_note := make_label(str(passive_descriptions.get(player.character_name, "")), 8, Color("c7d7eb"))
	passive_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	passive_box.add_child(passive_note)
	var deck_panel := PanelContainer.new()
	deck_panel.position = Vector2(24, 535)
	deck_panel.size = Vector2(930, 175)
	deck_panel.add_theme_stylebox_override("panel", compact_panel_style(Color(0.025, 0.055, 0.11, 0.94), 14, Color("facc15"), 2))
	hud.add_child(deck_panel)
	var deck_box := VBoxContainer.new()
	deck_box.add_theme_constant_override("separation", 4)
	deck_panel.add_child(deck_box)
	deck_status_label = make_label("宠物伤害＝基础值 × 基础伤害 × 左侧加算 × 右侧乘算 × 暴击/版本", 11, Color("facc15"))
	deck_box.add_child(deck_status_label)
	deck_card_row = HBoxContainer.new()
	deck_card_row.add_theme_constant_override("separation", 6)
	deck_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_box.add_child(deck_card_row)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(boss_label)
	mode_label = make_label("主线远征 · 关卡 1/6", 18, Color("c7d7eb"))
	mode_label.position = Vector2(24, 112)
	mode_label.size = Vector2(260, 36)
	hud.add_child(mode_label)
	toast_label = make_label("", 28)
	toast_label.position = Vector2(270, 425)
	toast_label.size = Vector2(700, 102)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.modulate.a = 0.0
	hud.add_child(toast_label)
	var pause_button := make_button("Ⅱ", Vector2(52, 52))
	pause_button.position = Vector2(1190, 112)
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.pressed.connect(show_pause)
	hud.add_child(pause_button)

func update_hud() -> void:
	if not is_instance_valid(hud) or not is_instance_valid(player):
		return
	time_label.text = "Boss %s" % next_boss_time()
	level_label.text = "◆ 星屑 %d" % star_shards
	kill_label.text = "击败 %d" % kills
	hp_bar.max_value = player.max_health
	hp_bar.value = player.health
	if is_instance_valid(resonance_bar):
		resonance_bar.value = resonance
	if is_instance_valid(active_hand_label):
		var ready_text := "发射" if pulse_timer <= 0.01 else "供能 %.1fs" % pulse_timer
		active_hand_label.text = "主角供能 · %s · 共鸣%d%%" % [ready_text, int(resonance)]
		if lone_star_protocol_active():
			active_hand_label.text += " · 孤星星火"
	var bosses_left := 6 - boss_kills
	var active_bosses := get_tree().get_nodes_in_group("bosses")
	check_boss_story_beats(active_bosses)
	boss_label.visible = active_bosses.size() > 0
	if active_bosses.size() > 0:
		boss_label.text = "◆ %s · %s ◆" % [active_bosses[0].kind, active_bosses[0].affix_summary()]
		var disruption_text := boss_disruption_summary()
		if not disruption_text.is_empty():
			boss_label.text += "\n%s" % disruption_text
	else:
		boss_label.text = ""
	if endless_mode:
		mode_label.text = "♾ 无尽挑战 · 第 %d 波" % endless_wave
		mode_label.add_theme_color_override("font_color", Color("f472b6"))
	else:
		var chapter := current_mainline_chapter()
		mode_label.text = "主线远征 · 第%d章/6 · %s" % [chapter, chapter_theme_name(chapter)]
		mode_label.add_theme_color_override("font_color", Color("c7d7eb"))
	if lone_star_protocol_active():
		mode_label.text += " · 孤星协议"
		mode_label.add_theme_color_override("font_color", Color("70d7ff"))
	if not danger_contract.is_empty():
		mode_label.text += " · 危险契约 %d/%d" % [maxi(0, kills - int(danger_contract.kills)), int(danger_contract.target)]
		mode_label.add_theme_color_override("font_color", Color("ef476f"))
	elif not wave_goal.is_empty():
		var goal_progress := wave_resonance_generated
		if str(wave_goal.type) == "kills": goal_progress = kills - int(wave_goal.start)
		elif str(wave_goal.type) == "hands": goal_progress = hands_played - int(wave_goal.start)
		mode_label.text += " · %s %d/%d" % [str(wave_goal.name), mini(int(goal_progress), int(wave_goal.target)), int(wave_goal.target)]
	update_skill_list()
	check_achievement_progress()

func update_skill_list() -> void:
	if is_instance_valid(deck_status_label):
		deck_status_label.text = "宠物伤害＝基础值 × 基础伤害 × 左侧加算 × 右侧乘算 × 暴击/版本　当前有效倍率×%.2f　共鸣 %d/%d" % [last_chain_multiplier, int(resonance), int(MAX_RESONANCE)]
	update_deck_card_row()

func update_deck_card_row() -> void:
	if not is_instance_valid(deck_card_row):
		return
	for cached_id in deck_card_cache.keys():
		if not equipped_cards.has(str(cached_id)):
			var stale_card = deck_card_cache[cached_id]
			if is_instance_valid(stale_card):
				stale_card.free()
			deck_card_cache.erase(cached_id)
	for index in equipped_cards.size():
		var id := equipped_cards[index]
		if not deck_card_cache.has(id):
			var card: DeckCardView = DeckCardViewScript.new()
			deck_card_row.add_child(card)
			deck_card_cache[id] = card
			card.tooltip_requested.connect(show_skill_tooltip)
			card.tooltip_hidden.connect(hide_skill_tooltip)
			card.swap_requested.connect(swap_equipped_cards)
		var card: DeckCardView = deck_card_cache[id]
		deck_card_row.move_child(card, index)
		var cd := skill_cooldown_data(id)
		var rarity := card_rarity(id)
		var control_state := core_pet_control_state(id)
		var description := skill_description(id)
		var deck_drawback := card_drawback_description(id)
		if not deck_drawback.is_empty():
			description += "\n\n" + deck_drawback
		var display_title := card_display_name(id)
		if id in CORE_SKILL_CARD_IDS:
			display_title += " ★%d" % core_mastery_rank(id)
		match control_state:
			"sealed": description += "\n\n【封印中】暂时不参与结算；击败5名敌人可提前解除。"
			"stolen": description += "\n\n【被盗】暂时不释放技能；靠近Boss身边的宠物可夺回。"
			"charmed": description += "\n\n【被魅惑】暂时倒戈发射敌弹；靠近宠物可净化。"
		card.set_card(id, make_skill_icon(id), display_title, maxi(1, int(upgrade_levels.get(id, 0))), index + 1, float(cd.remaining), float(cd.total), description, card_order_rule_text(id), rarity, CARD_RARITY_COLORS.get(rarity, Color("9bb4d1")))
		match control_state:
			"sealed": card.modulate = Color("8f719f")
			"stolen": card.modulate = Color("ef6b6b")
			"charmed": card.modulate = Color("f08ac1")
			_: card.modulate = Color.WHITE
	var needed_empty := maxi(0, card_slots - equipped_cards.size())
	while deck_empty_slots.size() < needed_empty:
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(116, 126)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_stylebox_override("panel", panel_style(Color(0.035, 0.06, 0.11, 0.64), 9, Color("344154"), 2))
		var text := make_label("空槽", 14, Color("607086"))
		text.name = "EmptyText"
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(text)
		deck_card_row.add_child(empty)
		deck_empty_slots.append(empty)
	while deck_empty_slots.size() > needed_empty:
		var empty: Control = deck_empty_slots.pop_back()
		if is_instance_valid(empty):
			empty.free()
	for empty_index in deck_empty_slots.size():
		var empty := deck_empty_slots[empty_index]
		deck_card_row.move_child(empty, equipped_cards.size() + empty_index)
		var label := empty.get_node_or_null("EmptyText") as Label
		if label:
			label.text = "空槽\n#%d" % (equipped_cards.size() + empty_index + 1)

func active_core_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for id in equipped_cards:
		if id in CORE_SKILL_CARD_IDS and (is_card_active(id) or core_pet_control_state(id) in ["stolen", "charmed"]):
			result.append(id)
	return arrange_core_pet_formation(result)

func equipped_pet_count() -> int:
	var count := 0
	for id in equipped_cards:
		if id in CORE_SKILL_CARD_IDS:
			count += 1
	return count

func is_sustainable_offense_pet(id: String) -> bool:
	# 处决无法从满血自行启动，护盾不产生伤害；引力奇点现在会造成范围伤害。
	return id in CORE_SKILL_CARD_IDS and not id in ["aegis", "execute"]

func has_sustainable_offense_pet() -> bool:
	for id in equipped_cards:
		if is_sustainable_offense_pet(id):
			return true
	return false

func lone_star_protocol_active() -> bool:
	# Boss的临时封印不触发保底，避免绕过其干扰机制。
	return state == GameState.PLAYING and not has_sustainable_offense_pet()

func arrange_core_pet_formation(active_ids: Array[String]) -> Array[String]:
	# Combo partners stand next to one another in the pet formation without
	# changing the player's actual left-to-right card resolution order.
	var arranged: Array[String] = []
	var groups := [
		["aura", "orbit", "satellite_engine"],
		["chain", "thunder_orb"],
		["gravity_well", "nova"],
		["phase_step", "blade_dance"]
	]
	for group in groups:
		var present: Array[String] = []
		for id in group:
			if active_ids.has(str(id)):
				present.append(str(id))
		if present.size() >= 2:
			for id in present:
				if not arranged.has(id):
					arranged.append(id)
	for id in active_ids:
		if not arranged.has(id):
			arranged.append(id)
	return arranged

func refresh_skill_entities() -> void:
	if not is_instance_valid(visual_root) or not is_instance_valid(player):
		return
	var active_ids := active_core_skill_ids()
	for cached_id in skill_entities.keys():
		if not active_ids.has(str(cached_id)):
			var stale = skill_entities[cached_id]
			if is_instance_valid(stale):
				stale.queue_free()
			skill_entities.erase(cached_id)
			pet_energy.erase(cached_id)
	for index in active_ids.size():
		var id := active_ids[index]
		if not pet_energy.has(id):
			pet_energy[id] = 0.0
		if not skill_entities.has(id):
			var entity: SkillEntity = SkillEntityScript.new()
			visual_root.add_child(entity)
			entity.global_position = player.global_position
			entity.setup(id, player, self, index, active_ids.size())
			skill_entities[id] = entity
		else:
			var entity: SkillEntity = skill_entities[id]
			entity.set_formation(index, active_ids.size())

func pet_hunt_target() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	var target := preferred_enemy_from(player.global_position, MAX_ENGAGE_RANGE)
	return target.global_position if is_instance_valid(target) else Vector2.ZERO

func skill_entity_origin(id: String) -> Vector2:
	var entity = skill_entities.get(id)
	if is_instance_valid(entity):
		return entity.global_position
	return player.global_position if is_instance_valid(player) else Vector2.ZERO

func orbit_pet_source_id() -> String:
	for id in equipped_cards:
		if id in ["orbit", "satellite_engine", "blade_dance"] and is_card_active(id):
			return id
	return "orbit"

func release_skill_entity(id: String, target_position := Vector2.ZERO, trigger_echo := true) -> void:
	var entity = skill_entities.get(id)
	if is_instance_valid(entity):
		entity.release_toward(target_position)
		if target_position != Vector2.ZERO:
			var direction: Vector2 = (target_position - entity.global_position).normalized()
			var distance: float = entity.global_position.distance_to(target_position)
			spawn_skill_effect(entity.global_position, "cast", entity.entity_color(), distance, direction)
	if trigger_echo and str(card_editions.get(id, "")) == "echo":
		var captured_damage: Array[Dictionary] = []
		echo_damage_captures[id] = captured_damage
		echo_pending[id] = int(echo_pending.get(id, 0)) + 1
		echo_skill_after_delay(id, target_position, captured_damage)

func echo_skill_after_delay(id: String, target_position: Vector2, captured_damage: Array[Dictionary]) -> void:
	await get_tree().create_timer(0.28, true).timeout
	var pending_count := maxi(0, int(echo_pending.get(id, 1)) - 1)
	if pending_count > 0:
		echo_pending[id] = pending_count
	else:
		echo_pending.erase(id)
	if state != GameState.PLAYING or not equipped_cards.has(id) or not is_instance_valid(player):
		return
	var center := target_position if target_position != Vector2.ZERO else player.global_position
	var entity = skill_entities.get(id)
	if is_instance_valid(entity):
		entity.release_toward(center)
	for record in captured_damage:
		var target = record.get("target")
		if is_instance_valid(target):
			target.take_damage(float(record.get("damage", 0.0)) * 0.55, Vector2.ZERO, "echo")
	spawn_skill_effect(center, "nova", Color("e8f5ff"), 72.0 * skill_area_multiplier(id))
	show_toast("回响 · %s再次触发" % card_display_name(id), Color("e8f5ff"), 0.45)

func swap_equipped_cards(source_id: String, target_id: String) -> void:
	if boss_shuffle_remaining > 0.0:
		show_toast("逆序洗牌期间无法调整卡序", Color("facc15"), 0.7)
		return
	var source_index := equipped_cards.find(source_id)
	var target_index := equipped_cards.find(target_id)
	if source_index < 0 or target_index < 0 or source_index == target_index:
		return
	var moved_id := equipped_cards[source_index]
	equipped_cards[source_index] = equipped_cards[target_index]
	equipped_cards[target_index] = moved_id
	show_toast("卡牌顺序已调整 · 从左到右重新结算", Color("facc15"), 0.7)
	update_deck_card_row()

func skill_description(id: String) -> String:
	for upgrade in UPGRADES:
		if upgrade.id == id:
			if is_training_card(id):
				return "%s\n当前角色收益：【%s】\n购买后立即使用，不占卡槽。" % [str(upgrade.desc), training_gain_preview(id)]
			var effect := "%s\n作用范围：【%s】" % [str(upgrade.desc), card_effect_scope(id)]
			if id in CORE_SKILL_CARD_IDS and CORE_MASTERY_RULES.has(id):
				var rule: Dictionary = CORE_MASTERY_RULES[id]
				var rank := core_mastery_rank(id)
				var progress_text := "已满级" if rank >= CORE_MASTERY_MAX_RANK else "%d/%d" % [int(core_mastery_progress.get(id, 0)), core_mastery_requirement(id)]
				var release_rule := "独立冷却%.2f秒" % PHASE_STEP_COOLDOWN if id == "phase_step" else "无技能冷却"
				return "%s\n供能需求：%.1f · 充满后释放，%s\n升级条件：%s（★%d · %s）" % [effect, pet_energy_requirement(id), release_rule, str(rule.condition), rank, progress_text]
			return effect
	match id:
		"aura": return "自动伤害宠物周围的敌人。\n作用范围：【以暮环为中心】"
		"orbit": return "自动释放卫星攻击宠物附近的敌人。\n作用范围：【以环尾为中心】"
		"endless_damage": return "宠物后置增伤，最高×1.50。\n作用范围：【对应宠物右侧全部】"
		"endless_vitality": return "4秒未受伤后持续恢复生命。\n作用范围：【全局】"
		"endless_haste": return "被群敌包围时加速技能与移动。\n作用范围：【全局】"
	return id

func core_mastery_rank(id: String) -> int:
	return clampi(int(core_mastery_ranks.get(id, 0)), 0, CORE_MASTERY_MAX_RANK)

func core_mastery_requirement(id: String) -> int:
	if not CORE_MASTERY_RULES.has(id):
		return 0
	var base := int(CORE_MASTERY_RULES[id].base)
	return base + int(ceil(float(base) * 0.35 * core_mastery_rank(id)))

func record_core_mastery(id: String, amount := 1) -> void:
	if amount <= 0 or not CORE_MASTERY_RULES.has(id) or not equipped_cards.has(id) or is_card_suppressed(id):
		return
	var rank := core_mastery_rank(id)
	if rank >= CORE_MASTERY_MAX_RANK:
		return
	var rule: Dictionary = CORE_MASTERY_RULES[id]
	var last_event := float(core_mastery_last_event.get(id, -99.0))
	if elapsed - last_event < float(rule.gap):
		return
	core_mastery_last_event[id] = elapsed
	var progress := int(core_mastery_progress.get(id, 0)) + amount
	var ranked_up := false
	while rank < CORE_MASTERY_MAX_RANK:
		var needed := int(rule.base) + int(ceil(float(rule.base) * 0.35 * rank))
		if progress < needed:
			break
		progress -= needed
		rank += 1
		ranked_up = true
	core_mastery_ranks[id] = rank
	core_mastery_progress[id] = 0 if rank >= CORE_MASTERY_MAX_RANK else progress
	if ranked_up:
		show_toast("条件养成完成 · %s ★%d\n%s" % [card_display_name(id), rank, str(rule.bonus)], Color("facc15"), 1.8)
		spawn_skill_effect(skill_entity_origin(id), "nova", Color("facc15"), 62.0 + rank * 5.0)
		play_tone(720.0 + rank * 45.0, 0.12, 0.18)
		if str(card_seals.get(id, "")) == "gold":
			gain_star_shards(2)
			show_toast("金蜡封回响 · 获得◆2", Color("facc15"), 0.8)
	update_skill_list()

func core_mastery_damage_factor(id: String) -> float:
	return 1.0 + core_mastery_rank(id) * 0.08 if id in CORE_SKILL_CARD_IDS else 1.0

func core_mastery_area_factor(id: String) -> float:
	return 1.0 + core_mastery_rank(id) * (0.05 if id == "gravity_well" else 0.04) if id in ["aura", "nova", "thunder_orb", "gravity_well", "meteor_rain"] else 1.0

func is_training_card(id: String) -> bool:
	return id in TRAINING_CARD_IDS

func is_slot_card(id: String) -> bool:
	if is_training_card(id):
		return false
	if id in ENDLESS_CARD_IDS:
		return true
	for upgrade in UPGRADES:
		if str(upgrade.id) == id:
			# 角色创建时的固有被动不在卡池中；商店内的角色专属牌仍占槽。
			return true
	return false

func is_card_suppressed(id: String) -> bool:
	return boss_card_disruptions.has(id)

func core_pet_control_state(id: String) -> String:
	if not boss_card_disruptions.has(id):
		return "normal"
	return str(boss_card_disruptions[id].get("mode", "sealed"))

func core_pet_control_target(id: String):
	if not boss_card_disruptions.has(id):
		return null
	return boss_card_disruptions[id].get("source")

func is_card_active(id: String) -> bool:
	if is_card_suppressed(id):
		return false
	if not is_slot_card(id):
		return true
	if equipped_cards.has(id):
		return true
	if active_relics.has("ember_vessel") and id == "burn":
		return true
	if id == "aura" and (int(upgrade_levels.get("knight_bulwark", 0)) > 0 or int(upgrade_levels.get("fire_rite", 0)) > 0):
		return true
	if id == "orbit" and int(upgrade_levels.get("guardian_bastion", 0)) > 0:
		return true
	return false

func refresh_derived_card_effects() -> void:
	if not is_instance_valid(player):
		return
	var aura_level := int(upgrade_levels.get("aura", 0)) if equipped_cards.has("aura") else 0
	var orbit_level := int(upgrade_levels.get("orbit", 0)) if equipped_cards.has("orbit") else 0
	var satellite_level := int(upgrade_levels.get("satellite_engine", 0)) if equipped_cards.has("satellite_engine") else 0
	var blade_card_level := int(upgrade_levels.get("blade_dance", 0)) if equipped_cards.has("blade_dance") else 0
	var knight_passive := int(upgrade_levels.get("knight_bulwark", 0)) > 0
	var ranger_passive := int(upgrade_levels.get("ranger_focus", 0)) > 0
	var mage_passive := int(upgrade_levels.get("mage_prism", 0)) > 0
	var guardian_passive := int(upgrade_levels.get("guardian_bastion", 0)) > 0
	var dancer_passive := int(upgrade_levels.get("dancer_execution", 0)) > 0
	var fire_passive := int(upgrade_levels.get("fire_rite", 0)) > 0
	aura_radius = 168.0
	if player.character_name == "星术师":
		aura_radius = 132.0
	elif player.character_name == "星火使":
		aura_radius = 205.0
	if knight_passive:
		aura_radius += 32.0
	if mage_passive:
		aura_radius += 20.0
	has_aura = aura_level > 0 or knight_passive or fire_passive
	aura_ignite = fire_passive
	has_orbit = orbit_level > 0 or satellite_level > 0 or blade_card_level > 0 or guardian_passive
	# 必须逐张累加：用 maxi 取最大值会让「再买一张环类宠物」完全不增加卫星。
	orbit_count = 1
	if orbit_level > 0:
		orbit_count += 1
	if satellite_level > 0:
		orbit_count += 1
	if blade_card_level > 0:
		orbit_count += 1
	if guardian_passive:
		orbit_count += 2
	chain_level = int(upgrade_levels.get("chain", 0)) if equipped_cards.has("chain") else 0
	if ranger_passive and chain_level > 0:
		chain_level += 1
	thunder_level = int(upgrade_levels.get("thunder_orb", 0)) if equipped_cards.has("thunder_orb") else 0
	nova_level = int(upgrade_levels.get("nova", 0)) if equipped_cards.has("nova") else 0
	soul_siphon_level = int(upgrade_levels.get("soul_siphon", 0)) if equipped_cards.has("soul_siphon") else 0
	gravity_level = int(upgrade_levels.get("gravity_well", 0)) if equipped_cards.has("gravity_well") else 0
	blade_level = blade_card_level
	meteor_level = int(upgrade_levels.get("meteor_rain", 0)) if equipped_cards.has("meteor_rain") else 0
	aegis_level = int(upgrade_levels.get("aegis", 0)) if equipped_cards.has("aegis") else 0
	phase_step_enabled = equipped_cards.has("phase_step")
	execute_enabled = equipped_cards.has("execute")
	momentum_enabled = equipped_cards.has("momentum") or dancer_passive
	core_engine_level = int(upgrade_levels.get("core_engine", 0)) if equipped_cards.has("core_engine") else 0
	combo_catalyst_level = int(upgrade_levels.get("combo_catalyst", 0)) if equipped_cards.has("combo_catalyst") else 0
	card_slots = MAX_CARD_SLOTS if equipped_cards.has("card_slot") else STARTING_CARD_SLOTS
	var fragile_count := 0
	for drawback_card_id in equipped_cards:
		if str(card_drawbacks.get(drawback_card_id, "")) == "fragile":
			fragile_count += 1
	player.incoming_damage_multiplier = pow(1.18, fragile_count)
	if evolutions.has("molten_circuit") and not (is_card_active("burn") and is_card_active("chain")):
		evolutions.erase("molten_circuit")
	if evolutions.has("stellar_lattice") and not (is_card_active("aura") and (is_card_active("orbit") or is_card_active("satellite_engine"))):
		evolutions.erase("stellar_lattice")
	refresh_skill_entities()
	if not has_sustainable_offense_pet():
		directed_shop_pending = true

func remove_slot_card_effect(id: String) -> void:
	if id in CORE_SKILL_CARD_IDS:
		core_mastery_ranks.erase(id)
		core_mastery_progress.erase(id)
		core_mastery_last_event.erase(id)
	var card_level := int(upgrade_levels.get(id, 0))
	if card_level > 0:
		match id:
			"damage", "cooldown", "speed", "health", "armor", "regen", "projectile", "pierce", "area", "crit", "magnet": pass
			"glass":
				var restored_health := float(card_runtime_values.get(id, 20.0 * card_level))
				player.max_health += restored_health
				player.health_changed.emit(player.health, player.max_health)
			"gamble":
				player.armor += 2.0 * card_level
			"ranger_focus":
				pass
			"knight_bulwark":
				player.armor -= 2.0
			"mage_prism":
				pass
			"guardian_bastion":
				player.max_health = maxf(1.0, player.max_health - 18.0)
				player.health = minf(player.health, player.max_health)
				player.health_changed.emit(player.health, player.max_health)
			"dancer_execution":
				stats.crit = maxf(0.0, float(stats.crit) - 0.12)
			"fire_rite":
				stats.area /= 1.12
			"red_contract": red_contract_stacks = 0
			"green_momentum": green_momentum_stacks = 0
			"campfire": campfire_stacks = 0
			"endless_damage", "endless_vitality", "endless_haste": pass
	upgrade_levels.erase(id)
	card_editions.erase(id)
	card_seals.erase(id)
	card_drawbacks.erase(id)
	card_runtime_values.erase(id)
	card_cast_counts.erase(id)
	update_conditional_card_effects(0.0)
	refresh_derived_card_effects()

func insure_pet_before_sale(id: String) -> void:
	if pet_insurance_used or not active_vouchers.has("pet_insurance") or not id in CORE_SKILL_CARD_IDS:
		return
	var rank := core_mastery_rank(id)
	var progress := int(core_mastery_progress.get(id, 0))
	insured_pet_mastery[id] = {"rank":int(floor(rank * 0.5)), "progress":int(floor(progress * 0.5))}
	pet_insurance_used = true
	show_toast("宠物保险生效 · 再次获得%s时返还一半养成" % card_display_name(id), Color("70d7ff"), 1.3)

func restore_insured_pet(id: String) -> void:
	if not insured_pet_mastery.has(id):
		return
	var saved: Dictionary = insured_pet_mastery[id]
	core_mastery_ranks[id] = int(saved.get("rank", 0))
	core_mastery_progress[id] = int(saved.get("progress", 0))
	insured_pet_mastery.erase(id)
	show_toast("宠物保险返还 · %s恢复至★%d" % [card_display_name(id), core_mastery_rank(id)], Color("70d7ff"), 1.2)

func card_display_name(id: String) -> String:
	for upgrade in UPGRADES:
		if upgrade.id == id:
			var edition_name := card_edition_name(str(card_editions.get(id, "")))
			var base_name := ("%s·%s" % [edition_name, upgrade.name]) if not edition_name.is_empty() else str(upgrade.name)
			var drawback_name := str({"fragile":"脆裂", "rental":"租赁", "eternal":"永恒"}.get(str(card_drawbacks.get(id, "")), ""))
			return ("%s·%s" % [drawback_name, base_name]) if not drawback_name.is_empty() else base_name
	match id:
		"endless_damage": return "无尽蓄压"
		"endless_vitality": return "无尽静息"
		"endless_haste": return "无尽围猎"
	return id

func card_drawback_description(id: String) -> String:
	match str(card_drawbacks.get(id, "")):
		"fragile": return "【脆裂版本】技能伤害+25%，角色受到伤害+18%。"
		"rental": return "【租赁版本】每次离店收取◆1；欠费会从后续星屑收入自动扣除。"
		"eternal": return "【永恒版本】本局不能出售、替换或被熔解。"
	return ""

func card_rarity(id: String) -> String:
	if id in ENDLESS_CARD_IDS:
		return "史诗"
	for upgrade in UPGRADES:
		if str(upgrade.id) == id and upgrade.has("character"):
			return "专属"
	if id in ["glass", "gamble", "core_engine", "combo_catalyst", "blueprint", "brainstorm", "four_elements", "luchador"]:
		return "传奇"
	if id in ["satellite_engine", "phase_step", "thunder_orb", "gravity_well", "blade_dance", "meteor_rain", "aegis", "execute", "trio_protocol", "hanging_echo", "boss_matador", "juggler", "astronomer"]:
		return "史诗"
	if id in ["chain", "nova", "homing", "burn", "frost_brand", "momentum", "soul_siphon", "card_slot", "projectile", "pierce", "empty_stencil", "loyalty_cycle", "pair_protocol", "sequence_protocol", "red_contract", "campfire", "lucky_doubler", "rocket", "moon_interest"]:
		return "稀有"
	return "普通"

func card_build_type(id: String) -> String:
	if is_training_card(id):
		return "一次性训练"
	if id in ENDLESS_CARD_IDS:
		return "无尽成长"
	if id in CORE_SKILL_CARD_IDS:
		return "宠物"
	if id in ["homing", "burn", "frost_brand", "projectile", "pierce", "area"]:
		return "技能改造"
	if id in ["momentum", "soul_siphon", "execute", "aegis"]:
		return "触发牌"
	if id in ["glass", "gamble"]:
		return "风险倍率"
	if id in ["card_slot", "core_engine", "combo_catalyst"]:
		return "构筑规则"
	if id in ["pair_protocol", "trio_protocol", "sequence_protocol", "four_elements", "empty_stencil", "low_deck", "astronomer"]:
		return "牌型规则"
	if id in ["blueprint", "brainstorm", "hanging_echo"]:
		return "复制回响"
	if id in ["red_contract", "campfire", "bull_reserve", "rocket", "moon_interest", "juggler"]:
		return "商店经济"
	if id in ["luchador", "boss_matador"]:
		return "Boss反制"
	if id in ["loyalty_cycle", "misprint", "green_momentum", "lucky_doubler"]:
		return "节奏倍率"
	return "条件属性"

func card_effect_scope(id: String) -> String:
	if is_training_card(id):
		return "购买后立即作用于角色，不占卡槽"
	if id in ["aura", "nova", "orbit", "satellite_engine", "blade_dance"]:
		return "以对应宠物为中心"
	if id in ["chain", "thunder_orb", "gravity_well", "meteor_rain", "execute"]:
		return "由对应宠物索敌"
	if id == "phase_step":
		return "宠物触发玩家突进"
	if id == "aegis":
		return "宠物为玩家施加护盾"
	if id in ["damage", "health", "core_engine"]:
		return "对应宠物左侧全部"
	if id == "sequence_protocol":
		return "对应宠物左侧第3格"
	if id == "hanging_echo":
		return "对应宠物右侧相邻"
	if id == "blueprint":
		return "自身右侧相邻1张"
	if id == "brainstorm":
		return "卡组最左侧1张"
	if id in ["burn", "frost_brand", "projectile", "pierce"]:
		return "对应宠物左右两侧（顺序改变效果）"
	if id == "homing":
		return "技能改造；对应宠物右侧附加伤害"
	if id in ["crit", "glass", "gamble", "combo_catalyst", "execute", "endless_damage", "empty_stencil", "loyalty_cycle", "misprint", "pair_protocol", "trio_protocol", "four_elements", "red_contract", "green_momentum", "campfire", "bull_reserve", "low_deck", "lucky_doubler", "boss_matador", "astronomer"]:
		return "对应宠物右侧全部"
	return "全局"

func card_edition_name(edition_id: String) -> String:
	for edition in CARD_EDITIONS:
		if str(edition.id) == edition_id:
			return str(edition.name)
	return ""

func active_combo_names() -> Array[String]:
	var result: Array[String] = []
	for combo in DECK_COMBOS:
		var cards: Array = combo.cards
		var active := is_card_active(str(cards[0])) and is_card_active(str(cards[1]))
		if combo.name == "星环矩阵":
			active = is_card_active("aura") and (is_card_active("orbit") or is_card_active("satellite_engine"))
		if active:
			result.append(str(combo.name))
	return result

func active_combo_count() -> int:
	return active_combo_names().size()

func card_order_rule_text(id: String) -> String:
	if is_training_card(id):
		return "[%s·一次性训练] %s；购买后立即消耗，不进入卡组" % [card_rarity(id), skill_description_short(id)]
	var rule := "[%s·%s] %s" % [card_rarity(id), card_build_type(id), skill_description_short(id)]
	if id in ["damage", "health", "core_engine"]:
		rule += "；放在宠物左侧才进入准备阶段"
	elif id in ["crit", "glass", "gamble", "combo_catalyst", "execute"]:
		rule += "；放在宠物右侧才进入结算阶段"
	elif id in ["burn", "frost_brand"]:
		rule += "；按所在位置先施加状态，再由后续牌利用"
	return rule

func skill_description_short(id: String) -> String:
	for upgrade in UPGRADES:
		if str(upgrade.id) == id:
			return str(upgrade.desc)
	match id:
		"endless_damage": return "宠物后置递减乘算，最高×1.50"
		"endless_vitality": return "4秒未受伤后持续恢复"
		"endless_haste": return "被群敌包围且宠物尚未充满时获得迅捷"
	return id

func source_uses_core_deck(source_id: String) -> bool:
	return source_id in CORE_SKILL_CARD_IDS and equipped_cards.has(source_id)

func calculate_skill_damage(base: float, source_id: String, target: Enemy = null) -> float:
	var result: float
	if source_uses_core_deck(source_id):
		result = resolve_core_card_chain(base, source_id, target)
	else:
		result = calculate_damage(base)
	var mastery_factor := core_mastery_damage_factor(source_id)
	var hand_factor := active_hand_multiplier
	if str(card_drawbacks.get(source_id, "")) == "fragile":
		hand_factor *= 1.25
	var source_cast_count := int(card_cast_counts.get(source_id, 0))
	if str(card_seals.get(source_id, "")) == "red" and source_cast_count > 0 and source_cast_count % 5 == 0:
		hand_factor *= 1.20
	if source_uses_core_deck(source_id):
		var raw_chain_multiplier := raw_damage_multiplier_from_effective(last_chain_multiplier)
		var raw_total_multiplier := raw_chain_multiplier * mastery_factor * hand_factor
		var effective_total_multiplier := soften_damage_multiplier(raw_total_multiplier)
		var external_factor := effective_total_multiplier / maxf(0.1, last_chain_multiplier)
		last_chain_multiplier = effective_total_multiplier
		mastery_factor = external_factor
		hand_factor = 1.0
	var final_damage := result * mastery_factor * hand_factor
	# 灼烧/寒霜必须按本次实际伤害结算。写死常数会让它们全程停在 8 点左右，
	# 到第 6 章只剩陨星单次伤害的 18%，元素与进化路线在中后期集体失效。
	if source_id in CORE_SKILL_CARD_IDS and is_instance_valid(target):
		var status_scale := skill_status_multiplier(source_id)
		var burn_ratio := 0.0
		if is_card_active("burn"):
			burn_ratio += 0.22
		if active_relics.has("ember_vessel"):
			burn_ratio += 0.10 * float(relic_rank("ember_vessel"))
		if burn_ratio > 0.0:
			target.apply_burn(final_damage * burn_ratio * status_scale, 2.4)
		if is_card_active("frost_brand"):
			target.apply_frost(0.42 * status_scale)
	return final_damage

func soften_damage_multiplier(raw_multiplier: float) -> float:
	var safe_multiplier := maxf(0.1, raw_multiplier)
	if safe_multiplier <= 8.0:
		return safe_multiplier
	# 超过阈值后仍保留50%边际收益，避免任何正向词条变成零收益。
	return 8.0 + (safe_multiplier - 8.0) * 0.50

func raw_damage_multiplier_from_effective(effective_multiplier: float) -> float:
	if effective_multiplier <= 8.0:
		return effective_multiplier
	return 8.0 + (effective_multiplier - 8.0) / 0.50

func resolve_core_card_chain(base: float, source_id: String, target: Enemy = null) -> float:
	var base_result := base * float(stats.damage) * PET_DAMAGE_SCALE
	var additive := 0.0
	var multiplier := 1.0
	var crit_chance := clampf(float(stats.crit), 0.0, 0.85)
	var core_seen := false
	var target_distance := player.global_position.distance_to(target.global_position) if is_instance_valid(target) else 0.0
	var dense_targets := count_enemies_in_range(target.global_position if is_instance_valid(target) else player.global_position, 180.0) if is_instance_valid(player) else 0
	var core_index := equipped_cards.find(source_id)
	var hit_count := int(core_hit_counts.get(source_id, 0)) + 1
	core_hit_counts[source_id] = hit_count
	var build_counts: Dictionary = {}
	for owned_id in equipped_cards:
		if is_card_suppressed(owned_id):
			continue
		var build_tag := card_build_type(owned_id)
		build_counts[build_tag] = int(build_counts.get(build_tag, 0)) + 1
	var has_pair := false
	var has_trio := false
	for count_value in build_counts.values():
		has_pair = has_pair or int(count_value) >= 2
		has_trio = has_trio or int(count_value) >= 3
	for card_index in equipped_cards.size():
		var id := equipped_cards[card_index]
		if is_card_suppressed(id):
			continue
		var level_value := maxi(1, int(upgrade_levels.get(id, 0)))
		if id == source_id:
			core_seen = true
			continue
		if not core_seen:
			match id:
				"core_engine":
					additive += minf(0.30, equipped_cards.size() * level_value * 0.025)
				"sequence_protocol":
					if core_index >= 3 and card_index == core_index - 3:
						additive += 0.20
				"projectile", "pierce":
					if dense_targets >= 2:
						additive += 0.06 * level_value
		else:
			match id:
				"glass":
					multiplier *= 1.0 + 0.40 * level_value
				"gamble":
					crit_chance = minf(0.85, crit_chance + 0.25 * level_value)
				"combo_catalyst":
					var combo_gain := minf(0.30, active_combo_count() * level_value * 0.05)
					if combo_gain > 0.0:
						multiplier *= 1.0 + combo_gain
				"execute":
					if is_instance_valid(target) and not target.is_boss and target.health <= target.max_health * 0.2:
						multiplier *= 2.0
				"homing":
					multiplier *= 1.0 + minf(0.16, level_value * 0.04)
				"projectile", "pierce":
					if dense_targets >= 2:
						multiplier *= 1.0 + 0.05 * level_value
				"endless_damage":
					var endless_gain := minf(0.50, 0.16 * sqrt(float(level_value)))
					multiplier *= 1.0 + endless_gain
				"empty_stencil":
					var empty_slots := maxi(0, card_slots - equipped_cards.size())
					if empty_slots > 0:
						var stencil_factor := 1.0 + empty_slots * 0.10
						multiplier *= stencil_factor
				"loyalty_cycle":
					if hit_count % 6 == 0:
						multiplier *= 2.20
				"misprint":
					var glitch_factor := randf_range(0.85, 1.35)
					multiplier *= glitch_factor
				"pair_protocol":
					if has_pair:
						multiplier *= 1.15
				"trio_protocol":
					if has_trio:
						multiplier *= 1.25
				"four_elements":
					if is_card_active("burn") and is_card_active("frost_brand") and is_card_active("thunder_orb") and is_card_active("gravity_well"):
						multiplier *= 1.45
				"hanging_echo":
					if card_index == core_index + 1:
						multiplier *= 1.22
				"blueprint":
					if card_index + 1 < equipped_cards.size():
						var copied_id := equipped_cards[card_index + 1]
						if not copied_id in ["blueprint", "brainstorm"]:
							var copied := copied_card_effect(copied_id, target_distance, dense_targets, target, hit_count, has_pair, has_trio)
							if bool(copied.supported):
								additive += float(copied.additive)
								multiplier *= float(copied.multiplier)
								crit_chance = minf(0.85, crit_chance + float(copied.crit_bonus))
				"brainstorm":
					if not equipped_cards.is_empty():
						var copied_id := equipped_cards[0]
						if not copied_id in ["blueprint", "brainstorm"]:
							var copied := copied_card_effect(copied_id, target_distance, dense_targets, target, hit_count, has_pair, has_trio)
							if bool(copied.supported):
								additive += float(copied.additive)
								multiplier *= float(copied.multiplier)
								crit_chance = minf(0.85, crit_chance + float(copied.crit_bonus))
				"red_contract":
					if red_contract_stacks > 0:
						var red_factor := 1.0 + red_contract_stacks * 0.05
						multiplier *= red_factor
				"green_momentum":
					if green_momentum_stacks > 0:
						var green_factor := 1.0 + green_momentum_stacks * 0.04
						multiplier *= green_factor
				"campfire":
					if campfire_stacks > 0:
						var camp_factor := 1.0 + campfire_stacks * 0.08
						multiplier *= camp_factor
				"bull_reserve":
					var reserve_gain := minf(0.25, floor(float(star_shards) / 10.0) * 0.05)
					if reserve_gain > 0.0:
						additive += reserve_gain
				"low_deck":
					if equipped_cards.size() < STARTING_CARD_SLOTS:
						var low_factor := 1.0 + (STARTING_CARD_SLOTS - equipped_cards.size()) * 0.12
						multiplier *= low_factor
				"lucky_doubler":
					if randf() < minf(0.80, 0.33 + float(stats.luck)):
						multiplier *= 1.50
				"boss_matador":
					if is_instance_valid(target) and target.is_boss and target.weakness_time > 0.0:
						multiplier *= 1.50
				"astronomer":
					if active_combo_count() > 0:
						multiplier *= 1.12
	var did_crit := randf() < crit_chance
	var crit_factor := 1.0
	if did_crit:
		crit_factor = 2.0 + bonus_crit_damage
	var edition_id := str(card_editions.get(source_id, ""))
	match edition_id:
		"foil": multiplier *= 1.15
		"holographic":
			if did_crit:
				crit_factor *= 1.25
		"polychrome": multiplier *= 1.20
	# 暴击放在软上限之外结算，保证暴击流在任何构筑强度下都是完整收益。
	last_chain_multiplier = soften_damage_multiplier((1.0 + additive) * multiplier) * crit_factor
	return base_result * last_chain_multiplier

func copied_card_effect(id: String, target_distance: float, dense_targets: int, target: Enemy, hit_count: int, has_pair: bool, has_trio: bool) -> Dictionary:
	var level_value := maxi(1, int(upgrade_levels.get(id, 0)))
	var result := {"supported":true, "additive":0.0, "multiplier":1.0, "crit_bonus":0.0}
	match id:
		"core_engine": result.additive = minf(0.30, equipped_cards.size() * level_value * 0.025)
		"glass": result.multiplier = 1.0 + 0.40 * level_value
		"gamble": result.crit_bonus = 0.25 * level_value
		"combo_catalyst": result.multiplier = 1.0 + minf(0.30, active_combo_count() * level_value * 0.05)
		"execute": result.multiplier = 2.0 if is_instance_valid(target) and not target.is_boss and target.health <= target.max_health * 0.2 else 1.0
		"homing": result.multiplier = 1.0 + minf(0.16, level_value * 0.04)
		"projectile", "pierce": result.multiplier = 1.0 + 0.05 * level_value if dense_targets >= 2 else 1.0
		"endless_damage": result.multiplier = 1.0 + minf(0.50, 0.16 * sqrt(float(level_value)))
		"empty_stencil": result.multiplier = 1.0 + maxi(0, card_slots - equipped_cards.size()) * 0.10
		"loyalty_cycle": result.multiplier = 2.20 if hit_count % 6 == 0 else 1.0
		"misprint": result.multiplier = randf_range(0.85, 1.35)
		"pair_protocol": result.multiplier = 1.15 if has_pair else 1.0
		"trio_protocol": result.multiplier = 1.25 if has_trio else 1.0
		"four_elements": result.multiplier = 1.45 if is_card_active("burn") and is_card_active("frost_brand") and is_card_active("thunder_orb") and is_card_active("gravity_well") else 1.0
		"hanging_echo": result.multiplier = 1.22
		"red_contract": result.multiplier = 1.0 + red_contract_stacks * 0.05
		"green_momentum": result.multiplier = 1.0 + green_momentum_stacks * 0.04
		"campfire": result.multiplier = 1.0 + campfire_stacks * 0.08
		"bull_reserve": result.additive = minf(0.25, floor(float(star_shards) / 10.0) * 0.05)
		"low_deck": result.multiplier = 1.0 + maxi(0, STARTING_CARD_SLOTS - equipped_cards.size()) * 0.12
		"lucky_doubler": result.multiplier = 1.50 if randf() < minf(0.80, 0.33 + float(stats.luck)) else 1.0
		"boss_matador": result.multiplier = 1.50 if is_instance_valid(target) and target.is_boss and target.weakness_time > 0.0 else 1.0
		"astronomer": result.multiplier = 1.12 if active_combo_count() > 0 else 1.0
		_: result.supported = false
	return result

func skill_status_multiplier(source_id: String) -> float:
	return 1.15 if str(card_editions.get(source_id, "")) == "foil" else 1.0

func configured_core_crit_chance() -> float:
	var best := float(stats.crit)
	for core_id in active_core_skill_ids():
		var current := float(stats.crit)
		var core_index := equipped_cards.find(core_id)
		for card_index in range(core_index + 1, equipped_cards.size()):
			var id := equipped_cards[card_index]
			if is_card_suppressed(id):
				continue
			if id == "gamble":
				current += 0.25 * int(upgrade_levels.get(id, 0))
		best = maxf(best, current)
	return clampf(best, 0.0, 0.85)

func show_skill_tooltip(description: String, rarity := "普通") -> void:
	if not is_instance_valid(hud):
		return
	if not is_instance_valid(skill_tooltip):
		skill_tooltip = PanelContainer.new()
		skill_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_tooltip.z_index = 100
		hud.add_child(skill_tooltip)
		var label := make_label("", 15, Color("e8f5ff"))
		label.name = "TooltipText"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(300, 0)
		skill_tooltip.add_child(label)
	var tooltip_text := skill_tooltip.get_node("TooltipText") as Label
	var rarity_color: Color = CARD_RARITY_COLORS.get(rarity, Color("9bb4d1"))
	skill_tooltip.add_theme_stylebox_override("panel", panel_style(Color("081326", 0.96), 10, rarity_color, 2))
	tooltip_text.add_theme_color_override("font_color", rarity_color)
	tooltip_text.text = description
	skill_tooltip.show()
	call_deferred("position_skill_tooltip")

func tooltip_screen_position(pointer: Vector2, tooltip_size: Vector2, viewport_size: Vector2) -> Vector2:
	const EDGE_MARGIN := 12.0
	const CURSOR_GAP := 18.0
	var target := pointer + Vector2(CURSOR_GAP, CURSOR_GAP)
	if target.x + tooltip_size.x > viewport_size.x - EDGE_MARGIN:
		target.x = pointer.x - tooltip_size.x - CURSOR_GAP
	if target.y + tooltip_size.y > viewport_size.y - EDGE_MARGIN:
		target.y = pointer.y - tooltip_size.y - CURSOR_GAP
	target.x = clampf(target.x, EDGE_MARGIN, maxf(EDGE_MARGIN, viewport_size.x - tooltip_size.x - EDGE_MARGIN))
	target.y = clampf(target.y, EDGE_MARGIN, maxf(EDGE_MARGIN, viewport_size.y - tooltip_size.y - EDGE_MARGIN))
	return target

func position_skill_tooltip() -> void:
	if not is_instance_valid(skill_tooltip) or not skill_tooltip.visible or not is_instance_valid(hud):
		return
	var viewport_size := hud.get_viewport().get_visible_rect().size
	var tooltip_size := skill_tooltip.get_combined_minimum_size()
	tooltip_size.x = minf(tooltip_size.x, viewport_size.x - 24.0)
	tooltip_size.y = minf(tooltip_size.y, viewport_size.y - 24.0)
	skill_tooltip.size = tooltip_size
	var pointer := hud.get_viewport().get_mouse_position()
	skill_tooltip.position = tooltip_screen_position(pointer, tooltip_size, viewport_size)

func hide_skill_tooltip() -> void:
	if is_instance_valid(skill_tooltip):
		skill_tooltip.hide()

func skill_cooldown_data(id: String) -> Dictionary:
	if id == "phase_step" and phase_step_cooldown > 0.0 and float(pet_energy.get(id, 0.0)) + 0.001 >= pet_energy_requirement(id):
		return {"remaining":phase_step_cooldown, "total":PHASE_STEP_COOLDOWN, "energy":false}
	if id in CORE_SKILL_CARD_IDS:
		var total_energy := pet_energy_requirement(id)
		return {"remaining": maxf(0.0, total_energy - float(pet_energy.get(id, 0.0))), "total": total_energy, "energy": true}
	return {"remaining": 0.0, "total": 1.0, "energy": false}

func on_health_changed(current: float, maximum: float) -> void:
	if is_instance_valid(hp_bar) and is_instance_valid(hp_lag_bar):
		var previous := displayed_health
		displayed_health = current
		hp_bar.max_value = maximum
		hp_lag_bar.max_value = maximum
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		if current < previous:
			hp_bar.add_theme_stylebox_override("fill", panel_style(Color("ef476f"), 6))
			tween.tween_property(hp_bar, "value", current, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_interval(0.12)
			tween.tween_property(hp_lag_bar, "value", current, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			hp_bar.add_theme_stylebox_override("fill", panel_style(Color("4ade80"), 6))
			tween.tween_property(hp_lag_bar, "value", current, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(hp_bar, "value", current, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_interval(0.18)
			tween.tween_callback(func(): if is_instance_valid(hp_bar): hp_bar.add_theme_stylebox_override("fill", panel_style(Color("ef476f"), 6)))

func on_player_hurt(amount: float) -> void:
	damage_taken_this_run += amount
	green_momentum_stacks = 0
	last_hurt_elapsed = elapsed
	var heavy_hit_threshold := maxf(10.0, player.max_health * 0.09) if is_instance_valid(player) else 10.0
	if amount >= heavy_hit_threshold:
		shake_camera(minf(12.0, 4.0 + amount * 0.35))
	if is_instance_valid(player):
		if player.character_name == "骑士":
			for defensive_pet in ["aegis", "aura", "blade_dance"]:
				if active_core_skill_ids().has(defensive_pet):
					on_pet_energy_received(defensive_pet, 0.55)
					break
		var tween := create_tween()
		tween.tween_property(player, "scale", Vector2(1.16, 0.84), 0.055)
		tween.tween_property(player, "scale", Vector2(0.93, 1.08), 0.07)
		tween.tween_property(player, "scale", Vector2.ONE, 0.11)

func on_player_shield_blocked() -> void:
	record_core_mastery("aegis")
	if is_instance_valid(player) and player.character_name == "骑士":
		for defensive_pet in ["aegis", "aura", "blade_dance"]:
			if active_core_skill_ids().has(defensive_pet):
				on_pet_energy_received(defensive_pet, 0.85)
				break
	show_toast("星垒格挡 · 条件养成推进", Color("70d7ff"), 0.55)
	spawn_skill_effect(player.global_position, "shield", Color("bde9ff"), 58.0)

func on_player_healed(_amount: float) -> void:
	if is_instance_valid(player):
		var tween := create_tween()
		tween.tween_property(player, "modulate", Color("b8ffd2"), 0.08)
		tween.tween_property(player, "modulate", Color.WHITE, 0.22)

func spawn_wavelet() -> void:
	if not is_instance_valid(player):
		return
	var chapter := current_mainline_chapter()
	var amount := 1
	if endless_mode:
		amount = 2 + (1 if endless_wave >= 7 and randf() < 0.45 else 0)
	elif randf() < clampf(float(chapter - 1) * 0.22, 0.0, 1.0):
		amount = 2
	if not endless_mode and chapter >= 6 and randf() < 0.10:
		amount += 1
	var boss_present := not get_tree().get_nodes_in_group("bosses").is_empty()
	var enemy_cap := (72 + mini(28, endless_wave * 2)) if endless_mode else mini(62, 44 + chapter * 5)
	if boss_present:
		# 主线里 Boss 是关卡高潮，收紧场面让玩家专心打；无尽里 Boss 每 3 波就来一次，
		# 用同样的力度会让后半段长期停摆，所以只做温和压制。
		enemy_cap = mini(enemy_cap, 44 if endless_mode else 26)
	if get_tree().get_nodes_in_group("enemies").size() >= enemy_cap:
		return
	if boss_present and randf() > (0.65 if endless_mode else 0.35):
		return
	for i in amount:
		spawn_enemy(chapter_enemy_kind(chapter, endless_wave if endless_mode else 0))

func current_mainline_chapter() -> int:
	if endless_mode:
		return 6
	for index in MAINLINE_BOSS_SCHEDULE.size():
		if elapsed < float(MAINLINE_BOSS_SCHEDULE[index]):
			return index + 1
	return 6

func chapter_theme_name(chapter: int) -> String:
	return str({1:"追踪信号", 2:"封锁街区", 3:"裁决前线", 4:"急袭回廊", 5:"裂隙城区", 6:"终局灯塔"}.get(chapter, "深渊循环"))

func chapter_enemy_kind(chapter: int, wave := 0) -> String:
	var weighted: Array[String] = []
	match chapter:
		1: weighted.assign(["追猎者", "追猎者", "追猎者", "追猎者", "疾行兽"])
		2: weighted.assign(["追猎者", "追猎者", "追猎者", "疾行兽", "重甲怪"])
		3: weighted.assign(["追猎者", "追猎者", "疾行兽", "重甲怪", "咒术师"])
		4: weighted.assign(["追猎者", "疾行兽", "重甲怪", "重甲怪", "咒术师"])
		5: weighted.assign(["疾行兽", "重甲怪", "重甲怪", "咒术师", "咒术师"])
		_: weighted.assign(["疾行兽", "重甲怪", "重甲怪", "咒术师", "咒术师"])
	if wave >= 6:
		weighted.append("重甲怪")
		weighted.append("咒术师")
	return str(weighted.pick_random())

func spawn_enemy(kind: String, boss := false) -> Enemy:
	var enemy: Enemy = EnemyScript.new()
	var angle := randf() * TAU
	# 刷新距离必须跟着攻击范围一起收：360 之外的敌人既打不到也看不见，
	# 过去 650~860 意味着每只怪要先走 3.7 秒不可见的路才进场，
	# 战斗节奏被拉断，而它们仍在源源不断地积压。
	var distance := randf_range(430.0, 560.0)
	enemy.position = player.position + Vector2.from_angle(angle) * distance
	entity_root.add_child(enemy)
	enemy.add_to_group("enemies")
	if boss:
		enemy.add_to_group("bosses")
	# 不再对 elapsed 封顶：过去把它钉在 360 秒会让 6 分钟后的敌人
	# 强度永久停在 1.61 倍，主线因此完全失去时间压力，拖多久都不会输。
	var difficulty := 0.92 + elapsed / 520.0
	if endless_mode:
		var late_wave := maxf(0.0, endless_wave - 13.0)
		difficulty *= 1.0 + minf(12.0, endless_wave - 1.0) * 0.055 + sqrt(late_wave) * 0.025 + late_wave * 0.012
	enemy.setup(kind, difficulty, player)
	if not danger_contract.is_empty() and not boss:
		enemy.health *= 1.25
		enemy.max_health *= 1.25
		enemy.damage *= 1.18
	if endless_mode and not boss:
		enemy.damage *= 1.0 + maxf(0.0, endless_wave - 13.0) * 0.006
	enemy.defeated.connect(on_enemy_defeated)
	enemy.fired.connect(spawn_enemy_projectile)
	enemy.damaged.connect(on_enemy_damaged)
	enemy.hazard_requested.connect(spawn_boss_hazard)
	enemy.affix_requested.connect(on_boss_affix_requested)
	enemy.dramatic_attack.connect(on_boss_dramatic_attack)
	return enemy

func on_boss_dramatic_attack(strength: float) -> void:
	shake_camera(clampf(strength, 5.0, 10.0))

func check_boss_timing() -> void:
	if endless_mode:
		return
	var boss_schedule := {
		60: ["星渊追猎者", "追击型 · 冲刺逼近"],
		120: ["星渊禁锢者", "控场型 · 陷阱封锁"],
		180: ["星渊裁决者", "爆发型 · 蓄力齐射"],
		240: ["星渊追猎者", "追击型 · 冲刺逼近"],
		300: ["星渊禁锢者", "控场型 · 陷阱封锁"],
		355: ["星渊裁决者", "爆发型 · 蓄力齐射"]
	}
	for mark in boss_schedule:
		var chapter := MAINLINE_BOSS_SCHEDULE.find(mark) + 1
		var story_profile := chapter_story_profile(chapter)
		if elapsed >= mark - 2.0 and not boss_warned.has(mark) and not boss_spawned.has(mark):
			boss_warned[mark] = true
			show_toast("%s\n不祥的气息正在逼近……" % str(story_profile.title), Color("ef7791"), 1.8)
			play_boss_warning_sound()
		if elapsed >= mark and not boss_spawned.has(mark):
			boss_spawned[mark] = true
			var profile: Array = boss_schedule[mark]
			var boss := spawn_enemy(profile[0], true)
			boss.set_meta("story_chapter", chapter)
			boss.set_meta("damage_taken_at_spawn", damage_taken_this_run)
			boss.set_chapter_tier(chapter)
			boss.set_mainline_health(MAINLINE_BOSS_HEALTH[clampi(chapter - 1, 0, MAINLINE_BOSS_HEALTH.size() - 1)])
			boss.set_affixes(roll_boss_affixes(chapter, boss.boss_style))
			apply_luchador_counter(boss)
			award_boss_affix_achievements(boss.affixes)
			show_toast("%s\n%s\n%s" % [str(story_profile.boss), boss_character_reply(chapter, player.character_name), "词条：" + boss.affix_summary()], Color("facc15"), 3.8)
			shake_camera(12.0)

func check_boss_story_beats(active_bosses: Array) -> void:
	for boss in active_bosses:
		if not is_instance_valid(boss) or boss.max_health <= 0.0 or boss.health / boss.max_health > 0.5:
			continue
		var key := "half_%d" % boss.get_instance_id()
		if narrative_seen.has(key):
			continue
		narrative_seen[key] = true
		var chapter := int(boss.get_meta("story_chapter", 0))
		show_toast(boss_half_story_line(str(boss.kind), chapter), Color("efb8ff"), 2.8)

func next_boss_time() -> String:
	if endless_mode:
		return "第 %d 波" % next_endless_boss_wave
	for mark in MAINLINE_BOSS_SCHEDULE:
		if not boss_spawned.has(mark):
			return format_time(maxf(0.0, mark - elapsed))
	return "已降临"

func spawn_endless_boss() -> void:
	var boss_types := ["星渊追猎者", "星渊禁锢者", "星渊裁决者"]
	var boss_index := int(endless_wave / 3.0 - 1.0) % boss_types.size()
	show_toast("无尽深处传来不祥回响……", Color("ef7791"), 1.2)
	play_boss_warning_sound()
	await get_tree().create_timer(0.85, false).timeout
	if state != GameState.PLAYING or not endless_mode or not is_instance_valid(player):
		return
	var boss := spawn_enemy(boss_types[boss_index], true)
	boss.set_meta("story_chapter", 0)
	boss.set_meta("damage_taken_at_spawn", damage_taken_this_run)
	boss.set_chapter_tier(6 + int(floor(maxi(0, endless_wave - 1) / 6.0)))
	boss.set_affixes(roll_boss_affixes(6 + int(floor(maxi(0, endless_wave - 1) / 6.0)), boss.boss_style))
	apply_luchador_counter(boss)
	award_boss_affix_achievements(boss.affixes)
	show_toast("无尽 Boss · %s\n词条：%s" % [boss.kind, boss.affix_summary()], Color("f472b6"), 2.7)
	shake_camera(12.0)

func weighted_affix_pick(weighted_ids: Array[String], excluded: Array[String] = []) -> String:
	var candidates: Array[String] = []
	for id in weighted_ids:
		if not excluded.has(id):
			candidates.append(id)
	return "" if candidates.is_empty() else str(candidates.pick_random())

func boss_combat_affix_pool(chapter: int, boss_style: String) -> Array[String]:
	var pool: Array[String] = []
	match boss_style:
		"pursuit": pool.assign(["exposed_core", "exposed_core", "prism_shield", "riftfield"])
		"control": pool.assign(["riftfield", "riftfield", "riftfield", "prism_shield", "exposed_core"])
		_: pool.assign(["exposed_core", "exposed_core", "prism_shield", "prism_shield", "riftfield"])
	if chapter >= 3:
		pool.append("rapid_pattern")
		if boss_style == "control": pool.append("riftfield")
		elif boss_style == "burst": pool.append("exposed_core")
	return pool

func boss_disruption_affix_pool(chapter: int, boss_style: String) -> Array[String]:
	var pool: Array[String] = []
	if chapter <= 1:
		return pool
	if chapter == 2:
		if equipped_cards.size() >= 3:
			pool.append("reverse_shuffle")
		return pool
	pool.assign(["sealed_hand", "reverse_shuffle", "sealed_hand"])
	if chapter >= 5 and normally_castable_pet_ids().size() >= 2 and boss_style != "pursuit":
		pool.append("pet_charm")
		if boss_style == "control":
			pool.append("pet_charm")
		else:
			pool.append("pet_thief")
	if equipped_cards.size() < 2:
		pool = pool.filter(func(id): return id != "reverse_shuffle")
	return pool

func roll_boss_affixes(chapter := 1, boss_style := "") -> Array[String]:
	# Chapters 1-2 teach readable ground/counter rules.  Deck disruption arrives
	# in chapters 3-4, and pet control is reserved for chapters 5+ with redundancy.
	var result: Array[String] = []
	var combat_id := weighted_affix_pick(boss_combat_affix_pool(chapter, boss_style))
	if not combat_id.is_empty():
		result.append(combat_id)
	var disruption_id := weighted_affix_pick(boss_disruption_affix_pool(chapter, boss_style), result)
	if not disruption_id.is_empty():
		result.append(disruption_id)
	if active_vouchers.has("counter_license") and randf() < 0.35:
		result.remove_at(randi_range(0, result.size() - 1))
		show_toast("破咒执照生效 · 本次Boss少获得一个词条", Color("4ade80"), 1.2)
	return result

func apply_luchador_counter(boss: Enemy) -> void:
	if not is_instance_valid(boss) or not equipped_cards.has("luchador") or boss.affixes.is_empty():
		return
	var removed_affix: String = boss.affixes.pick_random()
	boss.affixes.erase(removed_affix)
	equipped_cards.erase("luchador")
	remove_slot_card_effect("luchador")
	show_toast("破咒面具献祭 · 已取消Boss词条【%s】" % str(BOSS_AFFIXES.filter(func(item): return str(item.id) == removed_affix)[0].name), Color("4ade80"), 2.0)
	update_deck_card_row()

func on_boss_affix_requested(source, effect_id: String, duration: float) -> void:
	if state != GameState.PLAYING or boss_affix_pending or not is_instance_valid(source):
		return
	if effect_id in ["sealed_hand", "pet_thief", "pet_charm", "reverse_shuffle"] and cleanse_ward_charges > 0:
		cleanse_ward_charges -= 1
		show_toast("净化屏障生效 · 已抵消%s" % affix_display_name(effect_id), Color("4ade80"), 1.5)
		spawn_skill_effect(source.global_position, "shield", Color("4ade80"), 96.0)
		return
	boss_affix_pending = true
	var warning := "Boss正在改写卡组"
	match effect_id:
		"sealed_hand": warning = "封印预警 · 击败5名敌人可提前解除"
		"pet_thief": warning = "窃宠预警 · 接近被盗宠物可提前夺回"
		"pet_charm": warning = "魅惑预警 · 接近倒戈宠物可净化"
		"reverse_shuffle": warning = "洗牌预警 · 卡牌顺序即将暂时反转"
	show_toast(warning, Color("f472b6"), 1.35)
	spawn_skill_effect(source.global_position, "gravity", Color("f472b6"), 92.0)
	resolve_boss_affix_after_warning(source, effect_id, duration)

func resolve_boss_affix_after_warning(source, effect_id: String, duration: float) -> void:
	await get_tree().create_timer(0.8, false).timeout
	boss_affix_pending = false
	if state != GameState.PLAYING or not is_instance_valid(source) or source.health <= 0.0:
		return
	match effect_id:
		"sealed_hand": apply_boss_card_seal(source, duration)
		"pet_thief": apply_boss_pet_theft(source, duration)
		"pet_charm": apply_boss_pet_charm(source, duration)
		"reverse_shuffle": apply_boss_reverse_shuffle(source, duration)

func available_disruption_cards(include_core := true) -> Array[String]:
	var result: Array[String] = []
	for id in equipped_cards:
		if id == "card_slot" or is_card_suppressed(id):
			continue
		if not include_core and id in CORE_SKILL_CARD_IDS:
			continue
		result.append(id)
	return result

func normally_castable_pet_ids() -> Array[String]:
	var result: Array[String] = []
	for id in equipped_cards:
		if id in CORE_SKILL_CARD_IDS and core_pet_control_state(id) == "normal" and not is_card_suppressed(id):
			result.append(id)
	return result

func apply_boss_soft_interference(effect_id: String) -> void:
	var pets := normally_castable_pet_ids()
	if pets.is_empty():
		return
	var pet_id: String = pets[0]
	pet_energy[pet_id] = maxf(0.0, float(pet_energy.get(pet_id, 0.0)) - pet_energy_requirement(pet_id) * 0.25)
	show_toast("最后战力保护 · %s抵抗%s\n仅散失25%%能量，仍可继续施法" % [card_display_name(pet_id), affix_display_name(effect_id)], Color("70d7ff"), 1.6)
	update_skill_list()

func affix_display_name(id: String) -> String:
	for item in BOSS_AFFIXES:
		if str(item.id) == id:
			return str(item.name)
	return id

func apply_boss_card_seal(source, duration: float) -> void:
	var candidates := available_disruption_cards(false)
	if candidates.is_empty() and normally_castable_pet_ids().size() >= 2:
		candidates = normally_castable_pet_ids()
	if candidates.is_empty():
		apply_boss_soft_interference("sealed_hand")
		return
	var card_id: String = candidates.pick_random()
	boss_card_disruptions[card_id] = {"mode":"sealed", "remaining":duration, "source":source, "start_kills":kills}
	show_toast("封印契约：%s 暂时失效\n击败5名敌人可提前解除" % card_display_name(card_id), Color("f472b6"), 1.8)
	refresh_skill_entities()
	update_deck_card_row()

func apply_boss_pet_theft(source, duration: float) -> void:
	var candidates := normally_castable_pet_ids()
	if candidates.size() <= 1:
		apply_boss_soft_interference("pet_thief")
		return
	var card_id: String = candidates.pick_random()
	boss_card_disruptions[card_id] = {"mode":"stolen", "remaining":duration, "source":source, "shot_timer":99.0, "rescue_delay":1.15}
	show_toast("星渊窃宠：%s 被Boss夺走\n接近宠物即可提前夺回" % card_display_name(card_id), Color("ef7791"), 1.9)
	refresh_skill_entities()
	update_deck_card_row()

func apply_boss_pet_charm(source, duration: float) -> void:
	var candidates := normally_castable_pet_ids()
	if candidates.size() <= 1:
		apply_boss_soft_interference("pet_charm")
		return
	var card_id: String = candidates.pick_random()
	boss_card_disruptions[card_id] = {"mode":"charmed", "remaining":duration, "source":source, "shot_timer":0.9, "rescue_delay":1.15}
	show_toast("倒戈魅惑：%s 暂时叛变\n靠近它即可提前净化" % card_display_name(card_id), Color("f0abfc"), 1.9)
	refresh_skill_entities()
	update_deck_card_row()

func apply_boss_reverse_shuffle(source, duration: float) -> void:
	if boss_shuffle_remaining > 0.0 or equipped_cards.size() < 2:
		return
	boss_shuffle_original = equipped_cards.duplicate()
	boss_shuffle_remaining = duration
	boss_shuffle_source = source
	equipped_cards.reverse()
	show_toast("逆序洗牌：卡牌结算顺序已反转\n%.1f秒后恢复" % duration, Color("facc15"), 1.8)
	update_deck_card_row()

func update_boss_card_disruptions(delta: float) -> void:
	var restored: Array[String] = []
	for card_id in boss_card_disruptions.keys().duplicate():
		var record: Dictionary = boss_card_disruptions[card_id]
		record.remaining = float(record.get("remaining", 0.0)) - delta
		record.rescue_delay = maxf(0.0, float(record.get("rescue_delay", 0.0)) - delta)
		var mode := str(record.get("mode", "sealed"))
		var entity = skill_entities.get(card_id)
		if mode == "sealed" and kills >= int(record.get("start_kills", kills)) + 5:
			record.remaining = 0.0
		elif mode in ["stolen", "charmed"] and float(record.rescue_delay) <= 0.0 and is_instance_valid(entity) and player.global_position.distance_to(entity.global_position) <= (78.0 if mode == "stolen" else 62.0):
			record.remaining = 0.0
		if mode == "charmed" and is_instance_valid(entity):
			record.shot_timer = float(record.get("shot_timer", 0.0)) - delta
			if float(record.shot_timer) <= 0.0:
				record.shot_timer = 1.15
				var direction: Vector2 = (player.global_position - entity.global_position).normalized()
				spawn_enemy_projectile(entity.global_position, direction, 5.0 + elapsed / 210.0)
				spawn_skill_effect(entity.global_position, "cast", Color("f472b6"), 90.0, direction)
		if float(record.remaining) <= 0.0 or not is_instance_valid(record.get("source")):
			restored.append(str(card_id))
		else:
			boss_card_disruptions[card_id] = record
	if not restored.is_empty():
		for card_id in restored:
			boss_card_disruptions.erase(card_id)
			if str(card_seals.get(card_id, "")) == "white":
				gain_resonance(20.0)
		show_toast("卡牌与宠物控制已恢复", Color("4ade80"), 1.0)
		refresh_skill_entities()
		update_deck_card_row()
	if boss_shuffle_remaining > 0.0:
		boss_shuffle_remaining = maxf(0.0, boss_shuffle_remaining - delta)
		if boss_shuffle_remaining <= 0.0 or not is_instance_valid(boss_shuffle_source):
			restore_boss_shuffle()

func restore_boss_shuffle() -> void:
	if not boss_shuffle_original.is_empty():
		var current_cards := equipped_cards.duplicate()
		var restored_order: Array[String] = []
		for id in boss_shuffle_original:
			if current_cards.has(id) and not restored_order.has(id):
				restored_order.append(id)
		for id in current_cards:
			if not restored_order.has(id):
				restored_order.append(id)
		equipped_cards = restored_order
	boss_shuffle_original.clear()
	boss_shuffle_remaining = 0.0
	boss_shuffle_source = null
	update_deck_card_row()

func clear_boss_card_disruptions(source = null) -> void:
	var had_disruption := false
	if source == null:
		had_disruption = not boss_card_disruptions.is_empty() or boss_shuffle_remaining > 0.0
		boss_card_disruptions.clear()
		restore_boss_shuffle()
	else:
		for card_id in boss_card_disruptions.keys().duplicate():
			var record: Dictionary = boss_card_disruptions[card_id]
			if record.get("source") == source:
				boss_card_disruptions.erase(card_id)
				had_disruption = true
		if boss_shuffle_remaining > 0.0 and boss_shuffle_source == source:
			restore_boss_shuffle()
			had_disruption = true
	boss_affix_pending = false
	if had_disruption:
		refresh_skill_entities()
		update_deck_card_row()

func boss_disruption_summary() -> String:
	var parts: Array[String] = []
	for card_id in boss_card_disruptions:
		var record: Dictionary = boss_card_disruptions[card_id]
		var mode_name: String = str({"sealed":"封印", "stolen":"被盗", "charmed":"魅惑"}.get(str(record.get("mode", "sealed")), "干扰"))
		parts.append("%s:%s %.1fs" % [mode_name, card_display_name(str(card_id)), float(record.get("remaining", 0.0))])
	if boss_shuffle_remaining > 0.0:
		parts.append("逆序洗牌 %.1fs" % boss_shuffle_remaining)
	return "  ·  ".join(parts)

func spawn_boss_hazard(position: Vector2, damage: float, radius: float) -> void:
	if state != GameState.PLAYING or not is_instance_valid(hazard_root):
		return
	var hazard: BossHazard = BossHazardScript.new()
	hazard.position = position
	hazard.setup(player, damage, radius)
	hazard_root.add_child(hazard)

func pet_color(id: String) -> Color:
	var entity = skill_entities.get(id)
	return entity.entity_color() if is_instance_valid(entity) else Color("e8f5ff")

func take_effect() -> SkillEffect:
	while not effect_pool.is_empty():
		var reused: SkillEffect = effect_pool.pop_back()
		if is_instance_valid(reused):
			reused.revive()
			return reused
	var fresh: SkillEffect = SkillEffectScript.new()
	fresh.pool = self
	visual_root.add_child(fresh)
	return fresh

func recycle_effect(effect: SkillEffect) -> void:
	if is_instance_valid(effect) and effect_pool.size() < 96:
		effect_pool.append(effect)

func spawn_capsule_effect(at: Vector2, id: String, travel: float, width: float, direction: Vector2) -> void:
	if not is_instance_valid(visual_root):
		return
	var effect := take_effect()
	effect.position = at
	effect.setup_capsule(pet_color(id), travel, width, direction)

func spawn_arc_path_effect(id: String, path: PackedVector2Array) -> void:
	if not is_instance_valid(visual_root) or path.size() < 2:
		return
	var effect := take_effect()
	effect.position = Vector2.ZERO
	effect.setup_polyline(pet_color(id), path)

func spawn_skill_effect(position: Vector2, kind: String, color: Color, radius: float, direction := Vector2.RIGHT) -> void:
	if not is_instance_valid(visual_root):
		return
	var effect := take_effect()
	effect.position = position
	effect.setup(kind, color, radius, direction)

func process_weapons() -> void:
	try_release_charged_pets()
	# 链条只要连着就一直输能。过去要求「视野内有敌人」是为了不浪费飞行中的弹丸，
	# 但索敌收进 360 之后，敌人从 650 走到 360 的两三秒里会完全停产，
	# 而宠物本来就会把攒下的能量留到目标进范围再放，没有浪费一说。
	if pulse_timer <= 0.0 and not active_core_skill_ids().is_empty():
		fire_pulse()
		pulse_timer = energy_shot_interval()

func energy_shot_interval() -> float:
	var interval := 0.50 * float(stats.cooldown)
	if equipped_cards.has("endless_haste") and count_enemies_in_range(player.global_position, 300.0) >= 3:
		interval *= pow(0.97, mini(10, int(upgrade_levels.get("endless_haste", 0))))
	if player.character_name == "影舞者" and player.velocity.length() > player.speed * 0.55:
		interval *= 0.78
	return maxf(0.20, interval)

func pet_energy_requirement(id: String) -> float:
	var requirement := float(PET_ENERGY_REQUIREMENTS.get(id, 2.0))
	if id == "phase_step":
		requirement -= core_mastery_rank(id) * 0.10
	elif id == "aegis":
		requirement -= core_mastery_rank(id) * 0.20
	elif id == "aura" and int(upgrade_levels.get("mage_prism", 0)) > 0:
		requirement *= 0.80
	return maxf(0.75, requirement)

func pet_link_connected(id: String) -> bool:
	return not bool(pet_link_broken.get(id, false))

func pet_energy_ratio(id: String) -> float:
	return clampf(float(pet_energy.get(id, 0.0)) / pet_energy_requirement(id), 0.0, 1.0)

func selectable_energy_pet_ids() -> Array[String]:
	var result: Array[String] = []
	for id in active_core_skill_ids():
		if core_pet_control_state(id) == "normal" and pet_link_connected(id) and pet_energy_ratio(id) < 0.999 and is_instance_valid(skill_entities.get(id)):
			result.append(id)
	return result

func energy_amount_for_pet(id: String) -> float:
	var amount := float(stats.get("energy_power", 1.0))
	match player.character_name:
		"游侠": amount *= 1.22
		"星术师": amount *= 1.24
		"守卫":
			if guardian_stationary_time >= 1.2:
				amount *= 1.35
		"星火使": amount *= 1.0 + minf(0.50, fire_energy_heat)
	last_energy_pet = id
	return amount

func on_pet_energy_received(id: String, amount: float) -> void:
	if not active_core_skill_ids().has(id) or core_pet_control_state(id) != "normal" or not pet_link_connected(id):
		return
	for boss in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(boss) and boss.affixes.has("prism_shield") and boss.shield_time > 0.0:
			amount *= 0.50
			break
	var requirement := pet_energy_requirement(id)
	pet_energy[id] = float(pet_energy.get(id, 0.0)) + amount
	spawn_skill_effect(skill_entity_origin(id), "shield", Color("70f0ff"), 27.0)
	var release_guard := 0
	while float(pet_energy.get(id, 0.0)) + 0.001 >= requirement and release_guard < 4:
		release_guard += 1
		if not try_release_charged_pet(id):
			break
	update_skill_list()

func try_release_charged_pets() -> void:
	for id in active_core_skill_ids():
		try_release_charged_pet(id)

func pet_consumes_resonance(id: String) -> bool:
	# 引力奇点现在会造成范围伤害，和其它输出宠物一样支付共鸣；只有星辉壁垒是纯防御。
	return id in CORE_SKILL_CARD_IDS and id != "aegis"

func try_release_charged_pet(id: String) -> bool:
	var requirement := pet_energy_requirement(id)
	# 断链的宠物停摆：不再接收能量，也不释放技能，已存的能量保留。
	if float(pet_energy.get(id, 0.0)) + 0.001 < requirement or core_pet_control_state(id) != "normal" or not pet_link_connected(id):
		return false
	last_hand_patterns = active_star_patterns()
	last_hand_energy = active_hand_energy(last_hand_patterns)
	hands_played += 1
	var previous_cast_count := int(card_cast_counts.get(id, 0))
	card_cast_counts[id] = previous_cast_count + 1
	var mastery_total := 0
	for pattern in last_hand_patterns:
		mastery_total += int(pattern_mastery.get(pattern, 0))
	var resonance_spent := minf(resonance, RESONANCE_SPEND) if pet_consumes_resonance(id) else 0.0
	active_hand_multiplier = clampf(1.0 + last_hand_energy * 0.006 + resonance_spent * 0.014 + last_hand_patterns.size() * 0.06 + mastery_total * 0.03, 1.0, 2.60)
	# Consume the old pool before the synchronous cast. Damage and kills generated by
	# this cast then build a fresh pool for the next offensive pet.
	if resonance_spent > 0.0:
		resonance = maxf(0.0, resonance - resonance_spent)
	var released := cast_core_pet_from_hand(id, false)
	echo_damage_captures.erase(id)
	active_hand_multiplier = 1.0
	if not released:
		if resonance_spent > 0.0:
			resonance = clampf(resonance + resonance_spent, 0.0, MAX_RESONANCE)
		hands_played = maxi(0, hands_played - 1)
		card_cast_counts[id] = previous_cast_count
		return false
	pet_energy[id] = maxf(0.0, float(pet_energy[id]) - requirement)
	if star_bridge_hands > 0:
		star_bridge_hands -= 1
	return true

func update_pet_tethers(delta: float) -> void:
	if not is_instance_valid(player):
		return
	for key in enemy_cut_cooldown.keys():
		var left := float(enemy_cut_cooldown[key]) - delta
		if left <= 0.0:
			enemy_cut_cooldown.erase(key)
		else:
			enemy_cut_cooldown[key] = left
	var here := player.global_position
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and bool(enemy.cuts_tethers):
			enemy.tether_bait = Vector2.ZERO
	for id in active_core_skill_ids():
		var entity = skill_entities.get(id)
		if not is_instance_valid(entity):
			continue
		if not pet_link_connected(id):
			# 断开的宠物缓慢飘向玩家；玩家走到身边即可重新接上。
			if here.distance_to(entity.global_position) <= TETHER_RECONNECT_RANGE:
				reconnect_pet_tether(id)
			continue
		var grace := float(pet_link_grace.get(id, 0.0)) - delta
		if grace > 0.0:
			pet_link_grace[id] = grace
			continue
		pet_link_grace.erase(id)
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.is_boss:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, here, entity.global_position)
			var reach: float = enemy.global_position.distance_to(closest)
			# 精英怪把最近的链条当成进攻目标，普通怪只在恰好挡路时才剪断。
			if bool(enemy.cuts_tethers) and reach < MAX_ENGAGE_RANGE and reach < enemy.global_position.distance_to(enemy.tether_bait if enemy.tether_bait != Vector2.ZERO else Vector2(1e9, 1e9)):
				enemy.tether_bait = closest
			if enemy_cut_cooldown.has(enemy.get_instance_id()):
				continue
			if reach <= enemy.radius + 6.0:
				cut_pet_tether(id, enemy)
				break

func cut_pet_tether(id: String, enemy) -> void:
	pet_link_broken[id] = true
	pet_energy[id] = float(pet_energy.get(id, 0.0))
	if is_instance_valid(enemy):
		enemy_cut_cooldown[enemy.get_instance_id()] = TETHER_CUT_COOLDOWN
	var entity = skill_entities.get(id)
	if is_instance_valid(entity):
		# 断链要有反冲：宠物本来就贴在玩家身后 54~64 像素，不弹开的话
		# 下一帧就落进重连半径里，切断等于没发生。
		var away: Vector2 = entity.global_position - player.global_position
		if away.length() < 1.0:
			away = Vector2.from_angle(randf() * TAU)
		if is_instance_valid(enemy):
			away = away.normalized().lerp((entity.global_position - enemy.global_position).normalized(), 0.5)
		entity.global_position = player.global_position + away.normalized() * TETHER_SNAP_RECOIL
		spawn_skill_effect(entity.global_position, "sever", entity.entity_color(), 46.0)
	show_toast("供能链条被切断 · %s 停摆
走过去重新接上它" % card_display_name(id), Color("ef7791"), 1.4)
	play_tone(180.0, 0.12, 0.16)
	shake_camera(4.0)
	update_skill_list()

func reconnect_pet_tether(id: String) -> void:
	pet_link_broken.erase(id)
	pet_link_grace[id] = TETHER_RECONNECT_GRACE
	var entity = skill_entities.get(id)
	if is_instance_valid(entity):
		spawn_skill_effect(entity.global_position, "shield", entity.entity_color(), 52.0)
	show_toast("%s 重新连上" % card_display_name(id), Color("4ade80"), 0.8)
	play_tone(700.0, 0.09, 0.14)
	update_skill_list()

func has_any_attack_target() -> bool:
	if nearest_enemy(MAX_ENGAGE_RANGE) != null:
		return true
	for id in active_core_skill_ids():
		if nearest_enemy_from(skill_entity_origin(id), MAX_ENGAGE_RANGE) != null:
			return true
	return false

func active_star_patterns() -> Array[String]:
	var patterns: Array[String] = []
	var build_counts: Dictionary = {}
	for id in equipped_cards:
		if is_card_suppressed(id):
			continue
		var tag := card_build_type(id)
		build_counts[tag] = int(build_counts.get(tag, 0)) + 1
	for count_value in build_counts.values():
		if int(count_value) >= 2 and not patterns.has("双生式"):
			patterns.append("双生式")
		if int(count_value) >= 3 and not patterns.has("三相式"):
			patterns.append("三相式")
	if is_card_active("burn") and is_card_active("frost_brand") and is_card_active("thunder_orb") and is_card_active("gravity_well"):
		patterns.append("四象式")
	for index in equipped_cards.size():
		var id := equipped_cards[index]
		if id in CORE_SKILL_CARD_IDS and not is_card_suppressed(id):
			if index > 0 and not is_card_suppressed(equipped_cards[index - 1]) and card_build_type(equipped_cards[index - 1]) == "技能改造":
				if not patterns.has("邻接式"): patterns.append("邻接式")
			if index + 1 < equipped_cards.size() and not is_card_suppressed(equipped_cards[index + 1]) and card_build_type(equipped_cards[index + 1]) == "技能改造":
				if not patterns.has("邻接式"): patterns.append("邻接式")
			if index > 0 and index + 1 < equipped_cards.size() and not is_card_suppressed(equipped_cards[index - 1]) and not is_card_suppressed(equipped_cards[index + 1]) and card_build_type(equipped_cards[index - 1]) == card_build_type(equipped_cards[index + 1]):
				if not patterns.has("镜像式"): patterns.append("镜像式")
			if index + 1 < equipped_cards.size() and equipped_cards[index + 1] in CORE_SKILL_CARD_IDS and not is_card_suppressed(equipped_cards[index + 1]):
				if not patterns.has("双核式"): patterns.append("双核式")
	var effective_count := effective_equipped_card_count()
	if effective_count <= 3 and effective_count > 0:
		patterns.append("孤注式")
	if effective_count == MAX_CARD_SLOTS and equipped_cards.size() == MAX_CARD_SLOTS and build_counts.size() >= 5:
		patterns.append("满庭式")
	if has_valid_sequence_protocol():
		patterns.append("顺序式")
	if star_bridge_hands > 0 and not patterns.has("双核式"):
		patterns.append("双核式")
	var active_bosses := get_tree().get_nodes_in_group("bosses")
	if not active_bosses.is_empty() and active_bosses[0].weakness_time > 0.0 and effective_count >= 3:
		patterns.append("反制式")
	return patterns

func has_valid_sequence_protocol() -> bool:
	var protocol_index := equipped_cards.find("sequence_protocol")
	if protocol_index < 0 or is_card_suppressed("sequence_protocol") or protocol_index + 3 >= equipped_cards.size():
		return false
	for index in range(protocol_index, protocol_index + 4):
		if is_card_suppressed(equipped_cards[index]):
			return false
	return equipped_cards[protocol_index + 3] in CORE_SKILL_CARD_IDS

func effective_equipped_card_count() -> int:
	var count := 0
	for id in equipped_cards:
		if not is_card_suppressed(id):
			count += 1
	return count

func active_hand_energy(patterns: Array[String]) -> int:
	var active_core_count := 0
	for id in equipped_cards:
		if id in CORE_SKILL_CARD_IDS and is_card_active(id):
			active_core_count += 1
	var energy := 18 + effective_equipped_card_count() * 5 + active_core_count * 7
	for pattern in patterns:
		match pattern:
			"四象式", "满庭式": energy += 24
			"顺序式", "镜像式", "双核式", "反制式": energy += 16
			"三相式": energy += 12
			_: energy += 8
		energy += int(pattern_mastery.get(pattern, 0)) * 6
	return energy

func gain_resonance(amount: float) -> void:
	if amount > 0.0:
		wave_resonance_generated += amount
	resonance = clampf(resonance + amount, 0.0, MAX_RESONANCE)
	update_hud()

func cast_core_pet_from_hand(id: String, orbit_group_cast: bool) -> bool:
	match id:
		"aura":
			if has_aura and has_enemy_in_effect_radius(skill_entity_origin(id), aura_radius * skill_area_multiplier(id)):
				fire_aura(); return true
		"orbit", "satellite_engine", "blade_dance":
			if not orbit_group_cast and has_orbit and has_enemy_in_range_from(skill_entity_origin(id), 210.0):
				return fire_orbit_damage(id)
		"chain":
			if chain_level > 0 and nearest_enemy_from(skill_entity_origin(id), MAX_ENGAGE_RANGE) != null:
				fire_chain_lightning(); return true
		"nova":
			if nova_level > 0 and has_enemy_in_effect_radius(skill_entity_origin(id), (115.0 + nova_level * 18.0) * skill_area_multiplier(id)):
				fire_nova(); return true
		"phase_step":
			if phase_step_enabled and phase_step_cooldown <= 0.0 and nearest_enemy_from(skill_entity_origin(id), 300.0) != null:
				use_phase_step(); return true
		"thunder_orb":
			if thunder_level > 0 and nearest_enemy_from(skill_entity_origin(id), MAX_ENGAGE_RANGE) != null:
				fire_thunder_orb(); return true
		"gravity_well":
			if gravity_level > 0 and nearest_enemy_from(skill_entity_origin(id), MAX_ENGAGE_RANGE) != null:
				fire_gravity_well(); return true
		"meteor_rain":
			if meteor_level > 0 and nearest_enemy_from(skill_entity_origin(id), MAX_ENGAGE_RANGE) != null:
				fire_meteor_rain(); return true
		"aegis":
			# 必须有真实的重置间隔：挡下一击会立刻补能，否则护盾永远在，
			# 实测骑士靠它前五章一滴血都不掉。
			if aegis_level > 0 and player.shield_charges <= 0 and aegis_timer <= 0.0:
				aegis_timer = maxf(2.2, 3.4 - float(core_mastery_rank(id)) * 0.25)
				player.shield_charges = 1 + (1 if core_mastery_rank(id) >= CORE_MASTERY_MAX_RANK else 0)
				release_skill_entity(id, player.global_position); spawn_skill_effect(player.global_position, "shield", Color("70d7ff"), 48.0); return true
		"execute":
			if execute_enabled and fire_execute():
				return true
	return false

func fire_execute() -> bool:
	var execute_ratio := 0.20 + core_mastery_rank("execute") * 0.015
	var origin := skill_entity_origin("execute")
	var target: Enemy = null
	var lowest_ratio := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and origin.distance_to(node.global_position) <= 340.0 + node.radius and not node.is_boss and node.health <= node.max_health * execute_ratio:
			var health_ratio: float = node.health / maxf(1.0, node.max_health)
			if health_ratio < lowest_ratio:
				lowest_ratio = health_ratio
				target = node
	if is_instance_valid(target):
		release_skill_entity("execute", target.global_position)
		spawn_skill_effect(target.global_position, "sever", pet_color("execute"), 42.0)
		deal_skill_damage(target, calculate_skill_damage(26.0, "execute", target), "execute", Vector2.ZERO, "execute")
		if target.health <= 0.0:
			record_core_mastery("execute")
		return true
	return false

func has_enemy_in_range_from(origin: Vector2, range_limit: float) -> bool:
	return nearest_enemy_from(origin, range_limit) != null

func has_enemy_in_effect_radius(origin: Vector2, radius: float) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and origin.distance_to(node.global_position) <= radius + node.radius:
			return true
	return false

func count_enemies_in_range(center: Vector2, range_limit: float) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and center.distance_squared_to(node.global_position) <= range_limit * range_limit:
			count += 1
	return count

func any_core_pet_cooling_down() -> bool:
	for id in active_core_skill_ids():
		if pet_energy_ratio(id) < 0.999:
			return true
	return false

func update_conditional_card_effects(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var speed_base := maxf(1.0, player.speed - conditional_speed_bonus)
	conditional_speed_bonus = 0.0
	if any_core_pet_cooling_down():
		if equipped_cards.has("endless_haste") and not is_card_suppressed("endless_haste"):
			conditional_speed_bonus += speed_base * 0.03 * mini(10, int(upgrade_levels.get("endless_haste", 0)))
	player.speed = speed_base + conditional_speed_bonus
	var armor_base := player.armor - conditional_armor_bonus
	conditional_armor_bonus = 0.0
	player.armor = armor_base + conditional_armor_bonus
	if elapsed - last_hurt_elapsed >= OUT_OF_COMBAT_DELAY and player.health < player.max_health:
		player.heal(player.max_health * OUT_OF_COMBAT_REGEN * delta)
	if equipped_cards.has("endless_vitality") and not is_card_suppressed("endless_vitality") and elapsed - last_hurt_elapsed >= 4.0 and player.health < player.max_health:
		player.heal(0.15 * mini(10, int(upgrade_levels.get("endless_vitality", 0))) * delta)

func skill_area_multiplier(source_id: String) -> float:
	var result := float(stats.area) * core_mastery_area_factor(source_id)
	if source_id == "gravity_well" and active_relics.has("rift_compass"):
		result *= 1.0 + 0.35 * relic_rank("rift_compass")
	if equipped_cards.has("area") and not is_card_suppressed("area") and count_enemies_in_range(skill_entity_origin(source_id), 520.0) >= 2:
		result *= pow(1.12, int(upgrade_levels.get("area", 0)))
	return result

func effective_magnet_range() -> float:
	var result := float(stats.magnet)
	return result

func nearest_enemy(range_limit := MAX_ENGAGE_RANGE) -> Enemy:
	return nearest_enemy_from(player.global_position, range_limit)

func preferred_enemy_from(origin: Vector2, range_limit := MAX_ENGAGE_RANGE) -> Enemy:
	range_limit = minf(range_limit, MAX_ENGAGE_RANGE)
	# Boss 在场时优先咬 Boss：否则 AoE 构筑的伤害会被杂兵全部吸走。
	for boss in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(boss) and origin.distance_to(boss.global_position) <= range_limit + boss.radius:
			return boss
	return nearest_enemy_from(origin, range_limit)

func nearest_enemy_from(origin: Vector2, range_limit := MAX_ENGAGE_RANGE) -> Enemy:
	range_limit = minf(range_limit, MAX_ENGAGE_RANGE)
	var closest: Enemy
	var best := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		var d: float = origin.distance_squared_to(node.global_position)
		if d <= range_limit * range_limit and d < best:
			best = d
			closest = node
	return closest

func fire_pulse() -> void:
	# 供能不再是发射弹丸，而是沿链条连续注入。这里按一个「脉冲」的额度结算，
	# 总吞吐与原来一致（每次额度 = 原来一枚弹的能量），只是不再有飞行物。
	var targets := selectable_energy_pet_ids()
	if targets.is_empty():
		if lone_star_protocol_active() and has_any_attack_target():
			fire_lone_star_spark()
		return
	var surged := surge_pulses > 0
	if surged:
		surge_pulses -= 1
	var fed := 0
	for id in targets:
		if not is_instance_valid(skill_entities.get(id)):
			continue
		on_pet_energy_received(id, energy_amount_for_pet(id) * (1.5 if surged else 1.0))
		fed += 1
	if player.character_name == "星火使" and fed > 0:
		fire_energy_heat = minf(0.50, fire_energy_heat + 0.055)
	if fed > 0:
		play_tone(420.0 + randf_range(-16, 16), 0.025, 0.045)
	if lone_star_protocol_active() and has_any_attack_target():
		fire_lone_star_spark()

func fire_lone_star_spark() -> bool:
	var target := nearest_enemy_from(player.global_position, MAX_ENGAGE_RANGE)
	if not is_instance_valid(target):
		return false
	# 独立的低强度保底：不读取卡牌链、暴击、版本、共鸣、封印与养成。
	var damage := 3.2 * float(stats.damage)
	target.take_damage(damage, (target.global_position - player.global_position).normalized() * 18.0, "lone_star")
	spawn_skill_effect(target.global_position, "cast", Color("70d7ff"), 34.0)
	play_tone(330.0, 0.025, 0.035)
	return true

func deal_skill_damage(target: Enemy, amount: float, source_id: String, knockback := Vector2.ZERO, damage_type := "") -> void:
	if not is_instance_valid(target):
		return
	# 记录本次伤害的来源宠物，让飘字与击杀特效能标出「是谁打的」
	last_damage_color = pet_color(source_id) if source_id in CORE_SKILL_CARD_IDS else Color("e8f5ff")
	# 在所有反应倍率完成后再快照，回响才能复现最终实际伤害。
	if echo_damage_captures.has(source_id):
		var captured: Array = echo_damage_captures[source_id]
		captured.append({"target":target, "damage":amount})
	target.take_damage(amount, knockback, damage_type)

func fire_aura() -> void:
	var origin := skill_entity_origin("aura")
	var target := nearest_enemy_from(origin, aura_radius * skill_area_multiplier("aura") + 45.0)
	release_skill_entity("aura", target.global_position if is_instance_valid(target) else origin)
	var radius := aura_radius * skill_area_multiplier("aura")
	spawn_skill_effect(origin, "field", pet_color("aura"), radius)
	var hit_count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and origin.distance_to(node.global_position) <= radius + node.radius:
			hit_count += 1
			var aura_damage := calculate_skill_damage(10.0, "aura", node)
			deal_skill_damage(node, aura_damage, "aura", (node.global_position - origin).normalized() * 35.0)
			if aura_ignite:
				node.apply_burn(aura_damage * 0.18 * skill_status_multiplier("aura"), 1.8)
			if evolutions.has("stellar_lattice"):
				node.apply_resonance(1.25)
	if hit_count >= 4:
		record_core_mastery("aura")

func fire_orbit_damage(source_id := "") -> bool:
	var active_blade_level := blade_level if is_card_active("blade_dance") else 0
	var orbit_source: String = source_id if source_id in ["orbit", "satellite_engine", "blade_dance"] else orbit_pet_source_id()
	var origin := skill_entity_origin(orbit_source)
	var positions: Array[Vector2] = []
	var orbit_bonus := int(floor(core_mastery_rank("orbit") / 2.0)) if is_card_active("orbit") else 0
	var satellite_bonus := int(floor(core_mastery_rank("satellite_engine") / 2.0)) if is_card_active("satellite_engine") else 0
	var effective_orbit_count := maxi(1, orbit_count + orbit_bonus + satellite_bonus)
	var orbit_radius := 104.0 + core_mastery_rank("blade_dance") * 4.0
	var spin := Time.get_ticks_msec() * (0.0022 + core_mastery_rank("blade_dance") * 0.00012)
	for i in effective_orbit_count:
		positions.append(origin + Vector2.from_angle(spin + TAU * i / effective_orbit_count) * orbit_radius)
	# 卫星是「点」，命中窗口只有 30 像素，实测守卫一整章只能触发 30 多次、直接被淹。
	# 改成整片扫过：卫星高速旋转扫开轨道半径以内的全部敌人。注意不能只判环带——
	# 那样冲到宠物脸上的敌人反而免疫，威胁与距离的关系是反的。
	var ring_band := 26.0 + float(effective_orbit_count) * 3.0
	var hit_targets: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		if origin.distance_to(node.global_position) < orbit_radius + ring_band + node.radius:
			hit_targets.append(node)
	if hit_targets.is_empty():
		return false
	spawn_skill_effect(origin, "blades", pet_color(orbit_source), orbit_radius + ring_band)
	var orbit_target_position: Vector2 = hit_targets[0].global_position
	for orbit_entity_id in ["orbit", "satellite_engine", "blade_dance"]:
		if skill_entities.has(orbit_entity_id):
			release_skill_entity(orbit_entity_id, orbit_target_position, orbit_entity_id == orbit_source)
	var hit_count := 0
	for node in hit_targets:
		hit_count += 1
		var orbit_damage := calculate_skill_damage(6.0 + float(effective_orbit_count) * 2.5 + active_blade_level * 7.0, orbit_source, node)
		if evolutions.has("stellar_lattice") and node.consume_resonance():
			orbit_damage *= 2.25
		if active_combo_names().has("瞬身刃舞") and active_blade_level > 0 and node.consume_phase_mark():
			orbit_damage *= 2.0
			spawn_skill_effect(node.global_position, "dash", Color("70f0ff"), 70.0)
		deal_skill_damage(node, orbit_damage, orbit_source, Vector2.ZERO, "reaction")
	if hit_count >= 3 and is_card_active("orbit"):
		record_core_mastery("orbit")
	if hit_count >= 2 and is_card_active("satellite_engine"):
		record_core_mastery("satellite_engine")
	if hit_count >= 3 and is_card_active("blade_dance"):
		record_core_mastery("blade_dance")
	return true

func fire_chain_lightning() -> void:
	var current := preferred_enemy_from(skill_entity_origin("chain"), MAX_ENGAGE_RANGE)
	if current == null:
		return
	release_skill_entity("chain", current.global_position)
	var visited: Dictionary = {}
	var arc_path := PackedVector2Array([skill_entity_origin("chain")])
	var jumps := 2 + chain_level + int(floor(core_mastery_rank("chain") / 2.0))
	if active_relics.has("storm_relay"):
		jumps += 2 * relic_rank("storm_relay")
	for jump in jumps:
		if current == null:
			break
		visited[current.get_instance_id()] = true
		arc_path.append(current.global_position)
		deal_skill_damage(current, calculate_skill_damage(12.0 + chain_level * 3.0, "chain", current), "chain", Vector2.ZERO, "chain")
		if evolutions.has("molten_circuit"):
			current.apply_shock()
		if active_combo_names().has("风暴导体"):
			current.apply_conductive()
		var next: Enemy
		var best := INF
		for node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(node) and not visited.has(node.get_instance_id()):
				var distance := current.global_position.distance_squared_to(node.global_position)
				if distance < 260.0 * 260.0 and distance < best:
					best = distance
					next = node
		current = next
	spawn_arc_path_effect("chain", arc_path)
	if visited.size() >= 3:
		record_core_mastery("chain")
	play_tone(690.0, 0.05, 0.11)

func fire_nova() -> void:
	var origin := skill_entity_origin("nova")
	var target := nearest_enemy_from(origin, (115.0 + nova_level * 18.0) * skill_area_multiplier("nova") + 45.0)
	release_skill_entity("nova", target.global_position if is_instance_valid(target) else origin)
	var radius := (115.0 + nova_level * 18.0) * skill_area_multiplier("nova")
	var hit_count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and origin.distance_to(node.global_position) <= radius + node.radius:
			hit_count += 1
			var nova_damage := calculate_skill_damage(26.0 + nova_level * 6.0, "nova", node)
			if active_combo_names().has("坍缩爆心"):
				var collapse: int = node.consume_collapse()
				if collapse > 0:
					nova_damage *= 1.0 + minf(0.8, collapse * 0.10)
					spawn_skill_effect(node.global_position, "gravity", Color("c084fc"), 55.0)
			deal_skill_damage(node, nova_damage, "nova", (node.global_position - origin).normalized() * 180.0, "reaction")
	if hit_count >= 4:
		record_core_mastery("nova")
	show_toast("星核爆破", Color("facc15"), 0.35)
	spawn_skill_effect(origin, "field", pet_color("nova"), radius)
	play_tone(240.0, 0.12, 0.18)

func fire_thunder_orb() -> void:
	var target := preferred_enemy_from(skill_entity_origin("thunder_orb"), MAX_ENGAGE_RANGE)
	if target == null:
		return
	release_skill_entity("thunder_orb", target.global_position)
	var radius := (72.0 + thunder_level * 10.0) * skill_area_multiplier("thunder_orb")
	if active_relics.has("storm_relay"):
		radius *= 1.0 + 0.25 * relic_rank("storm_relay")
	var conducted := active_combo_names().has("风暴导体") and target.consume_conductive()
	var mastery_target := target.is_boss or target.kind in ["重甲怪", "咒术师"]
	var hit_count := 0
	if conducted:
		radius *= 1.45
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.global_position.distance_to(target.global_position) <= radius + node.radius:
			hit_count += 1
			mastery_target = mastery_target or node.is_boss or node.kind in ["重甲怪", "咒术师"]
			var thunder_damage := calculate_skill_damage(22.0 + thunder_level * 6.0, "thunder_orb", node) * (1.55 if conducted else 1.0)
			deal_skill_damage(node, thunder_damage, "thunder_orb", Vector2.ZERO, "reaction" if conducted else "thunder")
	if mastery_target or hit_count >= 3:
		record_core_mastery("thunder_orb")
	show_toast("雷暴法球", Color("70d7ff"), 0.28)
	spawn_skill_effect(target.global_position, "thunder", pet_color("thunder_orb"), radius)
	play_tone(760.0, 0.06, 0.1)

func fire_gravity_well() -> void:
	var target := preferred_enemy_from(skill_entity_origin("gravity_well"), MAX_ENGAGE_RANGE)
	if target == null:
		return
	release_skill_entity("gravity_well", target.global_position)
	var gravity_radius := 220.0 * skill_area_multiplier("gravity_well")
	var pulled_count := 0
	var pull_factor := 1.0 + core_mastery_rank("gravity_well") * 0.10
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.global_position.distance_to(target.global_position) < gravity_radius:
			pulled_count += 1
			node.knockback += (target.global_position - node.global_position).normalized() * (130.0 + gravity_level * 55.0) * pull_factor
			deal_skill_damage(node, calculate_skill_damage(11.0 + gravity_level * 4.0, "gravity_well", node), "gravity_well", Vector2.ZERO, "reaction")
			if active_combo_names().has("坍缩爆心"):
				node.apply_collapse(1)
	if pulled_count >= 5:
		record_core_mastery("gravity_well")
	show_toast("引力奇点", Color("c084fc"), 0.3)
	spawn_skill_effect(target.global_position, "gravity", pet_color("gravity_well"), gravity_radius)

func fire_meteor_rain() -> void:
	var target := preferred_enemy_from(skill_entity_origin("meteor_rain"), MAX_ENGAGE_RANGE)
	if target == null:
		return
	release_skill_entity("meteor_rain", target.global_position)
	var meteor_radius := 105.0 * skill_area_multiplier("meteor_rain")
	var hit_count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.global_position.distance_to(target.global_position) < meteor_radius + node.radius:
			hit_count += 1
			var meteor_damage := calculate_skill_damage(31.0 + meteor_level * 9.0, "meteor_rain", node)
			if active_combo_names().has("极寒天火") and node.consume_frost():
				meteor_damage *= 1.7
				spawn_skill_effect(node.global_position, "nova", Color("93c5fd"), 68.0)
			deal_skill_damage(node, meteor_damage, "meteor_rain", Vector2.ZERO, "reaction")
	if hit_count >= 4:
		record_core_mastery("meteor_rain")
	show_toast("陨星坠落", Color("ffbd69"), 0.35)
	spawn_skill_effect(target.global_position, "meteor", pet_color("meteor_rain"), meteor_radius)

func use_phase_step() -> void:
	if not phase_step_enabled or phase_step_cooldown > 0.0 or not is_card_active("phase_step") or not is_instance_valid(player):
		return
	phase_step_cooldown = PHASE_STEP_COOLDOWN
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() < 0.1:
		var target := nearest_enemy_from(skill_entity_origin("phase_step"), 300.0)
		direction = (target.global_position - player.global_position).normalized() if is_instance_valid(target) else Vector2.RIGHT.rotated(player.rotation)
	direction = direction.normalized()
	var old_position := player.global_position
	var destination := old_position + direction * 250.0
	release_skill_entity("phase_step", destination)
	player.global_position = destination
	award_achievement("phase_traveler")
	spawn_capsule_effect(old_position, "phase_step", 250.0, 76.0, direction)
	player.invulnerable = maxf(player.invulnerable, PHASE_STEP_INVULNERABILITY)
	var hit_count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.global_position.distance_to(Geometry2D.get_closest_point_to_segment(node.global_position, old_position, destination)) < 38.0 + node.radius:
			hit_count += 1
			deal_skill_damage(node, calculate_skill_damage(26.0, "phase_step", node), "phase_step", direction * 90.0, "phase")
			if active_combo_names().has("瞬身刃舞"):
				node.apply_phase_mark()
	if hit_count >= 2:
		record_core_mastery("phase_step")
	show_toast("相位突进 · 供能释放", Color("70f0ff"), 0.7)

func calculate_damage(base: float) -> float:
	var result := base * float(stats.damage)
	if randf() < clampf(float(stats.crit), 0.0, 0.85):
		result *= 2.0 + bonus_crit_damage
	return result

func spawn_enemy_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	if state != GameState.PLAYING:
		return
	var projectile: Projectile = ProjectileScript.new()
	projectile.position = origin
	projectile.direction = direction
	projectile.speed = 260.0
	projectile.damage = damage
	projectile.radius = 7.0
	projectile.enemy_shot = true
	projectile.target_player = player
	projectile.lifetime = 5.0
	projectile_root.add_child(projectile)
	projectile.queue_redraw()

func on_enemy_defeated(enemy: Enemy, value: int) -> void:
	# 星屑是纯局内货币。Boss使用独立且受控的奖励值，避免旧经验值造成
	# 连续升级式的经济爆炸；普通敌人改为概率掉落，维持逐关购买节奏。
	var death_position := enemy.global_position
	var shard_value := roll_enemy_shard_reward(enemy.is_boss, enemy.kind)
	gain_resonance(18.0 if enemy.is_boss else 3.0)
	if enemy.is_boss and equipped_cards.has("rocket"):
		shard_value += 2 + boss_kills
	if enemy.is_boss:
		gain_star_shards(shard_value)
	elif shard_value > 0:
		spawn_pickup("shard", shard_value, death_position)
	if burn_burst and enemy.burn_time > 0.0:
		for node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(node) and node != enemy and node.global_position.distance_to(death_position) < 92.0:
				node.take_damage(calculate_damage(10.0), Vector2.ZERO, "burn_burst")
		spawn_skill_effect(death_position, "nova", Color("fb923c"), 92.0)
	if not enemy.is_boss:
		if equipped_cards.has("green_momentum"):
			green_momentum_stacks = mini(10, green_momentum_stacks + 1)
		streak_count += 1
		streak_timer = 4.0
		if momentum_enabled and streak_count >= 10:
			streak_count = 0
			surge_pulses = 2
			player.heal(8.0)
			award_achievement("streak_master")
			show_toast("连杀节拍！恢复8生命 · 下2枚供能弹强化", Color("facc15"), 1.2)
	kills += 1
	if soul_siphon_level > 0 and randf() < 0.08 * soul_siphon_level:
		player.heal(3.0)
		show_toast("灵魂汲取", Color("4ade80"), 0.35)
	if randf() < 0.045 + float(stats.luck):
		spawn_pickup("heal", 18, death_position + Vector2(-18, 0))
	if enemy.is_boss:
		var story_chapter := int(enemy.get_meta("story_chapter", 0))
		var blue_seal_count := 0
		for sealed_id in card_seals:
			if equipped_cards.has(str(sealed_id)) and str(card_seals[sealed_id]) == "blue":
				blue_seal_count += 1
		if blue_seal_count > 0:
			var patterns := active_star_patterns().filter(func(pattern): return int(pattern_mastery.get(pattern, 0)) < 3)
			if not patterns.is_empty():
				patterns.sort_custom(func(a, b): return int(pattern_mastery.get(a, 0)) < int(pattern_mastery.get(b, 0)))
				var completed_research := 0
				for seal_index in blue_seal_count:
					patterns = patterns.filter(func(pattern): return int(pattern_mastery.get(pattern, 0)) < 3)
					if patterns.is_empty():
						break
					patterns.sort_custom(func(a, b): return int(pattern_mastery.get(a, 0)) < int(pattern_mastery.get(b, 0)))
					var pattern: String = patterns[0]
					pattern_mastery[pattern] = mini(3, int(pattern_mastery.get(pattern, 0)) + 1)
					completed_research += 1
				if completed_research > 0:
					show_toast("蓝蜡封研究 · 完成%d次星式研究" % completed_research, Color("70d7ff"), 1.0)
		clear_boss_card_disruptions(enemy)
		boss_kills += 1
		# 终章的压力主要来自群怪的持续接触伤害，护甲成长正好作用在这里。
		player.increase_max_health(BOSS_CLEAR_MAX_HEALTH)
		player.armor += BOSS_CLEAR_ARMOR
		var boss_heal := player.max_health * BOSS_CLEAR_HEAL
		player.heal(boss_heal)
		show_toast("关卡结算 · 最大生命 +%d · 护甲 +%d · 恢复 %d 生命" % [int(BOSS_CLEAR_MAX_HEALTH), int(BOSS_CLEAR_ARMOR), int(boss_heal)], Color("4ade80"), 1.4)
		campfire_stacks = 0
		award_boss_achievements(enemy)
		call_deferred("show_boss_reward", enemy.kind, story_chapter)
		show_toast("%s已击败 · 战利品宝箱开启" % enemy.kind, Color("facc15"))
		play_tone(880, 0.2, 0.25)
		if not endless_mode and boss_kills >= 6:
			mainline_completion_pending = true

func award_boss_achievements(boss: Enemy) -> void:
	var boss_name := str(boss.kind)
	award_achievement("boss_breaker")
	match boss_name:
		"星渊追猎者": award_achievement("chaser_breaker")
		"星渊禁锢者": award_achievement("warden_breaker")
		"星渊裁决者": award_achievement("judge_breaker")
	var damage_at_spawn := float(boss.get_meta("damage_taken_at_spawn", damage_taken_this_run))
	if damage_taken_this_run <= damage_at_spawn + 0.001:
		award_achievement("flawless_boss")
	if player.health <= player.max_health * 0.25:
		award_achievement("last_stand_boss")
	if player.health >= player.max_health * 0.95:
		award_achievement("healthy_boss")
	check_achievement_progress()

func roll_enemy_shard_reward(is_boss: bool, enemy_kind: String = "") -> int:
	if is_boss:
		return 6 + int(floor(boss_kills * 0.75))
	if enemy_kind in ["重甲怪", "咒术师"]:
		return 2
	var drop_chance := clampf(0.36 - float(current_mainline_chapter()) * 0.035, 0.14, 0.36) + clampf(float(stats.get("luck", 0.0)), 0.0, 0.12)
	return 1 if randf() < drop_chance else 0

func show_boss_reward(_boss_name: String, story_chapter := 0) -> void:
	if state == GameState.GAME_OVER or not is_instance_valid(ui_layer):
		return
	if is_instance_valid(boss_reward_overlay):
		pending_boss_rewards.append({"boss_name":_boss_name, "story_chapter":story_chapter})
		return
	state = GameState.LEVEL_UP
	get_tree().paused = true
	player.selection_protected = true
	player.can_move = false
	boss_reward_overlay = full_rect_control()
	boss_reward_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(boss_reward_overlay)
	add_dim_background(boss_reward_overlay, 0.78)
	var box := VBoxContainer.new()
	box.position = Vector2(100, 60)
	box.size = Vector2(1080, 600)
	box.add_theme_constant_override("separation", 10)
	boss_reward_overlay.add_child(box)
	var title := make_label("Boss 战利品宝箱  ·  选择一件稀有战利品", 34, Color("facc15"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var memory := boss_memory_for_chapter(story_chapter)
	var memory_label := make_label("获得记忆碎片 · %s\n%s\n完整内容已收入星渊档案" % [str(memory.title), str(memory.text)], 16, Color("c7d7eb"))
	memory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memory_label.custom_minimum_size.y = 70
	box.add_child(memory_label)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var pool: Array = BOSS_RELICS.filter(func(relic): return relic_rank(str(relic.id)) < 3)
	pool.shuffle()
	var relic_count := 2 if not active_core_skill_ids().is_empty() else 3
	var offered_relic_count := mini(relic_count, pool.size())
	for relic in pool.slice(0, offered_relic_count):
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var current_rank := relic_rank(str(relic.id))
		var rank_marks := ["Ⅰ", "Ⅱ", "Ⅲ"]
		var rank_text := "首次获得" if current_rank == 0 else "共鸣升级　%s→%s" % [rank_marks[current_rank - 1], rank_marks[current_rank]]
		button.text = "%s\n【%s · %s】\n\n%s" % [relic.name, str(relic.get("type", "稀有遗物")), rank_text, relic.desc]
		button.icon = make_skill_icon(relic.id)
		button.add_theme_constant_override("icon_max_width", 92)
		button.expand_icon = false
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", CARD_RARITY_COLORS["传奇"])
		button.add_theme_color_override("font_hover_color", Color("fff3c4"))
		button.add_theme_stylebox_override("normal", panel_style(Color("241c35"), 18, Color("facc15"), 3))
		button.add_theme_stylebox_override("hover", panel_style(Color("3a2a50"), 18, Color("fff3c4"), 3))
		button.pressed.connect(select_boss_relic.bind(relic.id))
		row.add_child(button)
	var core_ids := active_core_skill_ids()
	if not core_ids.is_empty():
		# Six relics cap at resonance III.  Once the pool becomes small, fill the
		# chest back to three meaningful choices with distinct pet editions so
		# endless Bosses never degrade into a one-button or empty reward screen.
		var edition_offer_count := maxi(1, 3 - offered_relic_count)
		var edition_pairs: Array[Dictionary] = []
		for target_id in core_ids:
			for edition in compatible_editions_for_card(target_id):
				edition_pairs.append({"target_id":target_id, "edition":edition})
		edition_pairs.shuffle()
		for offer_index in mini(edition_offer_count, edition_pairs.size()):
			var pair: Dictionary = edition_pairs[offer_index]
			add_boss_edition_reward(row, str(pair.target_id), pair.edition)

func add_boss_edition_reward(row: HBoxContainer, target_id: String, edition: Dictionary) -> void:
	var edition_button := Button.new()
	edition_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edition_button.text = "%s版本 · %s\n\n改造宠物【%s】\n%s\n\n卡牌改造" % [edition.name, edition.desc, card_display_name(target_id), "不增加卡牌、不占额外槽位"]
	edition_button.icon = make_skill_icon(target_id)
	edition_button.add_theme_constant_override("icon_max_width", 92)
	edition_button.expand_icon = false
	edition_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edition_button.add_theme_font_size_override("font_size", 20)
	var target_rarity_color: Color = CARD_RARITY_COLORS.get(card_rarity(target_id), Color("9bb4d1"))
	edition_button.add_theme_color_override("font_color", target_rarity_color)
	edition_button.add_theme_color_override("font_hover_color", target_rarity_color.lightened(0.16))
	edition_button.add_theme_stylebox_override("normal", panel_style(Color("182b3f"), 18, Color("70d7ff"), 3))
	edition_button.add_theme_stylebox_override("hover", panel_style(Color("214866"), 18, Color("e8f5ff"), 3))
	edition_button.pressed.connect(select_boss_card_edition.bind(target_id, str(edition.id)))
	row.add_child(edition_button)

func finish_boss_reward_selection() -> void:
	if is_instance_valid(boss_reward_overlay):
		boss_reward_overlay.queue_free()
	boss_reward_overlay = null
	if not pending_boss_rewards.is_empty():
		var next_reward: Dictionary = pending_boss_rewards.pop_front()
		call_deferred("show_boss_reward", str(next_reward.boss_name), int(next_reward.story_chapter))
		return
	if mainline_completion_pending and not endless_mode:
		call_deferred("show_mainline_completion_choice")
		return
	player.selection_protected = false
	player.can_move = true
	player.invulnerable = maxf(player.invulnerable, 0.8)
	state = GameState.PLAYING
	get_tree().paused = false
	# Boss宝箱本身已经是一轮构筑选择；不再紧接着强制弹出商店。
	# 下一家定时商店保证提供与当前宠物相关的搭档牌。
	directed_shop_pending = true
	# Boss 战期间被锁住的商店是玩家已经挣到的，打完就该兑现，
	# 否则「打得慢 -> 商店被吞 -> 更打不动」的负反馈会一直闭合。
	shop_pending = queued_shops > 0
	next_shop_time = maxf(next_shop_time, elapsed + 20.0)

func show_mainline_completion_choice() -> void:
	if state == GameState.GAME_OVER or endless_mode or not mainline_completion_pending or is_instance_valid(mainline_complete_overlay):
		return
	state = GameState.LEVEL_UP
	get_tree().paused = true
	player.selection_protected = true
	player.can_move = false
	mainline_complete_overlay = full_rect_control()
	mainline_complete_overlay.name = "MainlineCompleteOverlay"
	mainline_complete_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(mainline_complete_overlay)
	add_dim_background(mainline_complete_overlay, 0.88)
	var panel := PanelContainer.new()
	panel.position = Vector2(250, 105)
	panel.size = Vector2(780, 510)
	panel.add_theme_stylebox_override("panel", panel_style(Color("0c1830"), 24, Color("facc15"), 3))
	mainline_complete_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := make_label("六章主线完成", 46, Color("facc15"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var summary := make_label("大灯塔重新亮起，这次远征已经取得胜利。\n现在可以带着成果完成结算，也可以继续深入无尽星潮。", 22, Color("d8e5f3"))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(summary)
	var settle := make_button("完成远征 · 胜利结算", Vector2(720, 64))
	settle.process_mode = Node.PROCESS_MODE_ALWAYS
	settle.pressed.connect(complete_mainline_run)
	box.add_child(settle)
	var endless := make_button("继续挑战 · 进入无尽模式", Vector2(720, 64))
	endless.process_mode = Node.PROCESS_MODE_ALWAYS
	endless.pressed.connect(continue_to_endless)
	box.add_child(endless)

func complete_mainline_run() -> void:
	mainline_completion_pending = false
	if is_instance_valid(mainline_complete_overlay):
		mainline_complete_overlay.queue_free()
	mainline_complete_overlay = null
	end_run(true)

func continue_to_endless() -> void:
	mainline_completion_pending = false
	if is_instance_valid(mainline_complete_overlay):
		mainline_complete_overlay.queue_free()
	mainline_complete_overlay = null
	player.selection_protected = false
	player.can_move = true
	player.invulnerable = maxf(player.invulnerable, 0.8)
	state = GameState.PLAYING
	get_tree().paused = false
	directed_shop_pending = true
	start_endless_mode()

func select_boss_card_edition(card_id: String, edition_id: String) -> void:
	card_editions[card_id] = edition_id
	check_achievement_progress()
	show_toast("Boss改造：%s 获得【%s】版本" % [card_display_name(card_id), card_edition_name(edition_id)], Color("70d7ff"), 2.0)
	play_tone(980.0, 0.16, 0.22)
	update_deck_card_row()
	finish_boss_reward_selection()

func select_boss_relic(id: String) -> void:
	var previous_rank := relic_rank(id)
	if previous_rank >= 3:
		return
	active_relics[id] = previous_rank + 1
	award_achievement("relic_" + id)
	match id:
		"predator_boots": player.speed *= 1.12; stats.cooldown = maxf(0.55, float(stats.cooldown) * 0.92)
		"aegis_fragment": player.increase_max_health(12.0); player.armor += 1.0; player.shield_charges += 1
		"rift_compass": stats.area *= 1.15
		"judge_spark": stats.crit = minf(0.85, float(stats.crit) + 0.10); bonus_crit_damage += 0.20
		"ember_vessel": burn_burst = true
		"storm_relay": pass
	check_achievement_progress()
	var selected_relic: Dictionary = BOSS_RELICS.filter(func(relic): return relic.id == id)[0]
	show_toast("获得%s · %s　共鸣%d/3\n%s" % [str(selected_relic.get("type", "稀有遗物")), selected_relic.name, relic_rank(id), relic_story_line(id)], Color("facc15"), 2.8)
	refresh_derived_card_effects()
	check_evolutions()
	finish_boss_reward_selection()

func award_character_achievement(character_name: String) -> void:
	var ids := {"游侠":"ranger_journey", "骑士":"knight_journey", "星术师":"mage_journey", "守卫":"guardian_journey", "影舞者":"dancer_journey", "星火使":"fire_journey"}
	var achievement_id: String = ids.get(character_name, "")
	if achievement_id != "":
		award_achievement(achievement_id)

func award_achievement(id: String) -> void:
	if test_mode:
		return
	var before_story_ids := unlocked_story_ids()
	if SaveManager.add_achievement(id):
		var new_story_ids := newly_unlocked_story_ids(before_story_ids)
		for story_id in new_story_ids:
			if not run_new_story_ids.has(story_id):
				run_new_story_ids.append(story_id)
		var matches := ACHIEVEMENTS.filter(func(item): return item.id == id)
		if not matches.is_empty():
			var unlocked_character := character_unlocked_by_achievement(id)
			var message := "成就解锁 · %s" % matches[0].name
			if unlocked_character != "":
				message += "\n新角色解锁 · %s" % unlocked_character
			if not new_story_ids.is_empty():
				var first_story: Dictionary = StoryArchiveData.get_entry(new_story_ids[0])
				message += "\n新记忆归档 · %s" % str(first_story.title)
				if new_story_ids.size() > 1:
					message += " 等%d篇" % new_story_ids.size()
			show_toast(message, Color("c084fc"), 2.6 if unlocked_character != "" else 2.0)

func check_achievement_progress() -> void:
	if not is_instance_valid(player):
		return
	if kills >= 1: award_achievement("first_blood")
	if kills >= 50: award_achievement("fifty_fallen")
	if kills >= 100: award_achievement("hundred_fallen")
	if kills >= 250: award_achievement("swarm_breaker")
	if total_star_shards >= 20: award_achievement("level_five")
	if total_star_shards >= 50: award_achievement("level_ten")
	if total_star_shards >= 120: award_achievement("level_twenty")
	if total_star_shards >= 250: award_achievement("level_thirty")
	if spent_star_shards >= 30: award_achievement("shop_spree")
	if elapsed >= 60.0: award_achievement("survive_minute")
	if elapsed >= 180.0: award_achievement("survive_three")
	if elapsed >= 360.0: award_achievement("survive_six")
	if elapsed >= 60.0 and damage_taken_this_run <= 0.0: award_achievement("untouchable_minute")
	if boss_kills >= 3: award_achievement("boss_trio")
	if boss_kills >= 4: award_achievement("fourth_seal")
	if boss_kills >= 5: award_achievement("fifth_seal")
	if boss_kills >= 6: award_achievement("six_seals")
	if active_relics.size() >= 1: award_achievement("first_relic")
	if active_relics.size() >= 3: award_achievement("relic_trinity")
	if active_relics.size() >= 6: award_achievement("relic_master")
	if endless_mode and endless_wave >= 3: award_achievement("endless_three")
	if endless_mode and endless_wave >= 6: award_achievement("endless_six")
	if endless_mode and endless_wave >= 9: award_achievement("endless_nine")
	if endless_mode and endless_wave >= 12: award_achievement("endless_twelve")
	if endless_mode and endless_wave >= 15: award_achievement("endless_fifteen")
	if endless_mode and endless_wave >= 20: award_achievement("endless_twenty")
	if active_combo_count() >= 2: award_achievement("combo_duet")
	if active_combo_count() >= 4: award_achievement("combo_quartet")
	if is_card_active("burn") and is_card_active("frost_brand") and is_card_active("thunder_orb"):
		award_achievement("elemental_trinity")
	if equipped_cards.size() >= 5: award_achievement("five_core")
	if card_slots >= 5 and equipped_cards.size() >= card_slots: award_achievement("deck_full")
	if card_slots >= 6: award_achievement("slot_six")
	if card_slots >= MAX_CARD_SLOTS: award_achievement("slot_seven")
	var edition_pet_count := 0
	for edition_pet_id in active_core_skill_ids():
		if card_editions.has(edition_pet_id):
			edition_pet_count += 1
	if core_engine_level >= 1 and edition_pet_count >= 2: award_achievement("engine_master")
	if combo_catalyst_level >= 1 and active_combo_count() >= 2: award_achievement("catalyst_master")
	if int(upgrade_levels.get("glass", 0)) >= 1: award_achievement("glass_edge")
	var glass_index := equipped_cards.find("glass")
	if glass_index > 0:
		for left_index in glass_index:
			var left_id := equipped_cards[left_index]
			if left_id in CORE_SKILL_CARD_IDS and card_editions.has(left_id):
				award_achievement("shattered_cannon")
				break
	if int(upgrade_levels.get("gamble", 0)) >= 1: award_achievement("gamblers_oath")
	if int(upgrade_levels.get("glass", 0)) >= 1 and int(upgrade_levels.get("gamble", 0)) >= 1:
		award_achievement("double_or_nothing")
	if configured_core_crit_chance() >= 0.50: award_achievement("crit_half")
	if configured_core_crit_chance() >= 0.85: award_achievement("crit_cap")
	if player.health > 0.0 and player.health <= player.max_health * 0.20: award_achievement("last_stand")
	if aegis_level >= 1: award_achievement("aegis_bearer")
	if soul_siphon_level >= 1: award_achievement("soul_master")
	if not card_editions.is_empty(): award_achievement("core_max")
	if SaveManager.data.achievements.size() >= 10: award_achievement("achievement_ten")
	if SaveManager.data.achievements.size() >= 20: award_achievement("seasoned")
	if SaveManager.data.achievements.size() >= 40: award_achievement("archivist")
	if SaveManager.data.achievements.size() >= 50: award_achievement("achievement_fifty")

func start_endless_mode() -> void:
	mainline_completion_pending = false
	endless_mode = true
	endless_elapsed = 0.0
	endless_wave = 1
	next_endless_boss_wave = 3
	award_achievement("endless_walker")
	show_toast("主线六关完成！\n♾ 无尽挑战开启", Color("f472b6"), 3.0)
	play_tone(920.0, 0.3, 0.25)

func on_enemy_damaged(at: Vector2, amount: float, lethal: bool) -> void:
	var generated := minf(1.5, amount * 0.025)
	wave_resonance_generated += generated
	resonance = clampf(resonance + generated, 0.0, MAX_RESONANCE)
	var effect := HitEffectScript.new()
	effect.position = at
	effect.setup(amount, lethal, last_damage_color)
	visual_root.add_child(effect)

func spawn_pickup(kind: String, value: int, pos: Vector2) -> void:
	if not is_instance_valid(pickup_root):
		return
	var item: Pickup = PickupScript.new()
	item.setup(kind, value)
	item.velocity = Vector2.from_angle(randf() * TAU) * randf_range(30, 100)
	pickup_root.add_child(item)
	# The map is infinite and roots may gain transforms later. Always preserve the
	# enemy's world-space death position instead of interpreting it as local.
	item.global_position = pos

func process_pickups(delta: float) -> void:
	if not is_instance_valid(player):
		return
	for child in pickup_root.get_children():
		if not is_instance_valid(child) or child.is_queued_for_deletion() or child.collected:
			continue
		var distance: float = child.global_position.distance_to(player.global_position)
		var magnet_range := effective_magnet_range()
		if distance < magnet_range:
			var strength := 280.0 + (magnet_range - distance) * 6.0
			child.global_position = child.global_position.move_toward(player.global_position, strength * delta)
			distance = child.global_position.distance_to(player.global_position)
		# 无限地图上不让货币永久遗失：存在数秒且离得过远时直接汇入钱包。
		if child.kind == "shard" and child.age >= 3.0:
			# 无限地图 + 风筝流的组合下，掉落该由战斗表现决定归属，而不是走位路线。
			child.global_position = child.global_position.move_toward(player.global_position, (620.0 + child.age * 90.0) * delta)
			distance = child.global_position.distance_to(player.global_position)
		if distance < 30.0:
			collect_pickup(child)

func collect_pickup(item: Pickup) -> void:
	if not is_instance_valid(item) or item.collected:
		return
	item.collected = true
	match item.kind:
		"shard": gain_star_shards(item.value)
		"heal":
			player.heal(item.value)
			show_toast("+%d 生命" % item.value, Color("4ade80"), 0.7)
	item.queue_free()

func gain_star_shards(amount: int) -> void:
	credit_star_shards(amount, true)

func credit_star_shards(amount: int, count_as_collected := false) -> void:
	if amount <= 0:
		return
	if count_as_collected:
		total_star_shards += amount
	var debt_payment := mini(amount, rental_debt)
	if debt_payment > 0:
		rental_debt -= debt_payment
		amount -= debt_payment
		show_toast("租赁欠费自动偿还 · ◆%d" % debt_payment, Color("efb8ff"), 0.8)
	star_shards += amount
	check_achievement_progress()
	update_hud()

func spendable_after_shard_income(amount: int) -> int:
	return star_shards + maxi(0, amount - rental_debt)

func card_shop_price(id: String) -> int:
	var base := 6
	if is_training_card(id):
		base = 5 + mini(8, int(upgrade_levels.get(id, 0)) * 2)
	else:
		match card_rarity(id):
			"普通": base = 5
			"稀有": base = 8
			"史诗": base = 11
			"传奇": base = 15
			"专属": base = 9
	# 收入随章节滚雪球，定价必须跟着走，否则中后期「全买」没有任何取舍。
	# 涨幅必须封顶：回收价是「当前售价」的固定比例，涨幅超过 1/回收率 就会出现囤货套利。
	return maxi(1, int(round(float(base) * (1.0 + minf(0.54, 0.09 * float(maxi(0, shop_visit - 1)))))))

func card_sell_value(id: String) -> int:
	var refund_ratio := 0.65 if active_vouchers.has("salvage_license") else 0.50
	var value := maxi(1, int(floor(card_shop_price(id) * refund_ratio)))
	if card_editions.has(id):
		value += 2
	return value

func available_shop_cards(excluded: Array[String] = []) -> Array:
	var pool: Array = []
	for upgrade in UPGRADES:
		var id := str(upgrade.id)
		if excluded.has(id) or equipped_cards.has(id) or int(upgrade_levels.get(id, 0)) >= int(upgrade.max):
			continue
		if upgrade.has("character") and str(upgrade.character) != player.character_name:
			continue
		if id == "core_engine" and equipped_cards.size() < 2:
			continue
		if id == "combo_catalyst" and active_combo_count() <= 0:
			continue
		if id == "card_slot" and card_slots >= MAX_CARD_SLOTS:
			continue
		pool.append(upgrade)
	return pool

func directed_partner_ids() -> Array[String]:
	var result: Array[String] = []
	for combo in DECK_COMBOS:
		var cards: Array = combo.cards
		var left_id := str(cards[0])
		var right_id := str(cards[1])
		if is_card_active(left_id) and not is_card_active(right_id) and not result.has(right_id):
			result.append(right_id)
		if is_card_active(right_id) and not is_card_active(left_id) and not result.has(left_id):
			result.append(left_id)
	for core_id in active_core_skill_ids():
		var extras: Array = {
			"aura":["orbit", "satellite_engine", "area"], "orbit":["aura", "area"],
			"satellite_engine":["aura", "area"], "chain":["burn", "thunder_orb", "crit"],
			"nova":["gravity_well", "area"], "phase_step":["blade_dance", "crit"],
			"thunder_orb":["chain", "crit"], "gravity_well":["nova", "area"],
			"blade_dance":["phase_step", "crit"], "meteor_rain":["frost_brand", "area"],
			"aegis":["regen", "armor"], "execute":["crit", "momentum"]
		}.get(core_id, [])
		for id in extras:
			if not result.has(str(id)):
				result.append(str(id))
	return result

func make_directed_build_offer(excluded: Array[String]) -> Dictionary:
	var pool := available_shop_cards(excluded)
	if pool.is_empty():
		return {}
	if not has_sustainable_offense_pet():
		var offense_cards: Array = pool.filter(func(option): return is_sustainable_offense_pet(str(option.id)))
		if not offense_cards.is_empty():
			var offense_choice: Dictionary = weighted_upgrade_pick(offense_cards)
			var offense_price := card_shop_price(str(offense_choice.id))
			if shop_visit <= 2:
				offense_price = maxi(card_sell_value(str(offense_choice.id)), mini(offense_price, 4))
			return {"kind":"card", "id":str(offense_choice.id), "price":offense_price, "sold":false, "directed":true, "lone_star":true}
	var partner_ids := directed_partner_ids()
	var partners: Array = pool.filter(func(option): return partner_ids.has(str(option.id)))
	var choice: Dictionary
	if not partners.is_empty():
		choice = weighted_upgrade_pick(partners)
	else:
		pool.sort_custom(func(a, b): return upgrade_offer_score(a) > upgrade_offer_score(b))
		choice = pool[0]
	var price := card_shop_price(str(choice.id))
	if shop_visit <= 2:
		# 新手定向折扣不能低于当前回收价，否则可在同一家商店买入后套利。
		price = maxi(card_sell_value(str(choice.id)), mini(price, 4))
	return {"kind":"card", "id":str(choice.id), "price":price, "sold":false, "directed":true}

func make_endless_growth_offer(excluded: Array[String]) -> Dictionary:
	if not endless_mode:
		return {}
	var candidates: Array[String] = []
	var lowest_level := 999
	for id in ENDLESS_CARD_IDS:
		var level := int(upgrade_levels.get(id, 0))
		if excluded.has(id) or level >= 10:
			continue
		if level < lowest_level:
			lowest_level = level
			candidates.assign([id])
		elif level == lowest_level:
			candidates.append(id)
	if candidates.is_empty():
		return {}
	var id: String = candidates.pick_random()
	return {"kind":"endless", "id":id, "price":6 + int(upgrade_levels.get(id, 0)) * 2, "sold":false}

func shop_offer_key(offer: Dictionary) -> String:
	return "%s:%s:%s:%s" % [str(offer.get("kind", "card")), str(offer.get("id", "")), str(offer.get("edition", "")), str(offer.get("seal", ""))]

func make_guaranteed_shop_fallback(excluded: Array[String], used_keys: Array[String], slot_index: int) -> Dictionary:
	var endless_offer := make_endless_growth_offer(excluded)
	if not endless_offer.is_empty() and not used_keys.has(shop_offer_key(endless_offer)):
		return endless_offer
	for target_id in active_core_skill_ids():
		for edition in compatible_editions_for_card(target_id):
			var offer := {"kind":"edition", "id":target_id, "edition":str(edition.id), "price":8 if active_vouchers.has("edition_license") else 10, "sold":false}
			if not used_keys.has(shop_offer_key(offer)):
				return offer
	var forge_offer := make_forge_offer()
	if not forge_offer.is_empty() and not used_keys.has(shop_offer_key(forge_offer)):
		return forge_offer
	# Always-effective temporary sink: its boosted supply shots are consumed in combat.
	return {"kind":"supply", "id":"supply_%d" % slot_index, "icon_id":"endless_haste", "price":6 + (mini(8, int(endless_wave / 3)) if endless_mode else 0), "sold":false}

func forge_price() -> int:
	return FORGE_BASE_PRICE + forge_purchases * FORGE_STEP_PRICE

func forge_available() -> bool:
	return float(stats.get("energy_power", 1.0)) < FORGE_ENERGY_CAP - 0.001

func make_forge_offer() -> Dictionary:
	return {"kind":"forge", "id":"star_forge", "price":forge_price(), "sold":false} if forge_available() else {}

func make_pet_offer(excluded: Array[String]) -> Dictionary:
	var pool: Array = available_shop_cards(excluded).filter(func(option): return str(option.id) in CORE_SKILL_CARD_IDS)
	if pool.is_empty():
		return {}
	var choice := weighted_upgrade_pick(pool)
	return {"kind":"card", "id":str(choice.id), "price":card_shop_price(str(choice.id)), "sold":false}

func make_shop_card_offer(excluded: Array[String]) -> Dictionary:
	var pool := available_shop_cards(excluded)
	if pool.is_empty():
		return {}
	if shop_visit <= 2 and active_core_skill_ids().is_empty():
		var cores: Array = pool.filter(func(option): return str(option.id) in CORE_SKILL_CARD_IDS)
		if not cores.is_empty():
			pool = cores
	var choice := weighted_upgrade_pick(pool)
	return {"kind":"card", "id":str(choice.id), "price":card_shop_price(str(choice.id)), "sold":false}

func make_shop_utility_offer(excluded: Array[String]) -> Dictionary:
	var core_ids := active_core_skill_ids()
	var available_vouchers: Array = EXPEDITION_VOUCHERS.filter(func(item): return not active_vouchers.has(str(item.id)))
	if not available_vouchers.is_empty() and randf() < 0.24:
		var voucher: Dictionary = available_vouchers.pick_random()
		return {"kind":"voucher", "id":str(voucher.id), "price":int(voucher.price), "sold":false}
	if randf() < 0.30:
		var pack_types := ["pet_pack", "rule_pack", "element_pack", "risk_pack"]
		return {"kind":"pack", "id":str(pack_types.pick_random()), "price":8, "sold":false}
	if consumable_sigils.size() < 2 and randf() < 0.32:
		var usable_sigils: Array = STAR_SIGILS.filter(func(item): return sigil_is_usable(str(item.id)))
		if not usable_sigils.is_empty():
			var sigil: Dictionary = usable_sigils.pick_random()
			return {"kind":"sigil", "id":str(sigil.id), "price":6, "sold":false}
	if not equipped_cards.is_empty() and randf() < 0.28:
		var seal_pairs: Array[Dictionary] = []
		for target_id in equipped_cards:
			for seal_id in compatible_seals_for_card(target_id):
				seal_pairs.append({"target_id":target_id, "seal_id":seal_id})
		if not seal_pairs.is_empty():
			var pair: Dictionary = seal_pairs.pick_random()
			return {"kind":"seal", "id":str(pair.target_id), "seal":str(pair.seal_id), "price":9, "sold":false}
	var patterns := active_star_patterns()
	if not patterns.is_empty() and randf() < 0.24:
		var pattern: String = patterns.pick_random()
		if int(pattern_mastery.get(pattern, 0)) < 3:
			return {"kind":"pattern", "id":pattern, "price":10, "sold":false}
	if not core_ids.is_empty() and randf() < 0.55:
		var edition_targets: Array = core_ids.filter(func(core_id): return not compatible_editions_for_card(core_id).is_empty())
		if not edition_targets.is_empty():
			var target_id: String = edition_targets.pick_random()
			var edition: Dictionary = compatible_editions_for_card(target_id).pick_random()
			return {"kind":"edition", "id":target_id, "edition":str(edition.id), "price":8 if active_vouchers.has("edition_license") else 10, "sold":false}
	if is_instance_valid(player) and player.health < player.max_health * 0.82:
		return {"kind":"heal", "id":"field_heal", "price":4, "sold":false}
	if forge_available() and randf() < 0.45:
		return make_forge_offer()
	return make_shop_card_offer(excluded)

func prepare_shop_goods(_force_new := false) -> void:
	var desired_count := (SHOP_ITEM_COUNT + mini(2, maxi(0, shop_visit - 1) / 2) + (1 if equipped_cards.has("juggler") else 0) + (1 if active_vouchers.has("wide_shelf") else 0))
	shop_goods.clear()
	var excluded: Array[String] = []
	var used_keys: Array[String] = []
	var needs_directed_offer := directed_shop_pending or shop_visit <= 2
	var needs_endless_offer := endless_mode
	# 战力完全由宠物提供，队伍没满之前必须保证每家商店都能招到人，
	# 否则玩家会连续几家商店只看到规则牌，战力曲线原地不动。
	var needs_pet_offer := equipped_pet_count() < 4
	# 卡组会满，钱不会；余额堆起来时必须给出一个可反复投入的去处。
	var needs_forge_offer := forge_available() and star_shards >= 16
	while shop_goods.size() < desired_count:
		var offer: Dictionary
		if needs_endless_offer:
			offer = make_endless_growth_offer(excluded)
			needs_endless_offer = false
		elif needs_directed_offer:
			offer = make_directed_build_offer(excluded)
			needs_directed_offer = false
		elif needs_pet_offer:
			offer = make_pet_offer(excluded)
			needs_pet_offer = false
		elif needs_forge_offer:
			offer = make_forge_offer()
			needs_forge_offer = false
		elif guaranteed_reward_pack and not shop_goods.any(func(item): return str(item.get("kind", "")) == "pack") and shop_goods.size() == desired_count - 1:
			offer = {"kind":"pack", "id":["pet_pack", "rule_pack", "element_pack"].pick_random(), "price":0, "sold":false}
			guaranteed_reward_pack = false
		elif active_vouchers.has("deep_freight") and not shop_goods.any(func(item): return str(item.get("kind", "")) == "pack") and shop_goods.size() == desired_count - 1:
			offer = {"kind":"pack", "id":"rule_pack", "price":8, "sold":false}
		elif shop_goods.size() == desired_count - 1 and shop_visit > 1:
			offer = make_shop_utility_offer(excluded)
		else:
			offer = make_shop_card_offer(excluded)
		if offer.is_empty():
			offer = make_shop_utility_offer(excluded)
		if offer.is_empty() or used_keys.has(shop_offer_key(offer)):
			offer = make_guaranteed_shop_fallback(excluded, used_keys, shop_goods.size())
		shop_goods.append(offer)
		used_keys.append(shop_offer_key(offer))
		if str(offer.get("kind", "")) == "card" and str(offer.get("id", "")) in CORE_SKILL_CARD_IDS:
			needs_pet_offer = false
		if str(offer.get("kind", "")) == "forge":
			needs_forge_offer = false
		if str(offer.get("kind", "")) in ["card", "endless"]:
			excluded.append(str(offer.id))
	directed_shop_pending = false

func shop_window_open() -> bool:
	# Boss 战期间收起商店是为了让关卡高潮保持专注，但不能无限期堵住：
	# 无尽的 Boss 每 3 波就来一次且越来越肉，一旦打不动就会把「买不到强化 ->
	# 更打不动」的负反馈重新闭合。超过阈值就放行，累计的商店照常兑现。
	var bosses := get_tree().get_nodes_in_group("bosses")
	if bosses.is_empty():
		boss_engaged_since = -1.0
		return true
	if boss_engaged_since < 0.0:
		boss_engaged_since = elapsed
	return elapsed - boss_engaged_since > BOSS_SHOP_LOCK_LIMIT

func show_shop(force := false) -> void:
	if state == GameState.GAME_OVER or is_instance_valid(shop_overlay) or not is_instance_valid(ui_layer):
		return
	if not force and (state != GameState.PLAYING or not shop_window_open()):
		shop_pending = true
		return
	shop_pending = false
	queued_shops = maxi(0, queued_shops - 1)
	resolve_wave_challenges()
	bank_world_shards()
	shop_visit += 1
	shop_reroll_count = 0
	shop_purchases_this_visit = 0
	prepare_shop_goods(false)
	state = GameState.LEVEL_UP
	get_tree().paused = true
	player.selection_protected = true
	player.can_move = false
	shop_overlay = full_rect_control()
	shop_overlay.name = "StarShopOverlay"
	shop_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(shop_overlay)
	add_dim_background(shop_overlay, 1.0)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 4)
	shop_overlay.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)
	var title := make_label("星屑商店", 24, Color("facc15"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	shop_wallet_label = make_label("", 20, Color("fff3c4"))
	header.add_child(shop_wallet_label)
	var hint := make_label("星屑会保留到后续商店；按当前构筑取舍购买，或存下星屑等待高品质卡牌。", 12, Color("9bb4d1"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)
	# 货架高度必须是固定的：商品数量、文案长度、字体换行都会改变内容高度，
	# 直接放进 VBox 会把下方的卡组面板和操作行顶出视口（回归测试已捕获）。
	var goods_scroll := ScrollContainer.new()
	goods_scroll.custom_minimum_size.y = 300
	goods_scroll.size_flags_vertical = Control.SIZE_FILL
	goods_scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(goods_scroll)
	shop_goods_row = HBoxContainer.new()
	shop_goods_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_goods_row.add_theme_constant_override("separation", 10)
	goods_scroll.add_child(shop_goods_row)
	var deck_panel := PanelContainer.new()
	deck_panel.custom_minimum_size.y = 126
	deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_panel.add_theme_stylebox_override("panel", compact_panel_style(Color("0b1834"), 12, Color("355c91"), 2))
	root.add_child(deck_panel)
	shop_deck_box = VBoxContainer.new()
	shop_deck_box.add_theme_constant_override("separation", 5)
	deck_panel.add_child(shop_deck_box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	var reroll := make_compact_button("刷新商品", Vector2(0, 38))
	reroll.name = "ShopReroll"
	reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll.process_mode = Node.PROCESS_MODE_ALWAYS
	reroll.pressed.connect(reroll_shop)
	actions.add_child(reroll)
	var leave := make_compact_button("离开商店 · 进入下一波", Vector2(0, 38))
	leave.name = "ShopLeave"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.process_mode = Node.PROCESS_MODE_ALWAYS
	leave.pressed.connect(close_shop)
	actions.add_child(leave)
	var contract := make_compact_button("签署危险契约并出发", Vector2(0, 38))
	contract.name = "ShopContract"
	contract.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contract.process_mode = Node.PROCESS_MODE_ALWAYS
	contract.disabled = not danger_contract.is_empty()
	contract.tooltip_text = "下一波普通敌人生命+25%、伤害+18%；击败25名敌人奖励6星屑和一个免费补充包。"
	contract.pressed.connect(accept_danger_contract)
	actions.add_child(contract)
	refresh_shop_view()
	root.scale = Vector2(0.94, 0.94)
	root.pivot_offset = Vector2(610, 340)
	root.modulate.a = 0.0
	var appear := create_tween()
	appear.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	appear.set_parallel(true)
	appear.tween_property(root, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(root, "modulate:a", 1.0, 0.16)
	play_tone(610.0, 0.12, 0.16)

func bank_world_shards() -> void:
	if not is_instance_valid(pickup_root):
		return
	var banked := 0
	for child in pickup_root.get_children():
		if is_instance_valid(child) and not child.collected and child.kind == "shard":
			child.collected = true
			banked += int(child.value)
			child.queue_free()
	if banked > 0:
		gain_star_shards(banked)
		show_toast("波次结算 · 回收散落星屑 ◆%d" % banked, Color("facc15"), 0.9)

func shop_offer_text(offer: Dictionary) -> String:
	var kind := str(offer.get("kind", "card"))
	if kind == "endless":
		var id := str(offer.id)
		return "%s\n【史诗 · 无尽成长】\n\n%s\n\n当前 %d/10 · 可重复强化" % [card_display_name(id), skill_description(id), int(upgrade_levels.get(id, 0))]
	if kind == "forge":
		return "星屑熔炉
【可反复投入】

每次让每枚供能弹 +%.2f 能量
当前 %.2f / 上限 %.2f
不占卡槽" % [FORGE_ENERGY_GAIN, float(stats.energy_power), FORGE_ENERGY_CAP]
	if kind == "supply":
		return "星潮供能箱\n【即时补给】\n\n接下来3枚供能弹强度×1.50\n不占卡槽，可反复购买"
	if kind == "voucher":
		var voucher: Dictionary = EXPEDITION_VOUCHERS.filter(func(item): return str(item.id) == str(offer.id))[0]
		return "远征许可 · %s\n\n%s\n不占卡槽，本局持续生效" % [voucher.name, voucher.desc]
	if kind == "pack":
		var pack_names := {"pet_pack":"星灵蛋匣", "rule_pack":"星律卡包", "element_pack":"元素样本", "risk_pack":"禁忌档案"}
		return "%s\n\n打开4项候选并选择1项\n可以跳过，不占消耗物槽" % str(pack_names.get(str(offer.id), "星渊补充包"))
	if kind == "sigil":
		var sigil: Dictionary = STAR_SIGILS.filter(func(item): return str(item.id) == str(offer.id))[0]
		return "星象符 · %s\n\n%s\n最多携带2枚，在商店内使用" % [sigil.name, sigil.desc]
	if kind == "seal":
		var seal: Dictionary = CARD_SEALS.filter(func(item): return str(item.id) == str(offer.seal))[0]
		return "%s\n附着到【%s】\n\n%s" % [seal.name, card_display_name(str(offer.id)), seal.desc]
	if kind == "pattern":
		return "星式研究 · %s\n\n该牌型星能+6、宠物释技倍率+3%%\n最多研究3次" % str(offer.id)
	if kind == "edition":
		return "%s版本\n改造【%s】\n\n%s" % [card_edition_name(str(offer.edition)), card_display_name(str(offer.id)), CARD_EDITIONS.filter(func(item): return str(item.id) == str(offer.edition))[0].desc]
	if kind == "heal":
		return "战地修复\n\n立即恢复25生命\n不占卡槽"
	var id := str(offer.id)
	var data: Dictionary = UPGRADES.filter(func(item): return str(item.id) == id)[0]
	if is_training_card(id):
		return "%s\n【%s · 一次性训练】\n\n%s\n\n当前训练 %d/%d · 购买后立即使用，不占卡槽" % [data.name, card_rarity(id), training_gain_preview(id), int(upgrade_levels.get(id, 0)), int(data.max)]
	var slot_text := "槽满时可出售旧牌抵扣" if equipped_cards.size() >= card_slots else "购买后置入卡组最右侧"
	return "%s\n【%s · %s】\n\n%s\n\n%s" % [data.name, card_rarity(id), card_build_type(id), skill_description(id), slot_text]

func sigil_name(id: String) -> String:
	for item in STAR_SIGILS:
		if str(item.id) == id: return str(item.name)
	return id

func sigil_is_usable(id: String) -> bool:
	match id:
		"swap": return equipped_cards.size() >= 2
		"polish": return active_core_skill_ids().any(func(core_id): return card_deals_direct_damage(core_id) and not str(card_editions.get(core_id, "")) in ["polychrome", "echo"])
		"melt":
			return equipped_cards.any(func(card_id): return not card_id in CORE_SKILL_CARD_IDS and card_id != "card_slot" and str(card_drawbacks.get(card_id, "")) != "eternal")
		"cleanse": return cleanse_ward_charges < MAX_CLEANSE_WARD_CHARGES
		"sacrifice": return player.max_health >= 35.0 and active_core_skill_ids().any(func(core_id): return core_mastery_rank(core_id) < CORE_MASTERY_MAX_RANK)
		"bridge": return star_bridge_hands < 3
		"fortune": return star_shards >= 5
		"reforge": return true
	return false

func seal_name(id: String) -> String:
	for item in CARD_SEALS:
		if str(item.id) == id: return str(item.name)
	return id

func card_deals_direct_damage(id: String) -> bool:
	return id in CORE_SKILL_CARD_IDS and id != "aegis"

func compatible_editions_for_card(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not card_deals_direct_damage(id):
		return result
	var current := str(card_editions.get(id, ""))
	for edition in CARD_EDITIONS:
		if str(edition.id) != current:
			result.append(edition)
	return result

func compatible_seals_for_card(id: String) -> Array[String]:
	var result: Array[String] = []
	if card_deals_direct_damage(id):
		result.append("red")
	if id in CORE_SKILL_CARD_IDS and core_mastery_rank(id) < CORE_MASTERY_MAX_RANK:
		result.append("gold")
	if id in CORE_SKILL_CARD_IDS and active_star_patterns().any(func(pattern): return int(pattern_mastery.get(pattern, 0)) < 3):
		result.append("blue")
	if equipped_cards.has(id):
		result.append("white")
	var current := str(card_seals.get(id, ""))
	return result.filter(func(seal_id): return seal_id != current)

func booster_candidates(pack_id: String) -> Array:
	var pool := available_shop_cards([])
	match pack_id:
		"pet_pack": pool = pool.filter(func(item): return str(item.id) in CORE_SKILL_CARD_IDS)
		"element_pack": pool = pool.filter(func(item): return str(item.id) in ["burn", "frost_brand", "thunder_orb", "gravity_well", "chain", "meteor_rain", "aura"])
		"risk_pack": pool = pool.filter(func(item): return card_build_type(str(item.id)) in ["风险倍率", "复制回响", "Boss反制", "节奏倍率"])
		"rule_pack": pool = pool.filter(func(item): return card_build_type(str(item.id)) in ["构筑规则", "牌型规则", "触发牌", "技能改造"])
	pool.shuffle()
	return pool.slice(0, mini(4, pool.size()))

func show_booster_pack(pack_id: String) -> void:
	if not is_instance_valid(shop_overlay) or is_instance_valid(booster_overlay):
		return
	var candidates := booster_candidates(pack_id)
	if candidates.is_empty():
		gain_star_shards(3)
		show_toast("补充包没有可用新牌 · 回收◆3", Color("9bb4d1"), 0.9)
		return
	booster_overlay = full_rect_control()
	booster_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	booster_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.add_child(booster_overlay)
	add_dim_background(booster_overlay, 0.93)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	booster_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1020, 480)
	panel.add_theme_stylebox_override("panel", panel_style(Color("0b1834"), 18, Color("c084fc"), 3))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := make_label("打开补充包 · 选择1张", 30, Color("facc15"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	for candidate in candidates:
		var id := str(candidate.id)
		var rarity := card_rarity(id)
		var rarity_color: Color = CARD_RARITY_COLORS.get(rarity, Color("9bb4d1"))
		var risk_text := "\n\n禁忌代价：获得随机负面版本" if pack_id == "risk_pack" else ""
		var button := make_button("%s\n【%s】\n\n%s%s" % [candidate.name, rarity, skill_description(id), risk_text], Vector2(0, 320))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.add_theme_color_override("font_color", rarity_color)
		button.add_theme_color_override("font_hover_color", rarity_color.lightened(0.16))
		button.add_theme_color_override("font_pressed_color", rarity_color.lightened(0.24))
		button.pressed.connect(claim_booster_card.bind(id, pack_id))
		row.add_child(button)
	var skip := make_button("跳过并回收◆2", Vector2(0, 44))
	skip.process_mode = Node.PROCESS_MODE_ALWAYS
	skip.pressed.connect(skip_booster_pack)
	box.add_child(skip)

func close_booster_overlay() -> void:
	if is_instance_valid(booster_overlay): booster_overlay.queue_free()
	booster_overlay = null

func claim_booster_card(id: String, pack_id := "") -> void:
	close_booster_overlay()
	if pack_id == "risk_pack":
		var compatible_drawbacks: Array[String] = ["rental", "eternal"]
		if card_deals_direct_damage(id):
			compatible_drawbacks.append("fragile")
		pending_drawback_id = compatible_drawbacks.pick_random()
		card_drawbacks[id] = pending_drawback_id
	if is_slot_card(id) and equipped_cards.size() >= card_slots:
		show_shop_replacement(id, 0, -1)
	else:
		apply_upgrade(id, true, 0, -1)
		pending_drawback_id = ""
	var drawback_note := ""
	match str(card_drawbacks.get(id, "")):
		"fragile": drawback_note = "\n脆裂：技能伤害+25%，角色受到伤害+18%"
		"rental": drawback_note = "\n租赁：每次离店收取◆1，欠费会从后续收入扣除"
		"eternal": drawback_note = "\n永恒：本局不能出售、替换或熔解"
	show_toast("补充包选择 · %s%s" % [card_display_name(id), drawback_note], Color("c084fc"), 1.8 if not drawback_note.is_empty() else 1.0)

func skip_booster_pack() -> void:
	close_booster_overlay()
	gain_star_shards(2)
	refresh_shop_view()

func use_sigil(id: String) -> void:
	if not consumable_sigils.has(id) or not is_instance_valid(shop_overlay) or not sigil_is_usable(id):
		return
	match id:
		"swap":
			if equipped_cards.size() < 2: return
			var first := equipped_cards[0]; equipped_cards[0] = equipped_cards[-1]; equipped_cards[-1] = first
		"polish":
			var cores := active_core_skill_ids().filter(func(core_id): return card_deals_direct_damage(core_id) and not str(card_editions.get(core_id, "")) in ["polychrome", "echo"])
			if cores.is_empty(): return
			var target_id: String = cores.pick_random()
			var editions: Array[String] = ["foil", "holographic"].filter(func(edition_id): return edition_id != str(card_editions.get(target_id, "")))
			if editions.is_empty(): return
			card_editions[target_id] = editions.pick_random()
		"melt":
			var target := ""
			for index in range(equipped_cards.size() - 1, -1, -1):
				var candidate_id := str(equipped_cards[index])
				if not candidate_id in CORE_SKILL_CARD_IDS and candidate_id != "card_slot" and str(card_drawbacks.get(candidate_id, "")) != "eternal": target = candidate_id; break
			if target.is_empty(): return
			var value := card_sell_value(target) * 2
			equipped_cards.erase(target); remove_slot_card_effect(target); credit_star_shards(value)
			award_achievement("shop_sale")
			if equipped_cards.has("campfire"):
				campfire_stacks = mini(6, campfire_stacks + 1)
		"cleanse":
			if cleanse_ward_charges >= MAX_CLEANSE_WARD_CHARGES: return
			cleanse_ward_charges += 1
		"sacrifice":
			var cores := active_core_skill_ids().filter(func(core_id): return core_mastery_rank(core_id) < CORE_MASTERY_MAX_RANK)
			if cores.is_empty() or player.max_health < 35.0: return
			var target_id: String = cores.pick_random()
			player.reduce_max_health(15.0)
			core_mastery_ranks[target_id] = mini(CORE_MASTERY_MAX_RANK, core_mastery_rank(target_id) + 1)
			core_mastery_progress[target_id] = 0
		"bridge": star_bridge_hands = 3
		"fortune":
			var payout := mini(8, int(floor(star_shards * 0.20)))
			if payout <= 0: return
			gain_star_shards(payout)
		"reforge":
			prepare_shop_goods(true)
	consumable_sigils.erase(id)
	show_toast("使用星象符 · %s" % sigil_name(id), Color("c084fc"), 1.0)
	refresh_derived_card_effects()
	check_achievement_progress()
	update_deck_card_row()
	queue_shop_refresh()

func refresh_shop_view() -> void:
	shop_refresh_pending = false
	if not is_instance_valid(shop_overlay):
		return
	shop_wallet_label.text = "◆ 星屑 %d%s" % [star_shards, " · 租赁欠费 %d" % rental_debt if rental_debt > 0 else ""]
	for child in shop_goods_row.get_children():
		child.free()
	for index in shop_goods.size():
		var offer: Dictionary = shop_goods[index]
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border: Color = Color("facc15") if str(offer.get("kind", "")) != "card" else CARD_RARITY_COLORS.get(card_rarity(str(offer.id)), Color("9bb4d1"))
		panel.add_theme_stylebox_override("panel", compact_panel_style(Color("10213e"), 12, border, 2))
		shop_goods_row.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		panel.add_child(box)
		var description := PanelContainer.new()
		description.name = "ShopOfferDescription%d" % index
		description.custom_minimum_size.x = clampf(1180.0 / float(maxi(1, shop_goods.size())) - 32.0, 186.0, 240.0)
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description.mouse_filter = Control.MOUSE_FILTER_STOP
		description.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var offer_content := HBoxContainer.new()
		offer_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		offer_content.add_theme_constant_override("separation", 8)
		description.add_child(offer_content)
		if str(offer.get("kind", "")) in ["card", "endless"]:
			var offer_icon := TextureRect.new()
			offer_icon.texture = make_skill_icon(str(offer.get("icon_id", offer.id)))
			offer_icon.custom_minimum_size = Vector2(60, 60)
			offer_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			offer_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			offer_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			offer_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			offer_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			offer_content.add_child(offer_icon)
		var offer_text := Label.new()
		offer_text.name = "ShopOfferText%d" % index
		offer_text.text = shop_offer_text(offer).replace("\n\n", "\n")
		offer_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		offer_text.add_theme_font_size_override("font_size", 11)
		offer_text.add_theme_color_override("font_color", border)
		offer_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		offer_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		offer_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		offer_content.add_child(offer_text)
		box.add_child(description)
		var affordable := star_shards >= int(offer.price)
		if str(offer.get("kind", "")) in ["card", "endless"] and is_slot_card(str(offer.id)) and equipped_cards.size() >= card_slots:
			var best_refund := 0
			for owned_id in equipped_cards:
				if not (owned_id == "card_slot" and equipped_cards.size() > STARTING_CARD_SLOTS) and str(card_drawbacks.get(owned_id, "")) != "eternal":
					best_refund = maxi(best_refund, card_sell_value(owned_id))
			affordable = star_shards + best_refund >= int(offer.price)
		var purchase := make_compact_button("", Vector2(0, 32))
		purchase.name = "ShopPurchase%d" % index
		purchase.text = "已出售" if bool(offer.get("sold", false)) else "购买 · ◆ %d" % int(offer.price)
		purchase.disabled = bool(offer.get("sold", false)) or not affordable
		purchase.process_mode = Node.PROCESS_MODE_ALWAYS
		purchase.pressed.connect(purchase_shop_offer.bind(index))
		box.add_child(purchase)
	refresh_shop_deck()
	var reroll := shop_overlay.find_child("ShopReroll", true, false) as Button
	if is_instance_valid(reroll):
		var free_refresh := active_vouchers.has("free_reroll") and shop_reroll_count == 0
		var cost := 0 if free_refresh else 2 + shop_reroll_count * 2
		reroll.text = "首次免费刷新" if free_refresh else "刷新商品 · ◆ %d" % cost
		reroll.disabled = star_shards < cost

func queue_shop_refresh() -> void:
	if shop_refresh_pending:
		return
	shop_refresh_pending = true
	call_deferred("refresh_shop_view")

func refresh_shop_deck() -> void:
	if not is_instance_valid(shop_deck_box):
		return
	for child in shop_deck_box.get_children():
		child.free()
	if not consumable_sigils.is_empty():
		var utility_row := HBoxContainer.new()
		utility_row.add_theme_constant_override("separation", 8)
		shop_deck_box.add_child(utility_row)
		for sigil_id in consumable_sigils:
			var sigil_button := make_compact_button("使用 %s" % sigil_name(sigil_id), Vector2(112, 28))
			sigil_button.process_mode = Node.PROCESS_MODE_ALWAYS
			sigil_button.disabled = not sigil_is_usable(sigil_id)
			sigil_button.pressed.connect(use_sigil.bind(sigil_id))
			utility_row.add_child(sigil_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 150
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_deck_box.add_child(scroll)
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards_row)
	if equipped_cards.is_empty():
		var empty := make_label("暂无卡牌", 16, Color("607086"))
		empty.custom_minimum_size.x = 180
		cards_row.add_child(empty)
		return
	for index in equipped_cards.size():
		var id := equipped_cards[index]
		var rarity := card_rarity(id)
		var rarity_color: Color = CARD_RARITY_COLORS.get(rarity, Color("9bb4d1"))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(152, 132)
		card.add_theme_stylebox_override("panel", compact_panel_style(Color("10213e"), 10, rarity_color, 2))
		cards_row.add_child(card)
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 2)
		card.add_child(card_box)
		var icon := TextureRect.new()
		icon.texture = make_skill_icon(id)
		icon.custom_minimum_size = Vector2(52, 52)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_box.add_child(icon)
		var name := make_label(card_display_name(id), 12, rarity_color)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card_box.add_child(name)
		var meta := make_label("#%d · %s" % [index + 1, rarity], 10, rarity_color.darkened(0.1))
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(meta)
		var protects_capacity := id == "card_slot" and equipped_cards.size() > STARTING_CARD_SLOTS
		var sell := make_compact_button("出售 ◆%d" % card_sell_value(id), Vector2(0, 27))
		sell.add_theme_color_override("font_color", rarity_color)
		sell.add_theme_font_size_override("font_size", 10)
		sell.process_mode = Node.PROCESS_MODE_ALWAYS
		sell.disabled = protects_capacity or str(card_drawbacks.get(id, "")) == "eternal"
		sell.pressed.connect(sell_shop_card.bind(id))
		card_box.add_child(sell)

func reroll_shop() -> void:
	var cost := 0 if active_vouchers.has("free_reroll") and shop_reroll_count == 0 else 2 + shop_reroll_count
	if star_shards < cost:
		return
	star_shards -= cost
	spent_star_shards += cost
	shop_reroll_count += 1
	award_achievement("shop_reroll")
	prepare_shop_goods(false)
	refresh_shop_view()
	play_tone(480.0, 0.07, 0.12)

func mark_shop_offer_sold(index: int) -> void:
	if index < 0 or index >= shop_goods.size():
		return
	var offer: Dictionary = shop_goods[index]
	offer.sold = true
	shop_goods[index] = offer

func purchase_shop_offer(index: int) -> void:
	if index < 0 or index >= shop_goods.size():
		return
	var offer: Dictionary = shop_goods[index]
	var price := int(offer.price)
	if bool(offer.get("sold", false)):
		return
	var can_pay := star_shards >= price
	if not can_pay and str(offer.get("kind", "")) in ["card", "endless"] and is_slot_card(str(offer.get("id", ""))) and equipped_cards.size() >= card_slots:
		for owned_id in equipped_cards:
			if not (owned_id == "card_slot" and equipped_cards.size() > STARTING_CARD_SLOTS) and str(card_drawbacks.get(owned_id, "")) != "eternal":
				can_pay = can_pay or spendable_after_shard_income(card_sell_value(owned_id)) >= price
	if not can_pay:
		return
	match str(offer.get("kind", "card")):
		"voucher":
			star_shards -= price
			spent_star_shards += price
			active_vouchers[str(offer.id)] = true
			mark_shop_offer_sold(index)
			shop_purchases_this_visit += 1
			award_achievement("shop_first")
			show_toast("远征许可生效 · %s" % str(EXPEDITION_VOUCHERS.filter(func(item): return str(item.id) == str(offer.id))[0].name), Color("facc15"), 1.2)
		"pack":
			star_shards -= price
			spent_star_shards += price
			mark_shop_offer_sold(index)
			shop_purchases_this_visit += 1
			award_achievement("shop_first")
			show_booster_pack(str(offer.id))
		"sigil":
			if consumable_sigils.size() >= 2:
				return
			star_shards -= price
			spent_star_shards += price
			consumable_sigils.append(str(offer.id))
			mark_shop_offer_sold(index)
			shop_purchases_this_visit += 1
			award_achievement("shop_first")
			show_toast("获得星象符 · %s" % sigil_name(str(offer.id)), Color("c084fc"), 1.0)
		"seal":
			if not compatible_seals_for_card(str(offer.id)).has(str(offer.seal)):
				return
			star_shards -= price
			spent_star_shards += price
			card_seals[str(offer.id)] = str(offer.seal)
			mark_shop_offer_sold(index)
			shop_purchases_this_visit += 1
			award_achievement("shop_first")
			show_toast("%s获得%s" % [card_display_name(str(offer.id)), seal_name(str(offer.seal))], Color("facc15"), 1.0)
			update_deck_card_row()
		"pattern":
			star_shards -= price
			spent_star_shards += price
			pattern_mastery[str(offer.id)] = mini(3, int(pattern_mastery.get(str(offer.id), 0)) + 1)
			mark_shop_offer_sold(index)
			shop_purchases_this_visit += 1
			award_achievement("shop_first")
			show_toast("星式研究 · %s %d/3" % [str(offer.id), int(pattern_mastery[str(offer.id)])], Color("70d7ff"), 1.0)
		"heal":
			star_shards -= price
			spent_star_shards += price
			player.heal(25.0)
			mark_shop_offer_sold(index)
			show_toast("战地修复 · 恢复25生命", Color("4ade80"), 1.0)
			award_achievement("shop_first")
			shop_purchases_this_visit += 1
		"forge":
			if not forge_available():
				return
			star_shards -= price
			spent_star_shards += price
			forge_purchases += 1
			stats.energy_power = minf(FORGE_ENERGY_CAP, float(stats.energy_power) + FORGE_ENERGY_GAIN)
			# 不标售罄：熔炉是可反复投入的沉淀口，价格已经随次数递增。
			var refreshed: Dictionary = shop_goods[index]
			refreshed.price = forge_price()
			shop_goods[index] = refreshed
			shop_purchases_this_visit += 1
			award_achievement("shop_first")
			show_toast("星屑熔炉 · 供能强度提升至 %.2f" % float(stats.energy_power), Color("facc15"), 1.1)
		"supply":
			star_shards -= price
			spent_star_shards += price
			surge_pulses += 3
			mark_shop_offer_sold(index)
			shop_purchases_this_visit += 1
			show_toast("星潮供能箱 · 接下来3枚供能弹强化", Color("70d7ff"), 1.1)
			award_achievement("shop_first")
		"edition":
			if not compatible_editions_for_card(str(offer.id)).any(func(edition): return str(edition.id) == str(offer.edition)):
				return
			star_shards -= price
			spent_star_shards += price
			card_editions[str(offer.id)] = str(offer.edition)
			check_achievement_progress()
			mark_shop_offer_sold(index)
			update_deck_card_row()
			show_toast("卡牌改造：%s获得【%s】版本" % [card_display_name(str(offer.id)), card_edition_name(str(offer.edition))], Color("70d7ff"), 1.5)
			award_achievement("shop_first")
			shop_purchases_this_visit += 1
		_:
			var id := str(offer.id)
			if is_slot_card(id) and equipped_cards.size() >= card_slots:
				show_shop_replacement(id, price, index)
				return
			apply_upgrade(id, true, price, index)
	queue_shop_refresh()

func sell_shop_card(id: String) -> void:
	if not equipped_cards.has(id):
		return
	if str(card_drawbacks.get(id, "")) == "eternal":
		show_toast("永恒版本不能出售或替换", Color("ef476f"), 1.0)
		return
	if id == "card_slot" and equipped_cards.size() > STARTING_CARD_SLOTS:
		show_toast("扩展卡匣正在维持额外槽位，不能出售", Color("ef476f"), 1.2)
		return
	var refund := card_sell_value(id)
	insure_pet_before_sale(id)
	equipped_cards.erase(id)
	remove_slot_card_effect(id)
	credit_star_shards(refund)
	award_achievement("shop_sale")
	if equipped_cards.has("campfire"):
		campfire_stacks = mini(6, campfire_stacks + 1)
		show_toast("焚牌营火成长 · %d/6" % campfire_stacks, Color("fb923c"), 0.8)
	refresh_derived_card_effects()
	update_deck_card_row()
	queue_shop_refresh()
	show_toast("出售%s · 获得◆%d" % [card_display_name(id), refund], Color("facc15"), 1.0)

func close_shop() -> void:
	close_booster_overlay()
	if is_instance_valid(card_replace_overlay):
		card_replace_overlay.queue_free()
	card_replace_overlay = null
	if is_instance_valid(shop_overlay):
		shop_overlay.queue_free()
	shop_overlay = null
	shop_goods_row = null
	shop_wallet_label = null
	shop_deck_box = null
	shop_goods.clear()
	if shop_purchases_this_visit == 0 and equipped_cards.has("red_contract"):
		red_contract_stacks = mini(6, red_contract_stacks + 1)
		show_toast("拒选红契成长 · %d/6" % red_contract_stacks, Color("ef476f"), 1.0)
	if equipped_cards.has("moon_interest") and star_shards >= 10:
		var interest := mini(5, int(floor(star_shards * 0.10)))
		credit_star_shards(interest)
		show_toast("月息账户 · 利息 ◆%d" % interest, Color("facc15"), 1.0)
	start_wave_goal()
	var rental_cost := 0
	for id in equipped_cards:
		if str(card_drawbacks.get(id, "")) == "rental":
			rental_cost += 1
	rental_debt += rental_cost
	var paid := mini(star_shards, rental_debt)
	star_shards -= paid
	rental_debt -= paid
	if rental_cost > 0 or paid > 0 or rental_debt > 0:
		show_toast("租赁版本维护费 · 已付◆%d%s" % [paid, " · 欠费◆%d" % rental_debt if rental_debt > 0 else ""], Color("efb8ff"), 1.2)
	player.selection_protected = false
	player.can_move = true
	player.invulnerable = maxf(player.invulnerable, 0.8)
	shop_pending = queued_shops > 0
	state = GameState.PLAYING
	get_tree().paused = false
	update_hud()

func accept_danger_contract() -> void:
	if not danger_contract.is_empty():
		return
	danger_contract = {"kills":kills, "target":25}
	show_toast("危险契约已签署 · 强敌来袭\n击败25名敌人可赢得6星屑与免费补充包", Color("ef476f"), 1.8)
	close_shop()

func start_wave_goal() -> void:
	if not wave_goal.is_empty():
		return
	wave_resonance_generated = 0.0
	var type: String = ["kills", "hands", "resonance"].pick_random()
	match type:
		"kills": wave_goal = {"type":type, "start":kills, "target":16, "name":"本波击败16名敌人"}
		"hands": wave_goal = {"type":type, "start":hands_played, "target":10, "name":"本波宠物释技10次"}
		_: wave_goal = {"type":type, "start":0.0, "target":80, "name":"本波累计产生80共鸣"}

func resolve_wave_challenges() -> void:
	if not wave_goal.is_empty():
		var progress := 0.0
		match str(wave_goal.type):
			"kills": progress = kills - int(wave_goal.start)
			"hands": progress = hands_played - int(wave_goal.start)
			_: progress = wave_resonance_generated
		if progress >= float(wave_goal.target):
			gain_star_shards(3)
			show_toast("波次目标完成 · ◆3", Color("4ade80"), 1.0)
		else:
			show_toast("波次目标未完成 · 不受惩罚", Color("9bb4d1"), 0.8)
		wave_goal.clear()
	if not danger_contract.is_empty():
		if kills - int(danger_contract.kills) >= int(danger_contract.target):
			gain_star_shards(6)
			guaranteed_reward_pack = true
			show_toast("危险契约完成 · ◆6与免费补充包", Color("facc15"), 1.3)
		else:
			show_toast("危险契约失败 · 敌人恢复正常", Color("ef476f"), 0.9)
		danger_contract.clear()

func show_shop_replacement(incoming_id: String, price: int, offer_index: int) -> void:
	if not is_instance_valid(shop_overlay) or is_instance_valid(card_replace_overlay):
		return
	pending_shop_offer = offer_index
	pending_shop_price = price
	card_replace_overlay = full_rect_control()
	card_replace_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	card_replace_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.add_child(card_replace_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.06, 0.94)
	card_replace_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_replace_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 570)
	panel.add_theme_stylebox_override("panel", panel_style(Color("0b1834"), 18, Color("facc15"), 3))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	var title := make_label("卡槽已满 · 出售旧牌并购买新牌", 30, Color("facc15"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := make_label("准备购买【%s】 ◆%d\n旧牌回收价将直接抵扣；余额不足的选项不可选择。" % [card_display_name(incoming_id), price], 16, Color("c7d7eb"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 6)
	scroll.add_child(cards)
	for old_id in equipped_cards.duplicate():
		var refund := card_sell_value(old_id)
		var protects_capacity: bool = (old_id == "card_slot" and equipped_cards.size() > STARTING_CARD_SLOTS) or str(card_drawbacks.get(old_id, "")) == "eternal"
		var affordable := spendable_after_shard_income(refund) >= price
		var net := maxi(0, price - maxi(0, refund - rental_debt))
		var text_value := "不可出售【%s】·正在维持槽位" % card_display_name(old_id) if protects_capacity else "出售【%s】◆%d → 实付◆%d" % [card_display_name(old_id), refund, net]
		var button := make_button(text_value, Vector2(0, 48))
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.disabled = protects_capacity or not affordable
		button.pressed.connect(confirm_shop_replacement.bind(str(old_id), incoming_id, price, offer_index))
		cards.add_child(button)
	var cancel := make_button("取消购买 · 返回商店", Vector2(0, 48))
	cancel.process_mode = Node.PROCESS_MODE_ALWAYS
	cancel.pressed.connect(cancel_shop_replacement)
	box.add_child(cancel)

func cancel_shop_replacement(clear_pending_drawback := true) -> void:
	if is_instance_valid(card_replace_overlay):
		card_replace_overlay.queue_free()
	card_replace_overlay = null
	if clear_pending_drawback and not pending_drawback_id.is_empty():
		for id in card_drawbacks.keys():
			if str(card_drawbacks[id]) == pending_drawback_id and not equipped_cards.has(str(id)):
				card_drawbacks.erase(id)
	pending_drawback_id = ""
	pending_shop_offer = -1
	pending_shop_price = 0

func confirm_shop_replacement(old_id: String, incoming_id: String, price: int, offer_index: int) -> void:
	if not equipped_cards.has(old_id):
		return
	if str(card_drawbacks.get(old_id, "")) == "eternal":
		show_toast("永恒版本本局不能被替换", Color("ef476f"), 1.2)
		return
	var refund := card_sell_value(old_id)
	if spendable_after_shard_income(refund) < price:
		return
	var old_index := equipped_cards.find(old_id)
	insure_pet_before_sale(old_id)
	equipped_cards.remove_at(old_index)
	remove_slot_card_effect(old_id)
	credit_star_shards(refund)
	award_achievement("shop_sale")
	if equipped_cards.has("campfire"):
		campfire_stacks = mini(6, campfire_stacks + 1)
	cancel_shop_replacement(false)
	apply_upgrade(incoming_id, true, price, offer_index)
	pending_drawback_id = ""
	var new_index := equipped_cards.find(incoming_id)
	if new_index >= 0 and old_index < equipped_cards.size():
		var moved := equipped_cards[new_index]
		equipped_cards.remove_at(new_index)
		equipped_cards.insert(old_index, moved)
	award_achievement("deck_curator")
	update_deck_card_row()
	queue_shop_refresh()
	show_toast("卡牌替换：%s → %s" % [card_display_name(old_id), card_display_name(incoming_id)], Color("facc15"), 1.2)

func rarity_offer_weight(id: String) -> float:
	var rare_boost := active_vouchers.has("rare_license")
	match card_rarity(id):
		"普通": return 42.0 if rare_boost else 55.0
		"稀有": return 30.0 if rare_boost else 28.0
		"史诗": return 20.0 if rare_boost else 12.0
		"传奇": return 9.0 if rare_boost else 5.0
		"专属": return 30.0
	return 10.0

func weighted_upgrade_pick(candidates: Array) -> Dictionary:
	var total := 0.0
	var weights: Array[float] = []
	for option in candidates:
		var synergy := maxf(0.25, 1.0 + upgrade_offer_score(option) * 0.22)
		var weight := rarity_offer_weight(str(option.id)) * synergy
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()

func upgrade_offer_score(upgrade: Dictionary) -> float:
	var id := str(upgrade.id)
	var score := 0.0
	if equipped_cards.has(id):
		score += 5.0 if equipped_cards.size() >= card_slots else 2.5
	if upgrade.has("character"):
		score += 3.0
	if id in CORE_SKILL_CARD_IDS:
		score += maxf(0.0, 6.0 - float(equipped_pet_count()) * 1.3)
	if id in ["burn", "frost_brand", "homing", "projectile", "pierce", "area"] and not active_core_skill_ids().is_empty():
		score += 2.0
	for combo in DECK_COMBOS:
		var cards: Array = combo.cards
		if id == str(cards[0]) and is_card_active(str(cards[1])):
			score += 4.0
		if id == str(cards[1]) and is_card_active(str(cards[0])):
			score += 4.0
	if id == "combo_catalyst":
		score += active_combo_count() * 1.5
	if id == "core_engine":
		score += equipped_cards.size() * 0.35
	return score

func training_gain_preview(id: String) -> String:
	var specialist := ""
	var value := ""
	match id:
		"damage":
			value = "基础供能强度 +6%"
			if player.character_name == "游侠": value = "基础供能强度 +10%"; specialist = "游侠专精"
			elif player.character_name == "星火使": value = "基础供能强度 +9%"; specialist = "星火使专精"
		"cooldown": value = "基础供能间隔 -7%" if player.character_name == "星术师" else "基础供能间隔 -4%"; specialist = "星术师专精" if player.character_name == "星术师" else ""
		"speed": value = "基础移动速度 +17" if player.character_name == "影舞者" else "基础移动速度 +10"; specialist = "影舞者专精" if player.character_name == "影舞者" else ""
		"health": value = "最大生命 +12" if player.character_name in ["骑士", "守卫"] else "最大生命 +8"; specialist = "%s专精" % player.character_name if player.character_name in ["骑士", "守卫"] else ""
		"armor": value = "基础护甲 +2" if player.character_name == "骑士" else "基础护甲 +1"; specialist = "骑士专精" if player.character_name == "骑士" else ""
		"regen": value = "基础恢复 +0.22/秒" if player.character_name == "守卫" else "基础恢复 +0.12/秒"; specialist = "守卫专精" if player.character_name == "守卫" else ""
		"crit": value = ("宠物基础暴击率 +7%" if player.character_name == "影舞者" else "宠物基础暴击率 +4%") + " · 幸运 +1%"; specialist = "影舞者专精" if player.character_name == "影舞者" else ""
		"magnet": value = "基础拾取范围 +12"
	return value + (" · %s" % specialist if not specialist.is_empty() else "")

func apply_training_card(id: String) -> void:
	match id:
		"damage": stats.energy_power = minf(1.80, float(stats.energy_power) + (0.10 if player.character_name == "游侠" else (0.09 if player.character_name == "星火使" else 0.06)))
		"cooldown": stats.cooldown = maxf(0.55, float(stats.cooldown) * (0.93 if player.character_name == "星术师" else 0.96))
		"speed": player.speed += 17.0 if player.character_name == "影舞者" else 10.0
		"health": player.increase_max_health(12.0 if player.character_name in ["骑士", "守卫"] else 8.0)
		"armor": player.armor += 2.0 if player.character_name == "骑士" else 1.0
		"regen": player.regen += 0.22 if player.character_name == "守卫" else 0.12
		"crit":
			stats.crit = minf(0.85, float(stats.crit) + (0.07 if player.character_name == "影舞者" else 0.04))
			stats.luck = minf(0.12, float(stats.luck) + 0.01)
		"magnet": stats.magnet = minf(240.0, float(stats.magnet) + 12.0)
	show_toast("训练完成 · %s\n%s" % [card_display_name(id), training_gain_preview(id)], Color("4ade80"), 1.1)

func upgrade_max_level(id: String) -> int:
	if id in ENDLESS_CARD_IDS:
		return 10
	for upgrade in UPGRADES:
		if str(upgrade.id) == id:
			return int(upgrade.max)
	return 1

func apply_upgrade(id: String, from_shop := false, price := 0, offer_index := -1) -> void:
	if from_shop:
		if state != GameState.LEVEL_UP or not is_instance_valid(shop_overlay) or star_shards < price or int(upgrade_levels.get(id, 0)) >= upgrade_max_level(id):
			return
	var first_copy := int(upgrade_levels.get(id, 0)) <= 0
	if is_slot_card(id) and not equipped_cards.has(id):
		if equipped_cards.size() >= card_slots:
			if from_shop:
				show_shop_replacement(id, price, offer_index)
			return
		equipped_cards.append(id)
	upgrade_levels[id] = int(upgrade_levels.get(id, 0)) + 1
	if first_copy and id in CORE_SKILL_CARD_IDS:
		pending_story_toast = pet_first_meeting_line(id)
		award_pet_meeting_achievement(id)
		restore_insured_pet(id)
	match id:
		"damage", "cooldown", "speed", "health", "armor", "regen", "crit", "magnet": apply_training_card(id)
		"projectile", "pierce", "area": pass
		"glass":
			var previous_max_health := player.max_health
			player.reduce_max_health(20.0)
			card_runtime_values[id] = float(card_runtime_values.get(id, 0.0)) + previous_max_health - player.max_health
		"gamble":
			player.armor -= 2.0
		"ranger_focus":
			pass
		"knight_bulwark":
			has_aura = true
			aura_radius += 32.0
			player.armor += 2.0
		"mage_prism":
			has_aura = true
		"guardian_bastion":
			has_orbit = true
			orbit_count += 2
			player.increase_max_health(18.0)
		"dancer_execution":
			stats.crit = minf(0.85, float(stats.crit) + 0.12)
			momentum_enabled = true
		"fire_rite":
			has_aura = true
			aura_ignite = true
			stats.area *= 1.12
		"card_slot":
			card_slots = MAX_CARD_SLOTS
			show_toast("卡牌槽扩展至 %d 格" % card_slots, Color("70d7ff"), 1.0)
		"endless_damage", "endless_vitality", "endless_haste": pass
	refresh_derived_card_effects()
	check_evolutions()
	announce_new_combo_stories()
	if from_shop:
		star_shards -= price
		spent_star_shards += price
		shop_purchases_this_visit += 1
		mark_shop_offer_sold(offer_index)
		award_achievement("shop_first")
		play_tone(820, 0.09, 0.2)
		if not pending_story_toast.is_empty():
			show_toast(pending_story_toast, Color("70d7ff"), 2.4)
			pending_story_toast = ""
		check_achievement_progress()
		update_deck_card_row()
		queue_shop_refresh()
		return
	play_tone(820, 0.09, 0.2)

func check_evolutions() -> void:
	if not evolutions.has("molten_circuit") and is_card_active("burn") and is_card_active("chain"):
		evolutions["molten_circuit"] = true
		award_achievement("combo_adept")
		award_achievement("molten_master")
		show_toast("进化：熔雷回路\n灼烧目标被连锁电弧命中时引爆", Color("fb923c"), 2.2)
		shake_camera(8.0)
		pending_story_toast = "熔雷回路共鸣\n沉默城市的电网沿弧牙雷光重新亮起：我们看见了。"
		play_tone(760.0, 0.18, 0.2)
	if not evolutions.has("stellar_lattice") and is_card_active("aura") and (is_card_active("orbit") or is_card_active("satellite_engine")):
		evolutions["stellar_lattice"] = true
		award_achievement("combo_adept")
		award_achievement("stellar_master")
		show_toast("进化：星环矩阵\n光环标记敌人，卫星命中引爆共鸣", Color("c084fc"), 2.2)
		shake_camera(8.0)
		pending_story_toast = "星环矩阵共鸣\n暮环与环尾共同投影出轨道花园最后一次日落。"
		play_tone(880.0, 0.18, 0.2)

func show_pause() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	get_tree().paused = true
	var overlay := full_rect_control()
	overlay.name = "PauseOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(overlay)
	add_dim_background(overlay, 0.82)
	var panel := PanelContainer.new()
	panel.position = Vector2(430, 145)
	panel.size = Vector2(420, 430)
	panel.add_theme_stylebox_override("panel", panel_style(Color("0c1830"), 22, Color("355c91"), 2))
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := make_label("远征暂停", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(make_label("%s  ·  星屑 ◆%d\n生存 %s  ·  击败 %d\n本局成就 +%d" % [player.character_name, star_shards, format_time(elapsed), kills, maxi(0, SaveManager.data.achievements.size() - run_achievement_start_count)], 20, Color("9bb4d1")))
	var resume := make_button("继续", Vector2(360, 58))
	resume.process_mode = Node.PROCESS_MODE_ALWAYS
	resume.pressed.connect(resume_game)
	box.add_child(resume)
	var quit := make_button("结束本次远征", Vector2(360, 58))
	quit.process_mode = Node.PROCESS_MODE_ALWAYS
	quit.pressed.connect(func(): get_tree().paused = false; end_run(false))
	box.add_child(quit)
	box.add_child(make_label("ESC / P 继续", 16, Color("718bad")))

func resume_game() -> void:
	var overlay := ui_layer.get_node_or_null("PauseOverlay")
	if overlay:
		overlay.queue_free()
	get_tree().paused = false
	state = GameState.PLAYING

func end_run(victory: bool) -> void:
	if finished_run:
		return
	finished_run = true
	pending_boss_rewards.clear()
	mainline_completion_pending = false
	get_tree().paused = false
	state = GameState.GAME_OVER
	clear_boss_card_disruptions()
	if is_instance_valid(player):
		player.can_move = false
	award_achievement("first_expedition")
	check_achievement_progress()
	SaveManager.finish_run(elapsed, kills, boss_kills)
	clear_ui()
	var root := full_rect_control()
	ui_layer.add_child(root)
	add_dim_background(root, 0.86)
	var panel := PanelContainer.new()
	panel.position = Vector2(250, 42)
	panel.size = Vector2(780, 636)
	panel.add_theme_stylebox_override("panel", panel_style(Color("0c1830"), 24, Color("facc15") if victory else Color("ef476f"), 3))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	var result := make_label("远征成功" if victory else "远征结束", 48, Color("facc15") if victory else Color("ef7791"))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result)
	var subtitle := make_label("这一段星路已经修好。" if victory else "休息一下，伙伴们下次再出发。", 19, Color("9bb4d1"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var mode_summary := "无尽第 %d 波" % endless_wave if endless_mode else "主线 %d/6 关" % mini(boss_kills, 6)
	var new_achievements := maxi(0, SaveManager.data.achievements.size() - run_achievement_start_count)
	var summary := "生存时间  %s  ·  击败 %d  ·  Boss %d  ·  %s\n累计星屑 %d  ·  消费 %d  ·  剩余 %d\n本局解锁成就 %d  ·  新故事 %d  ·  永久保留内容只有成就与故事" % [format_time(elapsed), kills, boss_kills, mode_summary, total_star_shards, spent_star_shards, star_shards, new_achievements, run_new_story_ids.size()]
	var summary_label := make_label(summary, 18, Color("d8e5f3"))
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(summary_label)
	if not run_new_story_ids.is_empty():
		box.add_child(make_label("本次远征发现", 20, Color("c084fc")))
		var discovery_row := HBoxContainer.new()
		discovery_row.add_theme_constant_override("separation", 8)
		box.add_child(discovery_row)
		for story_id in run_new_story_ids.slice(0, 3):
			var entry: Dictionary = StoryArchiveData.get_entry(str(story_id))
			var story_button := make_button("新记忆\n%s" % str(entry.title), Vector2(230, 66))
			story_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			story_button.add_theme_font_size_override("font_size", 15)
			story_button.pressed.connect(show_story_archive.bind(str(entry.category), str(entry.id)))
			discovery_row.add_child(story_button)
	var retry := make_button("再次远征", Vector2(720, 52))
	retry.pressed.connect(start_game)
	box.add_child(retry)
	var menu := make_button("返回主菜单", Vector2(720, 48))
	menu.pressed.connect(show_main_menu)
	box.add_child(menu)
	play_tone(740 if victory else 180, 0.35, 0.25)

func show_toast(message: String, color: Color = Color.WHITE, duration := 1.5) -> void:
	if not is_instance_valid(toast_label):
		return
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(duration)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)

func shake_camera(amount: float) -> void:
	if not bool(SaveManager.data.settings.screenshake) or not is_instance_valid(camera):
		return
	var tween := create_tween()
	for i in 5:
		tween.tween_property(camera, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.035)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)

func play_tone(frequency: float, duration: float, volume := 0.12) -> void:
	if not bool(SaveManager.data.settings.sound):
		return
	var sample_rate := 22050
	var frames := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var envelope := 1.0 - float(i) / frames
		var sample := sin(TAU * frequency * float(i) / sample_rate) * envelope * volume
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()

func play_boss_warning_sound() -> void:
	if not bool(SaveManager.data.settings.sound):
		return
	# One short descending horror sting. It is deliberately non-looping and uses
	# a low rumble plus a decaying scrape instead of the regular sine-wave beep.
	var sample_rate := 22050
	var duration := 0.62
	var frames := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var noise_state := 0.0
	for i in frames:
		var progress := float(i) / float(frames)
		var seconds := float(i) / float(sample_rate)
		var attack := minf(1.0, progress / 0.045)
		var release := pow(1.0 - progress, 1.7)
		var envelope := attack * release
		var descending_frequency := lerpf(92.0, 43.0, progress)
		var rumble := sin(TAU * descending_frequency * seconds + progress * 5.0)
		var sub := sin(TAU * 34.0 * seconds) * 0.52
		noise_state = lerpf(noise_state, randf_range(-1.0, 1.0), 0.07)
		var scrape := noise_state * sin(PI * progress) * 0.34
		var initial_hit := sin(TAU * 168.0 * seconds) * exp(-seconds * 15.0) * 0.45
		var sample := (rumble * 0.58 + sub + scrape + initial_hit) * envelope * 0.28
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.finished.connect(audio.queue_free)
	add_child(audio)
	audio.play()

func format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [total / 60, total % 60]
