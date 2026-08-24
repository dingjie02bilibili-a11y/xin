# 星渊幸存者

一个使用 Godot 4 与 GDScript 制作的俯视角肉鸽生存游戏原型。角色、敌人、特效、场景与短音效均由代码实时生成，不依赖第三方素材。

## 运行方式

1. 安装 Godot 4.4 或更高版本。
2. 在项目管理器中导入本目录下的 `project.godot`。
3. 运行项目，或按 `F6/F5`。

## 操作

- `WASD` 或方向键：移动
- `Esc` 或 `P`：暂停 / 继续
- 主角每轮为每只未充满的星灵宠物各发射一枚供能弹；宠物充满能量后自动释放技能，够不着目标时会主动扑上去
- `F2`：仅编辑器调试模式可用，获得 10 星屑

## 游戏循环

- 主线共六章，Boss 在 1、2、3、4、5 分钟和 5分55秒出现。
- 击败敌人获得星屑；星屑用于定时出现的商店，不会触发经验升级。
- 商店出售一次性角色训练、宠物、构筑规则、遗物改造、符文、补充包、远征许可与可反复投入的星屑熔炉。
- 宠物与规则牌进入最多 7 格的卡组；每次宠物释技都按卡组从左到右结算加算、乘算、邻接和牌型。
- 宠物使用连续供能：超出施法需求的能量会保留，供下一次释放使用。
- 每个角色开局携带两只互补的星灵宠物。
- 击败 Boss 后从遗物共鸣或宠物版本中选择奖励，并获得最大生命、护甲与大额回复。
- 完成第六章后可以胜利结算，也可以继续进入无尽挑战。
- 所有战斗强化只在当前远征生效；局外仅保留角色、成就和故事解锁，不提供永久属性加成。
- 主线难度会跟着你走（无尽模式不参与，波数需要在不同存档间可比）：
  慢层按该角色最近几局战绩，在开局定下本局压力（±15%，不足三局不介入）；
  快层在局内做 ±8% 的短时微调（开局 45 秒与 Boss 战期间不介入）。
  两层都只作用在**普通敌人的血量**上（威胁在场上停留多久）；刷怪速率、出生距离、
  敌人伤害、掉落与 Boss 一律不变，当前系数在 HUD 与结算界面明示。
- 存档位于 Godot 的 `user://starfall_save.json`，其中 `run_history` 记录最近 40 局的战绩流水
  （角色、模式、生存时长、逐章受伤/末血/场均敌人/断链占比、Boss 击杀耗时）。它不提供任何
  属性加成，只作为后续「难度心流」调节的输入。

## 角色

- 游侠：供能弹更强更快；开局拥有弧牙。
- 骑士：高生命、高护甲；受击会为防御宠物补充能量。
- 星术师：每枚供能弹携带更多能量。
- 守卫：站稳后提高供能强度，开局拥有轨道卫星。
- 影舞者：高速移动时加快供能，拥有较高暴击并开局携带刃舞。
- 星火使：连续供能积累热量，逐步提高供能强度与范围。

除游侠外的角色通过对应成就解锁，具体条件可在游戏内成就墙查看。

## 项目结构

- `scenes/main.tscn`：主场景
- `scripts/main.gd`：界面、游戏状态、波次、卡组、商店、Boss 与数值结算
- `scripts/player.gd`：角色移动、生命、递减护甲和受击逻辑
- `scripts/enemy.gd`：敌人 AI、Boss 行为、词缀与元素状态
- `scripts/skill_entity.gd`：宠物实体、跟随运动与表现
- `scripts/save_manager.gd`：JSON 存档、成就、角色和故事解锁
- `work/*_smoke.gd`：无窗口回归测试（含数值审计与无尽模式门禁）
- `work/balance_sim.gd`：无窗口战斗模拟与平衡跑分；`-- 游侠 1 selftest` 是确定性门禁
- `work/history_fixtures.gd`：合成战绩画像（empty/weak/median/strong），供仿真声明「跑在哪种玩家身上」
- `scripts/difficulty_director.gd`：跨局难度心流（慢层）的判定，纯静态函数
- `work/balance_sim.gd`：无窗口战斗模拟，按固定步长驱动真实游戏循环并逐章输出难度压力

## 核心平衡入口

- 主线与商店节奏：`MAINLINE_BOSS_SCHEDULE`、`MAINLINE_BOSS_HEALTH`、`FIRST_SHOP_TIME`、`SHOP_INTERVAL`
- 开局配置与关卡奖励：`STARTING_PETS`、`BOSS_CLEAR_HEAL`、`BOSS_CLEAR_MAX_HEALTH`、`BOSS_CLEAR_ARMOR`
- 经济沉淀：`FORGE_BASE_PRICE`、`FORGE_STEP_PRICE`、`FORGE_ENERGY_GAIN`、`FORGE_ENERGY_CAP`
- 卡牌与稀有度：`UPGRADES`、`card_rarity`、`card_shop_price`
- 供能需求：`PET_ENERGY_REQUIREMENTS`
- 敌人基础属性：`scripts/enemy.gd` 的 `setup`
- 无尽增长：`spawn_enemy` 与 `spawn_endless_boss`

项目内置 Godot 4.4.1 控制台版本，可通过 `work/godot/Godot_v4.4.1-stable_win64_console.exe` 运行无窗口测试。
