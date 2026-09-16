extends SceneTree
# 用游戏自己的绘制代码渲染小游戏头像：星空底 + 主角 + 一只星灵。
# 跑法（要开窗口，headless 没有渲染）：
#   Godot --path . --script tools/render_avatar.gd
# 输出 outputs/avatar.png（512×512）。微信会把头像裁成圆形，主体都放在中间。
# 加 `-- share` 出分享卡片图 tools/minigame_assets/share.png（500×400，微信要求 5:4），
# 构建小游戏时会拷进主包的 images/。

const SIZE := 512
const OUT := "res://outputs/avatar.png"
const SHARE_SIZE := Vector2i(500, 400)
const SHARE_OUT := "res://tools/minigame_assets/share.png"

class Backdrop extends Node2D:
	var size := Vector2(SIZE, SIZE)
	var hero_at := Vector2(190, 300)
	var pet_at := Vector2(338, 182)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("050b1d"))
		# 中心往外的一圈圈柔光，比纯色底更像「星渊」。
		for i in 14:
			var r := 250.0 - i * 16.0
			draw_circle(size * 0.5, r, Color(0.10, 0.22, 0.45, 0.045))
		var grid := Color(0.13, 0.25, 0.42, 0.20)
		for x in range(0, int(size.x) + 1, 64):
			draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0)
		for y in range(0, int(size.y) + 1, 64):
			draw_line(Vector2(0, y), Vector2(size.x, y), grid, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260916
		for i in 70:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(0.8, 2.4), Color(0.6, 0.85, 1.0, rng.randf_range(0.25, 0.8)))
		# 主角和星灵之间的能量绳。
		draw_line(hero_at, pet_at, Color("facc15", 0.35), 10.0, true)
		draw_line(hero_at, pet_at, Color("fde68a", 0.85), 3.0, true)

var frames := 0

var share := false

func _initialize() -> void:
	share = "share" in OS.get_cmdline_user_args()
	var canvas := SHARE_SIZE if share else Vector2i(SIZE, SIZE)
	DisplayServer.window_set_size(canvas)
	root.size = canvas
	# 工程按 1280×720 做 canvas_items 拉伸，不关掉的话整张图会被缩到左上角一小块。
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var backdrop := Backdrop.new()
	backdrop.size = Vector2(canvas)
	# 分享卡片左边留给标题，角色往右挪。
	if share:
		backdrop.hero_at = Vector2(300, 300)
		backdrop.pet_at = Vector2(405, 205)
	root.add_child(backdrop)

	var hero := Player.new()
	hero.setup("游侠")
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero.position = backdrop.hero_at
	hero.scale = Vector2(2.7, 2.7) if share else Vector2(4.0, 4.0)
	root.add_child(hero)

	var pet = load("res://tools/avatar_pet.gd").new()
	pet.skill_id = "orbit"
	pet.process_mode = Node.PROCESS_MODE_DISABLED
	pet.position = backdrop.pet_at
	pet.scale = Vector2(2.1, 2.1) if share else Vector2(3.3, 3.3)
	root.add_child(pet)

	if share:
		var title := Label.new()
		title.text = "星渊幸存者"
		title.position = Vector2(34, 44)
		title.add_theme_font_size_override("font_size", 60)
		title.add_theme_color_override("font_color", Color("e8f5ff"))
		root.add_child(title)
		var tagline := Label.new()
		tagline.text = "和星灵伙伴一起
修好天穹大灯塔"
		tagline.position = Vector2(38, 130)
		tagline.add_theme_font_size_override("font_size", 24)
		tagline.add_theme_constant_override("line_spacing", -6)
		tagline.add_theme_color_override("font_color", Color("facc15"))
		root.add_child(tagline)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 6:
		return false
	var image := root.get_texture().get_image()
	var out := SHARE_OUT if share else OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	image.save_png(out)
	print("saved ", ProjectSettings.globalize_path(out), " ", image.get_size())
	return true
