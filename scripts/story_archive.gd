class_name StoryArchive
extends RefCounted

const CATEGORIES := ["主线纪事", "人物志", "星灵谱", "异象录", "遗物馆"]

# unlock 为空表示基础公开档案；条目ID与解锁条件保持不变，兼容旧存档。
const ENTRIES := [
	# 主线纪事
	{"id":"chronicle_origin", "category":"主线纪事", "title":"会发光的伙伴", "subtitle":"远征者和星灵一起守护家园", "unlock":"", "hint":"基础档案", "content":"很久以前，天空中漂着许多星光岛。可爱的星灵住在岛上，帮助大家照明、送信、修路和赶走怪物。\n\n星灵有力量，却需要伙伴为它们补充能量。远征者发出的光弹不会伤害敌人。光弹射中星灵后，星灵就会把能量变成自己的技能。这就是每场战斗最重要的配合。"},
	{"id":"chronicle_archive", "category":"主线纪事", "title":"天穹大灯塔", "subtitle":"本来保护大家的机器出了故障", "unlock":"first_expedition", "hint":"完成任意一次远征", "content":"天穹大灯塔为所有星光岛指路，也保存着每只星灵的资料。一次巨大的能量风暴袭来，灯塔为了保护大家，把所有道路和星灵都锁了起来。\n\n灯塔用力过头，六道安全门一起损坏。道路被撕成了不断变化的星渊，三位守门人也忘记了自己的任务。远征队必须修好六道门，让天空重新亮起来。"},
	{"id":"chronicle_abyss", "category":"主线纪事", "title":"会移动的星渊", "subtitle":"所以地图永远走不到尽头", "unlock":"first_blood", "hint":"击败第一名敌人", "content":"星渊是被能量风暴搅乱的道路。碎路会在远征者脚下重新拼好，所以这里看不到边界。走得越远，新的道路就会继续出现。\n\n坏掉的机器和乱跑的能量变成了怪物。打败它们会掉落星屑。星屑可以在每关后的商店购买宠物卡、规则卡和训练卡。"},
	{"id":"chapter_1", "category":"主线纪事", "title":"第一关：迷路的领航员", "subtitle":"先从追击中找到安全路线", "unlock":"chaser_breaker", "hint":"击败星渊追猎者", "content":"第一道门前，领航员赫巡被故障指令控制。他把所有离开旧路线的人都当成危险目标，不停追赶远征队。\n\n击败他以后，大家找到一张通往月港的手画地图。赫巡还记得自己的学生岚，只是故障让他无法说出真正想走的路。"},
	{"id":"chapter_2", "category":"主线纪事", "title":"第二关：关得太紧的城门", "subtitle":"躲开陷阱，打开出口", "unlock":"warden_breaker", "hint":"击败星渊禁锢者", "content":"第二道门由工程师弥垣看守。她害怕能量风暴进入城市，于是在地上放满裂隙陷阱，不让任何人靠近。\n\n远征队打破控制装置后，弥垣终于想起：城门既能关上，也应该在安全时打开。她留下了寻找裂隙出口的罗盘。"},
	{"id":"chapter_3", "category":"主线纪事", "title":"第三关：算错的守护机器", "subtitle":"看清预警，躲过大爆发", "unlock":"judge_breaker", "hint":"击败星渊裁决者", "content":"第三道门前，天秤·零号认为，只要赶走所有闯入者，灯塔就一定安全。它会先蓄力，再打出很强的能量攻击。\n\n星火使问它：如果大家都不能回家，空灯塔还要保护谁？零号第一次停下来思考，也给远征队留下了继续前进的机会。"},
	{"id":"interlude_first_cycle", "category":"主线纪事", "title":"三位守门人的合照", "subtitle":"他们原来都是保护大家的英雄", "unlock":"boss_trio", "hint":"在一局中击败三名Boss", "content":"三件Boss遗物合在一起，放出一张旧照片。赫巡负责带路，弥垣负责修门，零号负责看守灯塔。\n\n他们不是坏人，只是被错误指令困住了。接下来的三关，远征队要再次找到他们，帮助他们彻底摆脱控制。"},
	{"id":"chapter_4", "category":"主线纪事", "title":"第四关：赫巡想起名字", "subtitle":"最快的路不一定是正确的路", "unlock":"fourth_seal", "hint":"单局击败第四名Boss", "content":"赫巡再次出现。这一次，他的面甲裂开了，也认出了岚。他不停冲刺，是想赶在道路崩塌前把大家推回去。\n\n岚证明远征队能照顾好自己。赫巡终于交出第十三号路线图，并告诉她：好领航员负责提醒危险，但不替别人选择终点。"},
	{"id":"chapter_5", "category":"主线纪事", "title":"第五关：弥垣打开大门", "subtitle":"真正的保护也要给人自由", "unlock":"fifth_seal", "hint":"单局击败第五名Boss", "content":"弥垣把最重要的修理图藏在城门里。故障让她忘了这件事，只记得不停加固围墙和陷阱。\n\n砾用自己设计的新出口唤醒了她。弥垣关闭陷阱，打开大门，并把修理图交给远征队。"},
	{"id":"chapter_6", "category":"主线纪事", "title":"第六关：一起修好灯塔", "subtitle":"宠物不是工具，而是伙伴", "unlock":"six_seals", "hint":"完成六关主线", "content":"最后一道门后，零号想收走所有星灵的力量，用最简单的办法修复灯塔。这样虽然快，星灵却会失去自己的样子。\n\n远征者把能量送给星灵，星灵又把力量传给灯塔。零号终于明白，合作比抢走力量更可靠。六道门全部亮起，主线远征完成。"},
	{"id":"endless_0", "category":"主线纪事", "title":"修好以后继续巡逻", "subtitle":"无尽挑战从这里开始", "unlock":"endless_walker", "hint":"进入无尽挑战", "content":"灯塔已经重新发光，但星渊里还有很多散落的故障能量。远征队决定继续向前，帮助更多迷路的星灵。\n\n无尽模式没有最后一关。敌人会一波波变强，三位Boss也会带着不同词条回来训练大家。商店和卡组成长会一直继续。"},
	{"id":"endless_3", "category":"主线纪事", "title":"怪物学会新花样", "subtitle":"第三波开始，它们会观察卡组", "unlock":"endless_three", "hint":"抵达无尽第3波", "content":"第三波以后，故障能量学会改变战法。它们会打乱卡牌、封住规则，甚至暂时带走宠物。\n\n这些效果都有预警，也有解除办法。看清Boss词条，保护好宠物，就能把不利情况变成反击机会。"},
	{"id":"endless_6", "category":"主线纪事", "title":"六封寄回家的信", "subtitle":"每位远征者都有新的计划", "unlock":"endless_six", "hint":"抵达无尽第6波", "content":"第六波结束后，六名远征者各写了一封信。有人想重修月港，有人想开一所星灵学校，还有人要继续修理星路。\n\n他们的计划都不一样，却有同一句话：等巡逻结束，我们会带着星灵一起回家。"},
	{"id":"endless_9", "category":"主线纪事", "title":"第九波的路灯", "subtitle":"赫巡为迷路的人留下方向", "unlock":"endless_nine", "hint":"抵达无尽第9波", "content":"第九波深处，赫巡用旧地图搭起一盏路灯。它不要求大家走同一条路，只在危险的地方发出提醒。\n\n路灯上写着一句很简单的话：路是用来帮助大家见面的。"},
	{"id":"endless_12", "category":"主线纪事", "title":"城门外的第一棵树", "subtitle":"弥垣开始修建新的城市", "unlock":"endless_twelve", "hint":"抵达无尽第12波", "content":"弥垣打开旧城以后，在门外种下了一棵小树。她每天记录风雨，却不再因为害怕危险而把门锁死。\n\n她和砾一起修路、搭桥，还给每座新房子画了两个出口。"},
	{"id":"endless_20", "category":"主线纪事", "title":"第二十波的约定", "subtitle":"只要还有伙伴，远征就能继续", "unlock":"endless_twenty", "hint":"抵达无尽第20波", "content":"走到第二十波时，远征队已经离灯塔很远。回头看去，他们发现一路上的星灵都点起了小灯。\n\n这些灯连成新的星路。每次重新出发，都像在地图上多画一笔。总有一天，整个星渊都会再次亮起来。"},

	# 人物志：每位远征者两篇，三名Boss各两篇
	{"id":"char_ranger_1", "category":"人物志", "title":"游侠：岚", "subtitle":"跑得快、供能也快的信使", "unlock":"ranger_journey", "hint":"使用游侠开始远征", "content":"岚在月港送信，老师正是领航员赫巡。她擅长边跑边瞄准，同一只宠物连续接到她的光弹时，会更快积满能量。\n\n月港道路失踪后，她带着弧牙进入星渊。她想修好道路，也想把一封迟到很久的家书送到终点。"},
	{"id":"char_ranger_2", "category":"人物志", "title":"岚的最后一封信", "subtitle":"普通的小事也值得送到", "unlock":"untouchable_minute", "hint":"完成无伤序曲", "content":"信上只写着：晚饭不用等我，我会晚一点回家。岚以前觉得这句话太普通。\n\n后来她明白，正是晚饭、天气和朋友这些小事，让家变得重要。所以再难走的路，她也要把信送完。"},
	{"id":"char_knight_1", "category":"人物志", "title":"骑士：洛恩", "subtitle":"挨打也能给宠物补充能量", "unlock":"knight_journey", "hint":"使用骑士开始远征", "content":"洛恩曾守在静止之城的东门。他有厚重的护甲，也会在受伤或挡住攻击时，把冲击转成宠物能量。\n\n听见城里有人求救后，他第一次打开了自己看守的大门。他相信，盾应该保护身后的人，而不是只保护一条命令。"},
	{"id":"char_knight_2", "category":"人物志", "title":"会发光的旧盾", "subtitle":"暮环帮助骑士守住伙伴", "unlock":"healthy_boss", "hint":"以高生命击败Boss", "content":"洛恩的护盾里住着暮环。暮环张开光环时，可以照亮附近敌人，也能帮助骑士站得更稳。\n\n洛恩负责挡住危险，暮环负责把吸收的能量还给队伍。他们是最有耐心的一对伙伴。"},
	{"id":"char_mage_1", "category":"人物志", "title":"星术师：弥星", "subtitle":"一次能发出两枚供能弹", "unlock":"mage_journey", "hint":"使用星术师开始远征", "content":"弥星喜欢研究星灵怎样使用能量。她能把一次供能分成两条细光，让两只宠物更容易轮流发动技能。\n\n她跑得不算快，身体也比较弱，所以更需要安排宠物位置和攻击范围。她总说：先想好队形，再让星光出发。"},
	{"id":"char_mage_2", "category":"人物志", "title":"弥星的组合笔记", "subtitle":"好伙伴一起行动会更强", "unlock":"combo_adept", "hint":"解锁任意武器进化", "content":"弥星发现，两只合适的星灵放在一起，会产生新的技能。火和雷可以爆燃，引力和星核可以一起爆开。\n\n她把这些发现画成简单图案，贴在卡牌边上。这样大家在商店里就能看懂该怎样组成队伍。"},
	{"id":"char_guardian_1", "category":"人物志", "title":"守卫：砾", "subtitle":"站稳以后供能更有力", "unlock":"guardian_journey", "hint":"使用守卫开始远征", "content":"砾是一位修理师。他的护甲很厚，停下脚步时能把供能弹打得更稳，让宠物获得更多力量。\n\n他曾帮弥垣修建高墙。发现墙里没有出口后，他带着两只施工星灵回来拆墙。"},
	{"id":"char_guardian_2", "category":"人物志", "title":"有名字的施工卫星", "subtitle":"工具也能成为朋友", "unlock":"aegis_bearer", "hint":"获得星辉壁垒", "content":"工程队只给卫星编号，砾却给每一台都取了名字。它们休息时喜欢轻轻碰在一起，像是在打招呼。\n\n有一次砾倒下了，卫星们自己组成护盾救了他。从那以后，没有人再说它们只是工具。"},
	{"id":"char_dancer_1", "category":"人物志", "title":"影舞者：绯", "subtitle":"移动越快，宠物越有精神", "unlock":"dancer_journey", "hint":"使用影舞者开始远征", "content":"绯能快速闪过敌人的包围。她不停移动时，会带起一阵能量风，让跟随的宠物更快准备好技能。\n\n她以前替灯塔传送命令。发现命令会伤害无辜的人后，她带走名单，开始帮助名单上的人回家。"},
	{"id":"char_dancer_2", "category":"人物志", "title":"绯的新节拍", "subtitle":"速度也可以用来救人", "unlock":"streak_master", "hint":"触发连杀号令", "content":"绯以前只知道快速完成任务。加入远征队后，她把脚步变成队伍的节拍。\n\n宠物跟着她一只接一只发动技能，怪物便很难靠近。她终于发现，跑得快不只是为了追赶，也能帮助伙伴脱险。"},
	{"id":"char_fire_1", "category":"人物志", "title":"星火使：烬歌", "subtitle":"连续供能会让火焰越来越热", "unlock":"fire_journey", "hint":"使用星火使开始远征", "content":"烬歌来自温暖的余烬城。她连续把光弹送给同一只宠物时，会积累热量，让宠物的下一次攻击更有力量。\n\n能量风暴熄灭了城里的大炉火。烬歌带着坠火出发，要从星渊带回火种，重新点亮家乡。"},
	{"id":"char_fire_2", "category":"人物志", "title":"重新点亮的街灯", "subtitle":"火与雷组成熔雷回路", "unlock":"molten_master", "hint":"进化熔雷回路", "content":"当弧牙的雷碰到坠火留下的火焰，能量会沿着敌群快速跳动。烬歌把这种组合叫作熔雷回路。\n\n第一次成功时，远方的余烬城亮起了一排街灯。烬歌知道，回家的路还在那里。"},
	{"id":"boss_chaser_1", "category":"人物志", "title":"赫巡：领航员", "subtitle":"追击型Boss以前是带路英雄", "unlock":"chaser_breaker", "hint":"击败星渊追猎者", "content":"赫巡熟悉每一条星路，也教会岚怎样看地图。能量风暴来临时，他带着很多人安全回家。\n\n灯塔的故障指令让他不停追赶离开旧路线的人。击败他不是为了消灭他，而是为了打掉控制他的坏芯片。"},
	{"id":"boss_chaser_2", "category":"人物志", "title":"追击中的小缺口", "subtitle":"看准方向就能躲开冲刺", "unlock":"flawless_boss", "hint":"无伤击败一名Boss", "content":"赫巡每次冲刺前都会改变姿势，还会故意留下一条能躲开的路。那是他还没有忘记的领航习惯。\n\n读懂提示并躲开全部冲刺，就能让他想起：自己的任务是带路，不是堵路。"},
	{"id":"boss_warden_1", "category":"人物志", "title":"弥垣：城门工程师", "subtitle":"控场型Boss以前负责修城", "unlock":"warden_breaker", "hint":"击败星渊禁锢者", "content":"弥垣设计了坚固的城门和安全通道。风暴来时，她关门保护了很多人。\n\n可是故障指令一直说危险没有结束。她便不停制造陷阱和围墙，忘了门外还有等待回家的人。"},
	{"id":"boss_warden_2", "category":"人物志", "title":"门里面的纸条", "subtitle":"大家想自己走出城门", "unlock":"last_stand_boss", "hint":"低生命击败一名Boss", "content":"城里的人写了很多纸条，请弥垣在安全时开门。她读过每一张，却总担心外面还有危险。\n\n远征者从陷阱中坚持下来，让她看到大家已经学会保护自己。她终于愿意和大家一起走出去。"},
	{"id":"boss_judge_1", "category":"人物志", "title":"天秤·零号", "subtitle":"爆发型Boss也是灯塔管家", "unlock":"judge_breaker", "hint":"击败星渊裁决者", "content":"零号是一台负责管理灯塔的大机器。它会计算能量，也会在道路危险时发出警报。\n\n故障以后，它只记得“不能让灯塔受伤”，却忘了灯塔是为了帮助大家。它的强力攻击有清楚预警，抓住空隙就能反击。"},
	{"id":"boss_judge_2", "category":"人物志", "title":"零号保留的一秒钟", "subtitle":"看见亮光就准备躲避", "unlock":"six_seals", "hint":"完成六关主线", "content":"零号的大爆发总会先蓄力一小会儿。即使故障，它也没有删掉这段安全提醒。\n\n这说明它心里还记得自己的旧任务：保护大家。远征队利用这一秒躲开攻击，也利用这一秒唤醒了零号。"},

	# 星灵谱
	{"id":"pet_aura", "category":"星灵谱", "title":"暮环：虚空水母", "subtitle":"吸收能量后展开近身光环", "unlock":"meet_aura", "hint":"获得暮环·虚空光环", "content":"暮环以前负责点亮夜间花园。吸收足够供能弹后，它会展开一圈光，攻击靠近自己的敌人。\n\n它喜欢待在伙伴附近。敌人离得太远时，它会把能量留着，不会对着空地乱放技能。"},
	{"id":"pet_orbit", "category":"星灵谱", "title":"环尾：星轨狐", "subtitle":"召唤卫星绕着自己旋转", "unlock":"meet_orbit", "hint":"获得环尾·轨道卫星", "content":"环尾用大尾巴牵引小卫星。吸收能量后，卫星会围着它转动，撞击靠近的敌人。\n\n它和暮环是老朋友。把它们与枢核放进同一套卡组，可以组成更大的星环矩阵。"},
	{"id":"pet_hive", "category":"星灵谱", "title":"枢核：机械蜂巢", "subtitle":"制造更多轨道卫星", "unlock":"meet_satellite_engine", "hint":"获得枢核·卫星引擎", "content":"枢核是一只会修机器的小星灵。得到能量后，它会制造卫星，帮助附近的宠物作战。\n\n它制造的每枚卫星都有不同的小灯。枢核说，这样大家就不会认错自己的伙伴。"},
	{"id":"pet_chain", "category":"星灵谱", "title":"弧牙：雷电鳗龙", "subtitle":"雷电会在附近敌人之间跳跃", "unlock":"meet_chain", "hint":"获得弧牙·磁暴线圈", "content":"弧牙喜欢追着电流游动。它的技能会先打中近处敌人，再跳向旁边的目标。\n\n敌人站得越密，弧牙越开心。火焰和导电同时出现时，还会产生一次熔雷爆燃。"},
	{"id":"pet_nova", "category":"星灵谱", "title":"爆星：星核幼狮", "subtitle":"对身边敌人发动星核爆破", "unlock":"meet_nova", "hint":"获得爆星·星核爆破", "content":"爆星像一只装着小太阳的幼狮。敌人靠近并且能量充满时，它会大声咆哮，炸开一圈星光。\n\n黯潮能把敌人拉到它身边。两只星灵配合，就能让近身爆破击中更多目标。"},
	{"id":"pet_phase", "category":"星灵谱", "title":"瞬影：裂隙狐", "subtitle":"冲向敌人并留下相位印记", "unlock":"meet_phase_step", "hint":"获得瞬影·相位突进", "content":"瞬影是一只跑得很快的小狐狸。充满能量后，它会穿过附近的敌人，并留下发亮的印记。\n\n刃舞最会追踪这种印记。两只宠物一起行动时，会形成连续的瞬身刃舞。"},
	{"id":"pet_thunder", "category":"星灵谱", "title":"鸣霄：风暴猫头鹰", "subtitle":"把雷球投向重要目标", "unlock":"meet_thunder_orb", "hint":"获得鸣霄·雷暴法球", "content":"鸣霄总会先观察战场。能量充满后，它会把雷球投向攻击范围内最危险的敌人。\n\n它喜欢准确，弧牙喜欢热闹。两只宠物虽然常争论，组合起来却能让雷电跳得更远。"},
	{"id":"pet_gravity", "category":"星灵谱", "title":"黯潮：黑洞蝠鲼", "subtitle":"把附近敌人拉到一起", "unlock":"meet_gravity_well", "hint":"获得黯潮·引力奇点", "content":"黯潮慢慢游在空中。它吸收能量后会造出小型引力井，把一定范围内的敌人拉向中心。\n\n它本身不追求很高伤害，真正的本领是为爆星、坠火和范围技能摆好目标。"},
	{"id":"pet_blade", "category":"星灵谱", "title":"刃舞：星刃螳螂", "subtitle":"飞刃环绕自身并切开敌群", "unlock":"meet_blade_dance", "hint":"获得刃舞·星刃回环", "content":"刃舞挥动两把星刃保护伙伴。能量充满时，飞刃会绕着它旋转，攻击靠近的敌人。\n\n瞬影留下相位印记后，刃舞能更快找到目标。一个负责开路，一个负责守住退路。"},
	{"id":"pet_meteor", "category":"星灵谱", "title":"坠火：陨星幼龙", "subtitle":"召唤陨星轰击一片区域", "unlock":"meet_meteor_rain", "hint":"获得坠火·陨星坠落", "content":"坠火背着一袋没有落下的流星。发现范围内有敌人并吸满能量后，它会召唤陨星雨。\n\n陨星能灼烧地面。敌人先被寒霜冻住时，火焰会在破冰的一刻一起爆开。"},
	{"id":"pet_aegis", "category":"星灵谱", "title":"星垒：晶甲星龟", "subtitle":"展开护盾挡住一次危险", "unlock":"meet_aegis", "hint":"获得星垒·星辉壁垒", "content":"星垒不喜欢冲在最前面，却很会照顾伙伴。能量充满后，它会展开晶甲护盾，挡住一次危险攻击。\n\n护盾给远征者留下调整位置的时间。保护好队伍，也是赢得战斗的方法。"},
	{"id":"pet_execute", "category":"星灵谱", "title":"断罪：裁决渡鸦", "subtitle":"结束生命很低的普通敌人", "unlock":"meet_execute", "hint":"获得断罪·终结印记", "content":"断罪能看出普通怪物什么时候已经没有力气。吸满能量后，它会标记并击倒生命很低的非Boss敌人。\n\n它不会直接处决Boss。Boss战仍要靠远征者和宠物看准机会、一起完成。"},
	{"id":"combo_stellar", "category":"星灵谱", "title":"组合：星环矩阵", "subtitle":"暮环、环尾与枢核共同组队", "unlock":"stellar_master", "hint":"进化星环矩阵", "content":"暮环负责光环，环尾负责轨道，枢核负责制造卫星。三只宠物放进同一套卡组后，会组成星环矩阵。\n\n更多卫星会围绕宠物行动，光环也会更稳定。这是轨道宠物最完整的成长路线。"},
	{"id":"combo_molten", "category":"星灵谱", "title":"组合：熔雷回路", "subtitle":"让雷电点燃灼烧目标", "unlock":"molten_master", "hint":"进化熔雷回路", "content":"先用火焰让敌人进入灼烧，再让弧牙的雷电命中。火与雷会一起爆开，并把伤害传向旁边敌人。\n\n面对挤在一起的怪群时，这套组合特别有用。"},
	{"id":"combo_frostfire", "category":"星灵谱", "title":"组合：极寒天火", "subtitle":"寒霜锁住敌人，陨星负责引爆", "unlock":"combo_frostfire", "hint":"首次激活极寒天火", "content":"寒霜先让敌人减速并留下印记，坠火的陨星随后击中印记，就会发生更大的爆炸。\n\n先控制、后轰击，这个顺序很重要。调整卡牌位置能让组合更容易成功。"},
	{"id":"combo_collapse", "category":"星灵谱", "title":"组合：坍缩爆心", "subtitle":"黯潮聚怪，爆星近身引爆", "unlock":"combo_collapse", "hint":"首次激活坍缩爆心", "content":"黯潮先把敌人拉到一起，爆星再在中心发动星核爆破。原本分散的敌人会一起受到攻击。\n\n这套组合需要宠物靠近战场，也要注意Boss的范围攻击。"},
	{"id":"combo_blade", "category":"星灵谱", "title":"组合：瞬身刃舞", "subtitle":"相位印记为飞刃指出路线", "unlock":"combo_blade", "hint":"首次激活瞬身刃舞", "content":"瞬影冲过敌群后留下印记，刃舞的飞刃会沿着印记继续攻击。\n\n两只速度型宠物互相接力，适合追赶跑得快的敌人。"},
	{"id":"combo_storm", "category":"星灵谱", "title":"组合：风暴导体", "subtitle":"鸣霄选目标，弧牙传雷电", "unlock":"combo_storm", "hint":"首次激活风暴导体", "content":"鸣霄先用雷球给重要敌人加上导电，弧牙再让雷电从它身上跳向更多目标。\n\n对付Boss和周围小怪同时出现的场面，这套组合最方便。"},

	# 异象录
	{"id":"rule_cards", "category":"异象录", "title":"七格远征卡匣", "subtitle":"卡牌从左到右帮助宠物", "unlock":"deck_full", "hint":"装满当前全部卡槽", "content":"远征卡匣最多能放七张牌。宠物卡负责行动，规则卡负责改变旁边宠物的范围、目标和伤害。\n\n每次宠物发动技能，卡牌都会从左到右检查。把合适的规则放在宠物左边或右边，才能组成更强的触发链。"},
	{"id":"rule_replace", "category":"异象录", "title":"卡槽满了怎么办", "subtitle":"出售旧牌或放弃新牌", "unlock":"deck_curator", "hint":"完成第一次卡牌替换", "content":"卡槽装满后，不能再硬塞第八张牌。你可以出售一张旧牌，再购买更合适的新牌，也可以直接离开商店。\n\n被出售的宠物会回到星灵站休息，不会受伤。下一次远征还有机会再次遇见它。"},
	{"id":"rule_editions", "category":"异象录", "title":"卡牌的特殊版本", "subtitle":"Boss奖励能改造已有卡牌", "unlock":"first_relic", "hint":"获得第一件Boss遗物", "content":"击败Boss后，有机会把一张牌改造成闪箔、镭射、多彩或回响版本。每种版本都有不同帮助。\n\n改造不会占用新卡槽。它代表宠物经历Boss战后学会了新本领。"},
	{"id":"enemy_chaser", "category":"异象录", "title":"普通怪：追猎者", "subtitle":"会从侧面靠近", "unlock":"first_blood", "hint":"击败第一名敌人", "content":"小型追猎者来自损坏的导航机器。它们会绕到侧面，再向远征者靠近。\n\n保持移动，并让近战宠物守住身边，就能处理它们。"},
	{"id":"enemy_runner", "category":"异象录", "title":"普通怪：疾行兽", "subtitle":"会突然加速冲过来", "unlock":"fifty_fallen", "hint":"单局击败50名敌人", "content":"疾行兽是跑得很快的故障能量。它们会先寻找空隙，然后突然加速。\n\n减速、寒霜和远程宠物都能阻止它们靠近。"},
	{"id":"enemy_tank", "category":"异象录", "title":"普通怪：重甲怪", "subtitle":"速度慢，但是很耐打", "unlock":"hundred_fallen", "hint":"单局击败100名敌人", "content":"重甲怪由坏掉的城门零件组成。它们走得慢、生命高，会一步步挤压活动空间。\n\n持续灼烧和宠物组合可以更快打破它的外壳。"},
	{"id":"enemy_caster", "category":"异象录", "title":"普通怪：咒术师", "subtitle":"保持距离发射弹幕", "unlock":"swarm_breaker", "hint":"单局击败250名敌人", "content":"咒术师是失控的远程防卫机器。它们会和远征者保持距离，再向预计的位置射击。\n\n快速接近、相位突进或远程宠物都能对付它们。"},
	{"id":"element_reactions", "category":"异象录", "title":"五种战斗状态", "subtitle":"火、霜、雷、引力和相位可以组合", "unlock":"elemental_trinity", "hint":"达成元素三相", "content":"灼烧会持续伤害，寒霜会减速，导电会传递雷击，引力会把敌人聚在一起，相位会留下追击印记。\n\n两种合适状态接在一起，会产生更强反应。看卡牌说明并调整左右顺序，就能找到组合。"},
	{"id":"affix_assault", "category":"异象录", "title":"Boss词条：急袭与裂隙", "subtitle":"一个变快，一个改变地面", "unlock":"affix_field", "hint":"遭遇急袭脉冲或裂隙蔓延", "content":"急袭会让Boss更常行动，裂隙会在地面放出有预警的危险区域。\n\n看到提示后及时移动。裂隙不会立刻爆炸，玩家总有躲开的时间。"},
	{"id":"affix_counter", "category":"异象录", "title":"Boss词条：弱点与屏障", "subtitle":"看懂规则就能反击", "unlock":"affix_counter", "hint":"遭遇暴露核心或棱镜屏障", "content":"暴露核心会让Boss在强力攻击后短暂变弱。棱镜屏障会减少宠物收到的供能，但不会一直存在。\n\n等待屏障结束，再集中给宠物供能，是最安全的反击办法。"},
	{"id":"affix_deck", "category":"异象录", "title":"Boss词条：封印契约", "subtitle":"一张卡会暂时休息", "unlock":"affix_deck", "hint":"遭遇封印契约", "content":"Boss会暂时封住一张卡，让它不能参与从左到右的结算。卡牌不会丢失，时间结束后就会回来。\n\n击败五名小怪还能提前解除封印。注意卡组变化，换用仍在工作的宠物。"},
	{"id":"affix_pet", "category":"异象录", "title":"Boss词条：窃宠与魅惑", "subtitle":"靠近宠物可以更快救回它", "unlock":"affix_pet", "hint":"遭遇星渊窃宠或倒戈魅惑", "content":"窃宠会暂时把宠物拉向Boss，魅惑会让宠物认错伙伴。这些效果都不会永久带走宠物。\n\n靠近受影响的宠物，可以帮助它更快清醒。保护伙伴也是Boss战的一部分。"},
	{"id":"affix_shuffle", "category":"异象录", "title":"Boss词条：逆序洗牌", "subtitle":"卡牌顺序会暂时反过来", "unlock":"affix_shuffle", "hint":"遭遇逆序洗牌", "content":"逆序洗牌会把整套卡牌暂时倒过来，左右作用范围也会跟着改变。\n\n效果结束后，卡牌会回到原位。观察结算提示，先用不依赖位置的宠物应战。"},
	{"id":"rule_death", "category":"异象录", "title":"为什么每局重新开始", "subtitle":"带回家的只有成就与故事", "unlock":"first_expedition", "hint":"完成任意一次远征", "content":"每次进入星渊，卡牌、训练和遗物都会用临时星光组成。远征结束后，这些力量会散去，下一局要重新搭配。\n\n成就记录真正完成过的挑战，可以永久解锁角色和故事。没有局外属性加成，每次出发都公平。"},
	{"id":"rule_infinite", "category":"异象录", "title":"为什么地图没有边界", "subtitle":"坏掉的星路会不断重新拼接", "unlock":"survive_three", "hint":"生存三分钟", "content":"能量风暴把星路拆成许多小块。远征者向前走时，碎路会在脚下自动拼好，所以地图可以一直延伸。\n\n身后的旧路会慢慢淡去，前方则出现新的网格、星光和敌群。这就是无限滚动地图。"},

	# 遗物馆
	{"id":"relic_boots", "category":"遗物馆", "title":"追猎者的步伐", "subtitle":"角色遗物：赫巡留下的领航靴", "unlock":"relic_predator_boots", "hint":"获得追猎者的步伐", "content":"这双靴子陪赫巡走过许多危险道路。穿上它会提高角色移动速度，也会让角色更快发出供能弹。\n\n它只强化角色与供能，不直接增加宠物伤害。靴底还有一条空白路线，等着新的远征者把它走完。"},
	{"id":"relic_compass", "category":"遗物馆", "title":"裂隙罗盘", "subtitle":"宠物遗物：指向最近出口的修理工具", "unlock":"relic_rift_compass", "hint":"获得裂隙罗盘", "content":"弥垣用这只罗盘检查城墙。指针不指向北方，而是指向最需要出口的地方。\n\n它会扩大全部宠物技能范围。黯潮使用引力奇点时，还能把更远的敌人拉到一起。"},
	{"id":"relic_spark", "category":"遗物馆", "title":"裁决火花", "subtitle":"宠物遗物：零号掉落的小火花", "unlock":"relic_judge_spark", "hint":"获得裁决火花", "content":"零号第一次不知道该怎么回答时，核心里掉出一颗小火花。它提醒大家，再聪明的机器也可能算漏重要事情。\n\n火花会提高全部宠物的暴击率和暴击伤害。宠物暴击率最高为85%。"},
	{"id":"relic_ember", "category":"遗物馆", "title":"余烬容器", "subtitle":"宠物遗物：保存家乡炉火的小罐子", "unlock":"relic_ember_vessel", "hint":"获得余烬容器", "content":"烬歌把余烬城最后的火种装在这里。靠近时，能听见街道和学校里的声音。\n\n它让全部宠物命中时附加灼烧。着火的敌人倒下时，还会点燃旁边的怪物。"},
	{"id":"relic_aegis", "category":"遗物馆", "title":"壁垒碎片", "subtitle":"角色遗物：星垒旧护甲的一小块", "unlock":"relic_aegis_fragment", "hint":"获得壁垒碎片", "content":"星垒为了保护伙伴，挡住攻击时掉下了这块晶甲。碎片仍会在危险靠近时发亮。\n\n它会提高角色的生命和护甲，并立刻提供一层护盾。它只保护角色，不会替代星垒宠物卡。"},
	{"id":"relic_storm", "category":"遗物馆", "title":"风暴继电器", "subtitle":"宠物遗物：帮助雷电宠物互相传话", "unlock":"relic_storm_relay", "hint":"获得风暴继电器", "content":"弧牙住在海底，鸣霄飞在高空。这台小机器让它们的雷声能够互相传到。\n\n装备以后，弧牙电弧固定增加两次跳跃，鸣霄雷暴范围增加25%。"},
	{"id":"relic_gallery", "category":"遗物馆", "title":"六件遗物的完整地图", "subtitle":"每位伙伴都贡献了一块线索", "unlock":"relic_master", "hint":"单局集齐六种Boss遗物", "content":"六件遗物放在一起，会拼成一张修复灯塔的地图。靴子负责带路，罗盘寻找出口，火花启动机器，火种重新点灯，护甲保护队伍，继电器连接大家。\n\n没有哪一件遗物能单独完成任务。就像远征一样，真正强大的力量来自合作。"}
]

static func get_entry(id: String) -> Dictionary:
	for entry in ENTRIES:
		if str(entry.id) == id:
			return entry
	return {}

static func entries_for_category(category: String) -> Array:
	return ENTRIES.filter(func(entry): return str(entry.category) == category)
