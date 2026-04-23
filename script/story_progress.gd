extends Node

signal progress_changed

const SAVE_PATH := "user://story_progress.cfg"
const REQUIRED_WINS_PER_CHAPTER := 3
const MAX_CHAPTERS := 5

var highest_visible_chapter: int = 1
var mission_progress: int = 0

func _ready() -> void:
	_load_state()

func get_visible_chapter_limit() -> int:
	return highest_visible_chapter

func is_chapter_visible(chapter_number: int) -> bool:
	return chapter_number <= highest_visible_chapter

func is_chapter_unlocked(chapter_number: int) -> bool:
	if chapter_number <= 1:
		return true
	if chapter_number < highest_visible_chapter:
		return true
	if chapter_number == highest_visible_chapter:
		return mission_progress >= REQUIRED_WINS_PER_CHAPTER
	return false

func is_chapter_locked(chapter_number: int) -> bool:
	return is_chapter_visible(chapter_number) and not is_chapter_unlocked(chapter_number)

func get_chapter_progress_text(chapter_number: int) -> String:
	if chapter_number <= 1:
		return ""
	if not is_chapter_visible(chapter_number):
		return "Hey, you’re skipping ahead. Finish the last chapter first."
	if is_chapter_unlocked(chapter_number):
		return ""
	return "We’re not done yet. Complete 3 missions! (%d/%d)" % [mission_progress, REQUIRED_WINS_PER_CHAPTER]

func get_confirm_button_text(chapter_number: int) -> String:
	if is_chapter_locked(chapter_number):
		return "LOCKED"
	return "WE BALL!"

func record_mission_win() -> void:
	if highest_visible_chapter <= 1:
		return
	if mission_progress >= REQUIRED_WINS_PER_CHAPTER:
		return
		
	mission_progress += 1
	_save_state()
	progress_changed.emit()

func mark_chapter_completed(chapter_number: int) -> void:
	if chapter_number != highest_visible_chapter:
		return
	if highest_visible_chapter >= MAX_CHAPTERS:
		return

	highest_visible_chapter += 1
	mission_progress = 0
	_save_state()
	progress_changed.emit()

func reset_progress() -> void:
	highest_visible_chapter = 1
	mission_progress = 0
	_save_state()
	progress_changed.emit()

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	highest_visible_chapter = int(config.get_value("story", "highest_visible_chapter", 1))
	mission_progress = int(config.get_value("story", "mission_progress", 0))
	highest_visible_chapter = clampi(highest_visible_chapter, 1, MAX_CHAPTERS)
	mission_progress = clampi(mission_progress, 0, REQUIRED_WINS_PER_CHAPTER)

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("story", "highest_visible_chapter", highest_visible_chapter)
	config.set_value("story", "mission_progress", mission_progress)
	config.save(SAVE_PATH)
