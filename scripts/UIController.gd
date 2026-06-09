extends Node
class_name UIController

signal upgrade_key_pressed()
signal upgrade_split_pressed()

var ui_score: Label
var ui_combo: Label
var ui_judge: Label
var beat_bar: Range

var hp_bar: Range
var hp_text: Label
var hp_bar_base_scale: Vector2 = Vector2.ONE

var upgrade_panel: Control
var upgrade_title: Label
var remain_label: Label
var card_key: Button
var card_split: Button

var judge_hide_time: float = 0.0

func bind_nodes(
	_score: Label, _combo: Label, _judge: Label, _beat_bar: Range,
	_hp_bar: Range, _hp_text: Label,
	_upgrade_panel: Control, _upgrade_title: Label, _remain: Label,
	_card_key: Button, _card_split: Button
) -> void:
	ui_score = _score
	ui_combo = _combo
	ui_judge = _judge
	beat_bar = _beat_bar

	hp_bar = _hp_bar
	hp_text = _hp_text
	hp_bar_base_scale = hp_bar.scale

	upgrade_panel = _upgrade_panel
	upgrade_title = _upgrade_title
	remain_label = _remain
	card_key = _card_key
	card_split = _card_split

	upgrade_panel.visible = false
	upgrade_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	card_key.pressed.connect(func(): upgrade_key_pressed.emit())
	card_split.pressed.connect(func(): upgrade_split_pressed.emit())

func tick_hide_judge() -> void:
	var now: float = float(Time.get_ticks_msec()) * 0.001
	if ui_judge != null and ui_judge.text != "" and now > judge_hide_time:
		ui_judge.text = ""

func show_judge(text: String, seconds: float) -> void:
	if ui_judge == null:
		return
	ui_judge.text = text
	judge_hide_time = float(Time.get_ticks_msec()) * 0.001 + seconds

func update_score(stage_score: int, total_score: int) -> void:
	if ui_score != null:
		ui_score.text = "%d (TOTAL: %d)" % [stage_score, total_score]

func update_combo(combo: int) -> void:
	if ui_combo != null:
		ui_combo.text = "%d" % combo

func update_hp(hp: int, hp_max: int) -> void:
	if hp_bar != null:
		hp_bar.show()
		hp_bar.min_value = 0
		hp_bar.max_value = hp_max
		hp_bar.value = hp
	if hp_text != null:
		hp_text.show()
		hp_text.text = "%d / %d" % [hp, hp_max]

func hp_punch() -> void:
	if hp_bar == null:
		return
	hp_bar.scale = hp_bar_base_scale
	var t := create_tween()
	t.tween_property(hp_bar, "scale", hp_bar_base_scale * Vector2(0.92, 0.85), 0.06)
	t.tween_property(hp_bar, "scale", hp_bar_base_scale * Vector2(1.06, 1.10), 0.08)
	t.tween_property(hp_bar, "scale", hp_bar_base_scale, 0.10)

func open_upgrade(upgrades_taken: int, limit: int, disable_key: bool, disable_split: bool) -> void:
	# ✅ pause는 main.gd에서만 관리
	upgrade_panel.visible = true
	if upgrade_title != null:
		upgrade_title.text = "UPGRADE AVAILABLE"
	if remain_label != null:
		remain_label.text = "강화 진행: %d / %d" % [upgrades_taken, limit]
	if card_key != null:
		card_key.disabled = disable_key
	if card_split != null:
		card_split.disabled = disable_split

func close_upgrade() -> void:
	# ✅ pause는 main.gd에서만 관리
	upgrade_panel.visible = false
