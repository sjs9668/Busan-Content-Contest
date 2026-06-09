class_name Note
extends Node2D

@export var speed: float = 300.0

var key_char: String = "L"
var beat_index: int = 0

var was_judged: bool = false
var was_missed: bool = false      # ✅ 추가: 한 노트당 MISS 1회 보장용
var is_fading: bool = false

@onready var body: ColorRect = $Body
@onready var key_label: Label = $KeyLabel

# ✅ 노트 씬 안 Area2D 이름이 HitBox
@onready var area2d: Area2D = get_node_or_null("HitBox") as Area2D

func setup(c: String, beat_idx: int) -> void:
	key_char = c
	beat_index = beat_idx

	match c:
		"L": key_label.text = "←"
		"R": key_label.text = "→"
		"U": key_label.text = "↑"
		"D": key_label.text = "↓"
		_:   key_label.text = c

	match c:
		"L": body.color = Color(1.0, 0.2, 0.2)
		"R": body.color = Color(0.2, 1.0, 0.2)
		"U": body.color = Color(0.2, 0.4, 1.0)
		"D": body.color = Color(1.0, 1.0, 0.2)
		_:   body.color = Color.WHITE

	was_judged = false
	was_missed = false   # ✅ 추가 초기화
	is_fading = false
	body.modulate = Color(1, 1, 1, 1)
	key_label.modulate = Color(1, 1, 1, 1)

# ✅ 판정선 지나갈 때:
# 1) 빠르게 잔상 알파로 내림
# 2) 일정 시간 뒤 완전 삭제
func fade_fast(fade_time: float = 0.08, target_alpha: float = 0.18, free_delay: float = 0.35) -> void:
	if is_fading:
		return
	is_fading = true

	# ✅ in/out 시그널 중 즉시 변경 금지 → deferred로 끔
	if area2d != null:
		area2d.set_deferred("monitoring", false)
		area2d.set_deferred("monitorable", false)

	var t := create_tween()

	# 1) 잔상까지 빠르게 흐려짐 (0까지는 안 내려서 "완전 사라짐 느낌" 방지)
	t.tween_property(body, "modulate:a", target_alpha, fade_time)
	t.parallel().tween_property(key_label, "modulate:a", target_alpha, fade_time)

	# 2) 잔상 유지 시간
	t.tween_interval(free_delay)

	# 3) 삭제
	t.tween_callback(queue_free)

func _process(delta: float) -> void:
	position.y += speed * delta

	# 안전장치(혹시 fade를 안 타는 노트가 있으면)
	if position.y > 1400.0:
		queue_free()
