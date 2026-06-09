# ===========================
# main.gd  (Node2D)
# ===========================
extends Node2D

# ✅ 라운드 규칙: 항상 16박자(시간) 고정
const BEATS_PER_ROUND: int = 16
const BASE_SUBDIV: int = 12
const BASE_TICKS_PER_ROUND: int = BEATS_PER_ROUND * BASE_SUBDIV  # 192

# ✅ 스테이지 규칙
const STAGE_FINAL: int = 3
const STAGE_UPGRADES: Array[int] = [3, 4, 5]
const HP_MAX: int = 4

@export var seconds_per_beat: float = 1.0
@export var base_travel_time: float = 1.1

# ✅ 키 추가 순서 고정(↓→←↑). 스폰은 랜덤(허용된 개수 내)
var key_pool: Array[String] = ["D", "R", "L", "U"]

# 판정 거리
var perfect_dist: float = 12.0
var great_dist: float = 24.0
var good_dist: float = 40.0

var hit_y: float = 0.0
var judge_y: float = 0.0

var is_game_over: bool = false
var is_stage_clear: bool = false
var is_choosing_upgrade: bool = false
var round_waiting_clear: bool = false

@onready var beat_timer: Timer = $BeatTimer
@onready var notes_parent: Node2D = $Lane/Notes
@onready var hit_line: ColorRect = $Lane/HitLine
@onready var hit_area: Area2D = $Lane/HitArea

@onready var char_anim: AnimatedSprite2D = $CharAnim
@onready var ui_score: Label = $UI/ScoreLabel
@onready var ui_combo: Label = $UI/ComboLabel
@onready var ui_judge: Label = $UI/JudgeLabel
@onready var beat_bar: Range = $UI/BeatBar

@onready var upgrade_panel: Control = $UI/UpgradeOverlay/Panel
@onready var upgrade_title: Label = $UI/UpgradeOverlay/Panel/Center/RootVBox/Title
@onready var remain_label: Label = $UI/UpgradeOverlay/Panel/Center/RootVBox/RemainLabel
@onready var card_key: Button = $UI/UpgradeOverlay/Panel/Center/RootVBox/Cards/Card_Key
@onready var card_split: Button = $UI/UpgradeOverlay/Panel/Center/RootVBox/Cards/Card_Split

@onready var hp_bar: Range = $UI/HPBar
@onready var hp_text: Label = $UI/HPBar/HPText

@onready var bgm_player: AudioStreamPlayer = get_node_or_null("BGMPlayer") as AudioStreamPlayer
@onready var sfx_player: AudioStreamPlayer = get_node_or_null("SFXPlayer") as AudioStreamPlayer
@onready var background_sprite: Sprite2D = get_node_or_null("Background") as Sprite2D

var note_scene: PackedScene = preload("res://Note.tscn")
var bgm_stream: AudioStream = preload("res://audio/bgm.mp3")

var key_left_stream: AudioStream
var key_right_stream: AudioStream
var key_up_stream: AudioStream
var key_down_stream: AudioStream

# Backgrounds loaded from res://assets/backgrounds/ (optional)
var backgrounds: Array = [] # array of {name, path, tex}

# 분리 컴포넌트들
var state: GameState
var spawner: NoteSpawner
var judge: JudgeSystem
var ui: UIController
var progress: ProgressTracker

