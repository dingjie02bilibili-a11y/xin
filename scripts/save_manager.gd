extends Node

const SAVE_PATH := "user://starfall_save.json"
const DEFAULT_DATA := {
	"selected_character": "游侠",
	"settings": {"sound": true, "screenshake": true},
	"achievements": [],
	"story_read": [],
	"intro_seen": false
}
const CHARACTERS := ["游侠", "骑士", "星术师", "守卫", "影舞者", "星火使"]

var data: Dictionary = {}
var suppress_writes := false

func _ready() -> void:
	# Headless smoke scripts exercise real persistence code against an in-memory
	# save, but must never touch the player's existing file.
	for argument in OS.get_cmdline_args():
		var value := str(argument).replace("\\", "/")
		if value.contains("work/") and value.ends_with(".gd"):
			suppress_writes = true
			break
	load_data()

func load_data() -> void:
	data = DEFAULT_DATA.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)
	if not str(data.selected_character) in CHARACTERS:
		data.selected_character = "游侠"
	if not data.achievements is Array:
		data.achievements = []
	if not data.story_read is Array:
		data.story_read = []
	if "slot_nine" in data.achievements:
		data.achievements.erase("slot_nine")
		if not "slot_seven" in data.achievements:
			data.achievements.append("slot_seven")
	# 旧版本已经进入过无尽，必然完成过这些现版本成就条件。
	if "endless_walker" in data.achievements:
		for implied_id in ["survive_minute", "survive_three", "survive_six", "boss_breaker", "boss_trio", "six_seals"]:
			if not implied_id in data.achievements:
				data.achievements.append(implied_id)
	# 旧版本已完成六关的存档，应直接补发新增的第四、第五封印锚记。
	if "six_seals" in data.achievements:
		for implied_id in ["fourth_seal", "fifth_seal"]:
			if not implied_id in data.achievements:
				data.achievements.append(implied_id)
	if "relic_master" in data.achievements:
		for relic_id in ["predator_boots", "rift_compass", "judge_spark", "ember_vessel", "aegis_fragment", "storm_relay"]:
			var implied_id: String = "relic_" + str(relic_id)
			if not implied_id in data.achievements:
				data.achievements.append(implied_id)
	save()

func _merge(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if not target.has(key):
			continue
		if target[key] is Dictionary and source[key] is Dictionary:
			_merge(target[key], source[key])
		else:
			target[key] = source[key]

func save() -> void:
	if suppress_writes:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func finish_run(_seconds: float, _kills: int, _boss_kills: int) -> void:
	save()

func reset_all() -> void:
	data = DEFAULT_DATA.duplicate(true)
	save()

func add_achievement(id: String) -> bool:
	if id in data.achievements:
		return false
	data.achievements.append(id)
	save()
	return true

func mark_story_read(id: String) -> void:
	if id in data.story_read:
		return
	data.story_read.append(id)
	save()
