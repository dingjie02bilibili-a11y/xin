extends Node
# 微信小游戏平台能力的唯一出入口：埋点、分享、好友排行、游戏圈按钮、震动、
# 屏幕常亮、实时日志、激励视频广告。
#
# 桌面、编辑器、无窗口测试里 wx 不存在，这里每个方法都直接什么也不做，
# 游戏代码因此可以放心地到处调用，不必自己判断平台。
#
# 两个绕不开的限制决定了下面的写法：
#   · 小游戏平台禁用 eval，JavaScriptBridge.eval 对任何表达式都返回 null；
#     get_interface 走另一条绑定，不受影响。
#   · GDScript 的 Dictionary 传不进 JS。参数对象一律用 JSON.parse 在 JS 侧造，
#     回调再挂到造出来的对象上。

# 广告先接好、不启用：开通流量主拿到广告位 ID 之前，rewarded_ready() 恒为
# false，游戏里所有看广告的入口都不会出现。启用时只改这两行。
const ADS_ENABLED := false
const REWARDED_AD_UNIT_ID := ""

# 好友排行榜的 key，要和后台「微信排行榜配置」里填的唯一标识一致。
const RANK_KEY := "best_kills"
# 主包里的分享图，5:4。被动转发（右上角菜单）在外壳 game.js 里配，用的也是它。
const SHARE_IMAGE := "images/share.png"
# 连续受击时不要让手机一直震。
const VIBRATE_INTERVAL_MS := 120
# 游戏圈按钮的最小边长（CSS 像素）。
const CLUB_MIN_CSS := 36.0
# JS 回调必须由 GDScript 持有引用，否则被回收后 JS 再调用会崩。一次性回调
# （success / fail）只保留最近这些，早就执行完了；会被反复调用的（广告关闭、
# 按钮点击）另存一份，永不淘汰。
const CALLBACK_KEEP := 64

var wx = null
var _json = null
var _log = null
var _callbacks: Array = []
var _persistent_callbacks: Array = []
var _css_size := Vector2.ZERO
var _last_vibrate_ms := -VIBRATE_INTERVAL_MS
var _club_button = null
var _rewarded = null
var _ad_done := Callable()
var _ad_placement := ""

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	var api = JavaScriptBridge.get_interface("wx")
	var json = JavaScriptBridge.get_interface("JSON")
	if api == null or json == null:
		return
	wx = api
	_json = json
	var info = wx.getSystemInfoSync()
	if info != null:
		_css_size = Vector2(float(info.windowWidth), float(info.windowHeight))
	if wx.getRealtimeLogManager != null:
		_log = wx.getRealtimeLogManager()

func is_available() -> bool:
	return wx != null

# ---------------------------------------------------------------- 埋点

# 事件 ID 和字段要先在 We分析「数据管理 → 事件管理」里建好，否则上报会被丢弃。
# 字段值只放数字和短字符串；数组、嵌套对象 We分析 不收。
func report_event(event_id: String, data: Dictionary) -> void:
	if wx == null or wx.reportEvent == null:
		return
	wx.reportEvent(event_id, _js(data))

# ---------------------------------------------------------------- 实时日志

func log_info(message: String) -> void:
	if _log != null:
		_log.info(message)

func log_warn(message: String) -> void:
	if _log != null:
		_log.warn(message)

# ---------------------------------------------------------------- 手感

func vibrate(strength := "light") -> void:
	if wx == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_vibrate_ms < VIBRATE_INTERVAL_MS:
		return
	_last_vibrate_ms = now
	wx.vibrateShort(_js({"type": strength}))

# 幸存者类玩家常常盯着屏幕不碰，不开的话战斗打到一半手机自己锁屏。
func keep_screen_on(on: bool) -> void:
	if wx == null:
		return
	wx.setKeepScreenOn(_js({"keepScreenOn": on}))

# ---------------------------------------------------------------- 分享与排行

func share(title: String, query := "") -> void:
	if wx == null:
		return
	wx.shareAppMessage(_js({"title": title, "imageUrl": SHARE_IMAGE, "query": query}))

# 微信排行榜只认这个格式：value 是 {"wxgame": {"score": 整数, "update_time": 秒}}
# 的 JSON 字符串。托管数据是覆盖写，只在刷新最佳成绩时调用。
func submit_rank(score: int) -> void:
	if wx == null:
		return
	var value := JSON.stringify({"wxgame": {"score": score, "update_time": int(Time.get_unix_time_from_system())}})
	var request = _js({"KVDataList": [{"key": RANK_KEY, "value": value}]})
	request.fail = _callback(func(args): log_warn("setUserCloudStorage fail: %s" % _describe(args)))
	wx.setUserCloudStorage(request)

