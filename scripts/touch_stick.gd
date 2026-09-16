class_name TouchStick
extends Control
# 手机上的虚拟摇杆。手指按在屏幕任意空白处，摇杆就出现在按下的那一点，
# 拖多远就走多快——不用去够一个固定的圆圈，单手拿着手机也能走位。
#
# 它不碰 player.gd：走位读的是 Input.get_vector("move_left"...)，这里
# 每帧把手指方向用 Input.action_press(action, strength) 灌回同样那四个
# action，所以键盘和手指走的是同一条路，游戏那边一行都不用改。
#
# 事件走 _unhandled_input：被按钮吃掉的点击不会落到这里，所以点暂停、
# 点卡牌都不会顺手把角色甩出去。

# 拖到这个距离就是满速。720 高的屏幕上约等于拇指自然滑动的幅度。
const MAX_RADIUS := 110.0
# 手指抖动小于这个距离不算走位，免得站着不动时角色微微颤。
const DEAD_ZONE := 12.0
# Input.get_vector 的 deadzone 是 0.2，低于它注入进去等于没按，
# 所以真要走的时候强度从这里起跳，轻推也能挪。
const MIN_STRENGTH := 0.24

const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
# 鼠标按住时借用这个「手指编号」。桌面浏览器上没有触摸事件，拿鼠标也能走位，
# 本地调试摇杆就不用非得翻出一台真机。
const MOUSE_INDEX := -2

# 回指 main.gd，用来问「现在能不能走位」。
var game
var active_touch := -1
var origin := Vector2.ZERO
var current := Vector2.ZERO
var vector := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 面板弹出来时游戏树是暂停的，摇杆得照样跑，才能在那一刻把手指方向撤掉。
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 4

func _unhandled_input(event: InputEvent) -> void:
	if game != null and not game.touch_controls_active():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# 真手指优先：手机上一次触摸还会被引擎补一个模拟鼠标事件，
			# 先占住位子，那个补出来的就会被下面的分支挡掉。
			if active_touch == -1 or active_touch == MOUSE_INDEX:
				_begin(event.index, event.position)
		elif event.index == active_touch:
			_release()
	elif event is InputEventScreenDrag and event.index == active_touch:
		current = event.position
		_update_vector()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if active_touch == -1:
				_begin(MOUSE_INDEX, event.position)
		elif active_touch == MOUSE_INDEX:
			_release()
	elif event is InputEventMouseMotion and active_touch == MOUSE_INDEX:
		current = event.position
		_update_vector()

func _process(_delta: float) -> void:
	# 节点一直留在场景里而不是靠 visible 藏起来：隐藏的 Control 收不到输入，
	# 一旦藏起来就再也等不到第一次触摸，摇杆永远出不来。要不要画由 _draw 决定。
	if game != null and not game.touch_controls_active():
		stop()
		return
	if active_touch == -1:
		return
	_apply()

func _begin(index: int, at: Vector2) -> void:
	active_touch = index
	origin = at
	current = at
	_update_vector()

func _update_vector() -> void:
	var offset := current - origin
	var distance := offset.length()
	if distance <= DEAD_ZONE:
		vector = Vector2.ZERO
	else:
		var strength := clampf((distance - DEAD_ZONE) / (MAX_RADIUS - DEAD_ZONE), 0.0, 1.0)
		vector = offset.normalized() * lerpf(MIN_STRENGTH, 1.0, strength)
	_apply()
	queue_redraw()

func _apply() -> void:
	_press("move_left", maxf(-vector.x, 0.0))
	_press("move_right", maxf(vector.x, 0.0))
	_press("move_up", maxf(-vector.y, 0.0))
	_press("move_down", maxf(vector.y, 0.0))

func _press(action: String, strength: float) -> void:
	if strength <= 0.0:
		Input.action_release(action)
	else:
		Input.action_press(action, strength)

func _release() -> void:
	active_touch = -1
	vector = Vector2.ZERO
	for action in ACTIONS:
		Input.action_release(action)
	queue_redraw()

# 战斗结束、弹面板、暂停时由 main 调用：手指还按着也要停下来，
# 否则关掉面板回到战斗时角色会自己往上一次的方向跑。
func stop() -> void:
	if active_touch != -1 or vector != Vector2.ZERO:
		_release()

func _draw() -> void:
	if active_touch == -1:
		return
	var base := Color("66d9ff")
	draw_circle(origin, MAX_RADIUS, Color(base.r, base.g, base.b, 0.08))
	draw_arc(origin, MAX_RADIUS, 0.0, TAU, 48, Color(base.r, base.g, base.b, 0.30), 2.0)
	var knob := origin + (current - origin).limit_length(MAX_RADIUS)
	draw_circle(knob, 30.0, Color(base.r, base.g, base.b, 0.22))
	draw_arc(knob, 30.0, 0.0, TAU, 28, Color(base.r, base.g, base.b, 0.65), 2.5)