func _ready() -> void:
	randomize()

	# 배경 로드(assets/backgrounds 폴더에 이미지들을 넣어주세요)
	_load_backgrounds()

	# 뷰포트 리사이즈 시 배경 재조정
	if get_viewport() != null:
		get_viewport().connect("size_changed", Callable(self, "_on_viewport_resized"))

	hit_y = hit_line.position.y
	judge_y = _get_hit_area_center_y()

	# --- 생성/바인딩 ---
	state = GameState.new()
	add_child(state)

	spawner = NoteSpawner.new()
	add_child(spawner)

	judge = JudgeSystem.new()
	add_child(judge)

	ui = UIController.new()
	add_child(ui)

	progress = ProgressTracker.new()
	add_child(progress)

	ui.bind_nodes(
		ui_score, ui_combo, ui_judge, beat_bar,
		hp_bar, hp_text,
		upgrade_panel, upgrade_title, remain_label, card_key, card_split
	)
	progress.bind_bar(beat_bar)

	# --- 시그널 연결 ---
	beat_timer.timeout.connect(_on_tick_1_6)

	spawner.spawn_requested.connect(_on_spawn_requested)
	spawner.round_time_over.connect(_on_round_time_over)

	hit_area.area_entered.connect(func(a): judge.on_hit_area_entered(a))
	hit_area.area_exited.connect(func(a): judge.on_hit_area_exited(a, is_choosing_upgrade))

	judge.hit_scored.connect(_on_judge_hit_scored)
	judge.missed.connect(_on_judge_missed)
	judge.note_should_fade.connect(_on_note_should_fade)

	ui.upgrade_key_pressed.connect(_choose_key_add)
	ui.upgrade_split_pressed.connect(_choose_split)

	judge.configure(judge_y, perfect_dist, great_dist, good_dist, HP_MAX)

	if bgm_player != null:
		bgm_player.stream = bgm_stream
		bgm_player.volume_db = -14.0
		if not bgm_player.playing:
			bgm_player.play()

	if sfx_player != null:
		sfx_player.volume_db = -2.0

	key_left_stream = load("res://audio/key_left.mp3") as AudioStream
	key_right_stream = load("res://audio/key_right.mp3") as AudioStream
	key_up_stream = load("res://audio/key_up.mp3") as AudioStream
	key_down_stream = load("res://audio/key_down.mp3") as AudioStream

	# 시작
	_start_stage(1)
	_start_next_round()

	ui.update_score(state.stage_score, state.total_score)
	ui.update_combo(state.combo)
	_update_hp_ui()

func _process(_delta: float) -> void:
	if bgm_player != null and bgm_player.stream != null and not bgm_player.playing:
		bgm_player.play()

	ui.tick_hide_judge()

	if is_game_over or is_stage_clear:
		return

	if round_waiting_clear:
		if notes_parent.get_child_count() == 0 and judge.is_zone_empty():
			round_waiting_clear = false

			# FINAL ROUND까지 끝났으면 스테이지 종료/다음
			if state.pending_stage_clear:
				_finish_stage_and_go_next()
				return

			# 아직 강화 남아있으면 업그레이드 오픈
			if state.can_open_upgrade(state.stage_upgrade_limit):
				_open_upgrade()
				return

			_start_next_round()
		return

func _on_tick_1_6() -> void:
	if is_game_over or is_stage_clear:
		return
	if is_choosing_upgrade:
		return
	if round_waiting_clear:
		return

	spawner.on_tick(BASE_SUBDIV, BASE_TICKS_PER_ROUND, state.subdiv)

func _on_spawn_requested(seq_id: int) -> void:
	_spawn_note(seq_id)

func _on_round_time_over() -> void:
	round_waiting_clear = true

func _spawn_note(seq_id: int) -> void:
	var note_node: Node = note_scene.instantiate()
	var note: Note = note_node as Note
	if note == null:
		return

	notes_parent.add_child(note)

	var spawn_y: float = -60.0
	note.position = Vector2(0.0, spawn_y)

	var key: String = key_pool[randi() % state.active_key_count]
	note.setup(key, seq_id)

	var dist: float = hit_y - spawn_y
	note.speed = dist / base_travel_time

	progress.register_note(note)

func _on_note_should_fade(note: Note) -> void:
	if note != null:
		note.fade_fast(0.08, 0.18, 0.16)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_end"):
		_debug_go_ending()
		return
	if is_game_over or is_stage_clear:
		return
	if is_choosing_upgrade:
		return

	var pressed: String = ""
	if event.is_action_pressed("hit_q"):
		pressed = "L"
		if char_anim != null:
			char_anim.play_action("left")
		if sfx_player != null:
			sfx_player.stream = key_left_stream
			sfx_player.play()
	elif event.is_action_pressed("hit_w"):
		pressed = "R"
		if char_anim != null:
			char_anim.play_action("right")
		if sfx_player != null:
			sfx_player.stream = key_right_stream
			sfx_player.play()
	elif event.is_action_pressed("hit_e"):
		pressed = "U"
		if char_anim != null:
			char_anim.play_action("up")
		if sfx_player != null:
			sfx_player.stream = key_up_stream
			sfx_player.play()
	elif event.is_action_pressed("hit_r"):
		pressed = "D"
		if char_anim != null:
			char_anim.play_action("down")
		if sfx_player != null:
			sfx_player.stream = key_down_stream
			sfx_player.play()
	else:
		return

	judge.try_hit(pressed, state.phase)

