extends Control

@export var game_scene_path: String = "res://Main.tscn"

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var stage_label: Label = $CenterContainer/VBoxContainer/StageLabel
@onready var score_label: Label = $CenterContainer/VBoxContainer/ScoreLabel
@onready var score_list: VBoxContainer = $CenterContainer/VBoxContainer/ScoreList
@onready var total_label: Label = $CenterContainer/VBoxContainer/TotalLabel
@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton

func _ready() -> void:
	var stage: int = int(ScoreResult.last_stage)
	var score: int = int(ScoreResult.last_stage_score)

	title_label.text = "GAME OVER"
	stage_label.text = "FAILED AT STAGE %d" % max(stage, 1)
	score_label.text = "Failed stage score : %d" % score

	_populate_score_list(stage, score)
	total_label.text = "TOTAL : %d" % (_calculate_total(stage, score))

	retry_button.pressed.connect(_on_retry_pressed)

func _populate_score_list(failed_stage: int, failed_score: int) -> void:
	while score_list.get_child_count() > 0:
		score_list.get_child(0).queue_free()

	for i in range(1, failed_stage):
		var cleared_score: int = int(ScoreResult.stage_scores.get(i, 0))
		var label := Label.new()
		label.text = "Stage %d : %d" % [i, cleared_score]
		label.set("theme_override_font_sizes/font_size", 28)
		score_list.add_child(label)

	var failed_label := Label.new()
	failed_label.text = "Stage %d (Failed) : %d" % [failed_stage, failed_score]
	failed_label.set("theme_override_font_sizes/font_size", 28)
	failed_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	score_list.add_child(failed_label)

func _calculate_total(failed_stage: int, failed_score: int) -> int:
	var total: int = failed_score
	for i in range(1, failed_stage):
		total += int(ScoreResult.stage_scores.get(i, 0))
	return total

func _on_retry_pressed() -> void:
	ScoreResult.reset()
	get_tree().change_scene_to_file(game_scene_path)