# ---------------------------------------------------------------- 游戏圈

# 游戏圈按钮是盖在画布上的原生按钮，坐标是 CSS 像素。传进来的矩形是 viewport
# 坐标（已经算上 UI 层的安全区内缩），这里再换算一次。
func show_game_club(viewport_rect: Rect2) -> void:
	if wx == null or _css_size == Vector2.ZERO:
		return
	var css := viewport_to_css(viewport_rect)
	# 设计坐标按 1280 宽画，竖屏手机上 52 像素的格子换算下来只剩十几个 CSS
	# 像素，按钮小到点不中。保住一个手指能按的最小尺寸，以格子中心为准放大。
	if css.size.x < CLUB_MIN_CSS or css.size.y < CLUB_MIN_CSS:
		var center := css.get_center()
		var side := maxf(CLUB_MIN_CSS, maxf(css.size.x, css.size.y))
		css = Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	if _club_button != null:
		_club_button.destroy()
		_club_button = null
	_club_button = wx.createGameClubButton(_js({
		"type": "image",
		"icon": "light",
		"style": {"left": css.position.x, "top": css.position.y, "width": css.size.x, "height": css.size.y, "backgroundColor": "#00000000"}
	}))
	if _club_button != null:
		_club_button.onTap(_callback(func(_args): report_event("game_club_tap", {"from": "menu"}), true))

func hide_game_club() -> void:
	if _club_button != null:
		_club_button.destroy()
		_club_button = null

func viewport_to_css(rect: Rect2) -> Rect2:
	var viewport := get_viewport().get_visible_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0 or _css_size == Vector2.ZERO:
		return rect
	var ratio := _css_size / viewport
	return Rect2(rect.position * ratio, rect.size * ratio)

# ---------------------------------------------------------------- 激励视频广告

func rewarded_ready() -> bool:
	return ADS_ENABLED and not REWARDED_AD_UNIT_ID.is_empty() and wx != null

# on_done(watched: bool)。只有看完才算 true；拉不到广告、中途关掉都是 false，
# 调用方按「没看」处理，不会把玩家卡住。
func show_rewarded(placement: String, on_done: Callable) -> void:
	if not rewarded_ready():
		on_done.call(false)
		return
	if _rewarded == null:
		_rewarded = wx.createRewardedVideoAd(_js({"adUnitId": REWARDED_AD_UNIT_ID}))
		_rewarded.onClose(_callback(_on_rewarded_close, true))
		_rewarded.onError(_callback(_on_rewarded_error, true))
	_ad_done = on_done
	_ad_placement = placement
	report_event("ad_rewarded", {"placement": placement, "result": "request"})
	# 第一次 show 常因为还没加载完而失败，失败就先 load 再 show 一次。
	var shown = _rewarded.show()
	if shown != null:
		shown.catch(_callback(func(_args):
			var loaded = _rewarded.load()
			if loaded != null:
				loaded.then(_callback(func(_a): _rewarded.show()))
		))

func _on_rewarded_close(args: Array) -> void:
	var res = args[0] if not args.is_empty() else null
	var watched := res == null or bool(res.isEnded)
	report_event("ad_rewarded", {"placement": _ad_placement, "result": "watched" if watched else "closed"})
	_finish_ad(watched)

func _on_rewarded_error(args: Array) -> void:
	log_warn("rewarded ad error: %s" % _describe(args))
	report_event("ad_rewarded", {"placement": _ad_placement, "result": "error"})
	_finish_ad(false)

func _finish_ad(watched: bool) -> void:
	if not _ad_done.is_valid():
		return
	var done := _ad_done
	_ad_done = Callable()
	done.call(watched)

# ---------------------------------------------------------------- 内部

func _js(data: Dictionary):
	return _json.parse(JSON.stringify(data))

func _callback(fn: Callable, persistent := false):
	var cb = JavaScriptBridge.create_callback(fn)
	if persistent:
		_persistent_callbacks.append(cb)
		return cb
	_callbacks.append(cb)
	if _callbacks.size() > CALLBACK_KEEP:
		_callbacks.pop_front()
	return cb

func _describe(args: Array) -> String:
	if args.is_empty() or args[0] == null:
		return "?"
	var first = args[0]
	if first is JavaScriptObject and first.errMsg != null:
		return str(first.errMsg)
	return str(first)