func _on_judge_hit_scored(add_score: int, label: String) -> void:
	state.on_hit(add_score)

	ui.show_judge(label, 0.6)
	ui.update_score(state.stage_score, state.total_score)
	ui.update_combo(state.combo)

func _on_judge_missed() -> void:
	var over := state.on_miss(HP_MAX)
	_update_hp_ui()
	ui.hp_punch()

	ui.show_judge("MISS", 0.6)
	ui.update_score(state.stage_score, state.total_score)
	ui.update_combo(state.combo)

	if over:
		_on_game_over()

func _on_game_over() -> void:
	is_game_over = true
	beat_timer.stop()
	spawner.stop()

	# ✅ pause는 main에서만 관리: 게임오버면 무조건 해제
	is_choosing_upgrade = false
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = false

	ui.close_upgrade()
	ui.show_judge("GAME OVER", 9999.0)

	# 게임오버 화면으로 전환 (2초 지연)
	ScoreResult.record_game_over(state.stage, state.stage_score)
	call_deferred("_deferred_show_game_over")

func _deferred_show_game_over() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(2.0).timeout
	tree.change_scene_to_file("res://GameOver.tscn")

func _open_upgrade() -> void:
	# 업그레이드 열릴 때 HP 회복
	state.heal_on_upgrade_open()
	judge.heal_full()
	_update_hp_ui()

	is_choosing_upgrade = true

	# ✅ pause는 main에서만
	get_tree().paused = true

	var disable_key := state.active_key_count >= 4
	var disable_split := state.subdiv >= 4
	ui.open_upgrade(state.upgrades_taken, state.stage_upgrade_limit, disable_key, disable_split)

func _close_upgrade() -> void:
	# ✅ pause는 main에서만
	get_tree().paused = false

	ui.close_upgrade()
	is_choosing_upgrade = false

	state.close_upgrade_and_advance(state.stage_upgrade_limit)

	if state.pending_stage_clear:
		ui.show_judge("FINAL ROUND", 0.8)

	_start_next_round()

func _choose_key_add() -> void:
	if state.active_key_count < 4:
		state.active_key_count += 1
	_close_upgrade()

func _choose_split() -> void:
	if state.subdiv == 1:
		state.subdiv = 2
	elif state.subdiv == 2:
		state.subdiv = 3
	elif state.subdiv == 3:
		state.subdiv = 4
	_close_upgrade()

func _start_stage(new_stage: int) -> void:
	state.start_stage(new_stage, STAGE_UPGRADES, STAGE_FINAL)

	is_game_over = false
	is_stage_clear = false
	is_choosing_upgrade = false
	round_waiting_clear = false

	# ✅ 혹시 이전 상태에서 pause가 남아있으면 방지
	get_tree().paused = false

	ui.show_judge("STAGE %d" % state.stage, 0.8)
	ui.update_score(state.stage_score, state.total_score)
	ui.update_combo(state.combo)
	_update_hp_ui()

	# 스테이지 시작 시 배경 설정
	_set_background_for_stage(state.stage)


func _start_next_round() -> void:
	round_waiting_clear = false
	judge.reset_for_round()

	# 라운드 목표치 고정(16박 * subdiv)
	progress.reset_for_round(BEATS_PER_ROUND * state.subdiv)

	spawner.reset_round()
	spawner.start()

	beat_timer.stop()
	beat_timer.wait_time = seconds_per_beat / float(BASE_SUBDIV)
	beat_timer.start()

