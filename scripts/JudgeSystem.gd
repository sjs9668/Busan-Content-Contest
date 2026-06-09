extends Node
class_name JudgeSystem

signal hit_scored(add_score: int, label: String)
signal missed()
signal note_should_fade(note: Note)

var perfect_dist: float = 12.0
var great_dist: float = 24.0
var good_dist: float = 40.0

var judge_y: float = 0.0
var hp_max: int = 4
var notes_in_zone: Array[Note] = []

func configure(_judge_y: float, _perfect: float, _great: float, _good: float, _hp_max: int) -> void:
	judge_y = _judge_y
	perfect_dist = _perfect
	great_dist = _great
	good_dist = _good
	hp_max = _hp_max

func reset_for_round() -> void:
	notes_in_zone.clear()

func heal_full() -> void:
	# no-op: HP is tracked by GameState
	pass

func is_zone_empty() -> bool:
	return notes_in_zone.is_empty()

func on_hit_area_entered(area: Area2D) -> void:
	var note: Note = area.get_parent() as Note
	if note == null:
		return
	if not notes_in_zone.has(note):
		notes_in_zone.append(note)

func on_hit_area_exited(area: Area2D, blocked: bool) -> void:
	var note: Note = area.get_parent() as Note
	if note == null:
		return

	notes_in_zone.erase(note)

	if blocked:
		return

	note_should_fade.emit(note)

	# ✅ 이미 판정(성공)했거나, 이미 미스 확정된 노트면 추가 MISS 금지
	if note.was_judged or note.was_missed:
		return

	_do_miss()

func try_hit(pressed: String, phase: int) -> void:
	# ✅ 존이 비었는데 누르면 MISS (너 기존 룰 유지)
	if notes_in_zone.is_empty():
		return  # ✅ 노트 없으면 입력 무시 (MISS 안 줌)

	# 1) 같은 키 노트 중에서 가장 가까운 거 찾기
	var best_note: Note = null
	var best_dist: float = 1.0e20

	for note: Note in notes_in_zone:
		if note == null:
			continue
		if note.key_char != pressed:
			continue

		var d: float = abs(note.position.y - judge_y)
		if d < best_dist:
			best_dist = d
			best_note = note

	# 2) 같은 키 노트가 없으면: MISS 1번 + 노트 1개를 "미스 확정" 처리(중복 MISS 방지)
	if best_note == null:
		var nearest: Note = null
		var nearest_dist: float = 1.0e20

		for note: Note in notes_in_zone:
			if note == null:
				continue
			var d2: float = abs(note.position.y - judge_y)
			if d2 < nearest_dist:
				nearest_dist = d2
				nearest = note

		if nearest != null:
			nearest.was_missed = true
			notes_in_zone.erase(nearest)
			note_should_fade.emit(nearest) # ✅ 지나간 것처럼 잔상 처리

		_do_miss()
		return

	# 3) 같은 키 노트가 있으면: 거리로 판정
	var label: String = ""
	var add_score: int = 0
	var phase_bonus: int = 10 * (phase - 1)

	if best_dist <= perfect_dist:
		label = "PERFECT"
		add_score = 100 + phase_bonus
	elif best_dist <= great_dist:
		label = "GREAT"
		add_score = 80 + phase_bonus
	elif best_dist <= good_dist:
		label = "GOOD"
		add_score = 60 + phase_bonus
	else:
		# ✅ 타이밍이 너무 멀면: MISS 1번만 나게(노트는 "성공 판정"이 아니므로 judged 표시 X)
		best_note.was_missed = true
		notes_in_zone.erase(best_note)
		note_should_fade.emit(best_note)
		_do_miss()
		return

	# 성공 판정
	best_note.was_judged = true
	notes_in_zone.erase(best_note)
	hit_scored.emit(add_score, label)

func _do_miss() -> void:
	missed.emit()
