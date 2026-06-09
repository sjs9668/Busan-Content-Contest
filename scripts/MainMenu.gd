extends CanvasLayer

@export var target_bus_name: String = "Master"
@export var default_volume_linear: float = 0.8

# ✅ START 누르면 넘어갈 씬
@export var game_scene_path: String = "res://Main.tscn"

@onready var btn_start: Button = $Control/Panel/Center/MenuBox/VBox/BtnStart
@onready var sld_volume: HSlider = $Control/Panel/Center/MenuBox/VBox/RowVolume/SldVolume

var bus_idx: int = -1

func _ready() -> void:
	bus_idx = AudioServer.get_bus_index(target_bus_name)
	if bus_idx == -1:
		bus_idx = 0

	sld_volume.value = default_volume_linear
	_apply_volume(default_volume_linear)

	btn_start.pressed.connect(_on_start_pressed)
	sld_volume.value_changed.connect(func(v: float):
		_apply_volume(v)
	)

func _on_start_pressed() -> void:
	ScoreResult.reset()  # ✅ 게임 시작마다 점수 초기화
	get_tree().change_scene_to_file(game_scene_path)

func _apply_volume(v_linear: float) -> void:
	var db := linear_to_db(max(v_linear, 0.0001))
	AudioServer.set_bus_volume_db(bus_idx, db)