func _finish_stage_and_go_next() -> void:
	# ✅ 지금 스테이지 정산
	state.finish_stage()

	# ✅ 스테이지 점수 저장(싱글톤 ScoreResult)
	ScoreResult.add_stage_score(state.stage, state.stage_score)

	# ✅ 마지막 스테이지면 엔딩
	if state.stage >= STAGE_FINAL:
		beat_timer.stop()
		spawner.stop()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://EndingScreen.tscn")
		return

	# ✅ 다음 스테이지로 넘어가기 전: 5초 텀
	is_choosing_upgrade = true        # 입력 막기
	get_tree().paused = false         # pause 풀어야 타이머가 정상 동작
	beat_timer.stop()
	spawner.stop()

	ui.close_upgrade()
	ui.show_judge("STAGE %d START IN 5..." % (state.stage + 1), 5.0)

	await get_tree().create_timer(5.0).timeout

	is_choosing_upgrade = false
	_start_stage(state.stage + 1)
	_start_next_round()

func _update_hp_ui() -> void:
	var hp := HP_MAX - state.miss_round
	if hp < 0:
		hp = 0
	ui.update_hp(hp, HP_MAX)

func _get_hit_area_center_y() -> float:
	var cs: CollisionShape2D = hit_area.get_node("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return notes_parent.to_local(hit_area.global_position).y

	var rect := cs.shape as RectangleShape2D
	if rect == null:
		return notes_parent.to_local(hit_area.global_position).y

	var center_local_in_area: Vector2 = cs.position
	var center_global: Vector2 = hit_area.to_global(center_local_in_area)
	var center_in_notes: Vector2 = notes_parent.to_local(center_global)
	return center_in_notes.y

func _debug_go_ending() -> void:
	# 진행 중인 것들 정리
	is_game_over = true
	is_choosing_upgrade = false
	round_waiting_clear = false

	beat_timer.stop()
	spawner.stop()
	get_tree().paused = false
	ui.close_upgrade()

	# ✅ 지금 스테이지 점수까지도 기록하고 싶으면(선택)
	# 이미 기록된 스테이지는 덮어써도 되고, 그냥 강제로 넣어도 됨
	ScoreResult.add_stage_score(state.stage, state.stage_score)

	get_tree().change_scene_to_file("res://EndingScreen.tscn")


### Background helpers
func _load_backgrounds() -> void:
	backgrounds.clear()
	var dir := DirAccess.open("res://assets/backgrounds")
	if dir == null:
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			fname = dir.get_next()
			continue

		var ext := fname.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp", "avif"]:
			var p := "res://assets/backgrounds/" + fname
			var tex := load(p) as Texture2D
			if tex != null:
				backgrounds.append({"name": fname, "path": p, "tex": tex})

		fname = dir.get_next()
	dir.list_dir_end()

func _set_background_for_stage(stage: int) -> void:
	if background_sprite == null:
		return
	if backgrounds.is_empty():
		background_sprite.texture = null
		return

	var tex: Texture2D = null
	# Final stage: prefer a file with 'final' in its name, else pick last one
	if stage >= STAGE_FINAL:
		for b in backgrounds:
			if b.name.to_lower().find("final") >= 0:
				tex = b.tex
				break
		if tex == null:
			tex = backgrounds[ backgrounds.size() - 1 ].tex
	else:
		var non_final_backgrounds := []
		for b in backgrounds:
			if b.name.to_lower().find("final") < 0:
				non_final_backgrounds.append(b)
		if non_final_backgrounds.is_empty():
			non_final_backgrounds = backgrounds
		tex = non_final_backgrounds[ randi() % non_final_backgrounds.size() ].tex

	background_sprite.texture = tex
	_fit_background()

func _on_viewport_resized() -> void:
	_fit_background()

func _fit_background() -> void:
	if background_sprite == null:
		return
	var tex := background_sprite.texture
	if tex == null:
		return

	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return

	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size.x <= 0 or view_size.y <= 0:
		return

	var sx: float = view_size.x / tex_size.x
	var sy: float = view_size.y / tex_size.y
	var s: float = max(sx, sy) # cover

	background_sprite.scale = Vector2(s, s)

	# 가운데 정렬: tex*scale 크기에서 중앙으로 오프셋
	var real_size := tex_size * s
	var offset := (view_size - real_size) * 0.5
	background_sprite.position = offset
