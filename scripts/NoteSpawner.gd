extends Node
class_name NoteSpawner

signal spawn_requested(seq_id: int)
signal round_time_over()

var base_tick: int = 0
var note_seq: int = 0
var running: bool = false

func reset_round() -> void:
	base_tick = 0
	note_seq = 0

func start() -> void:
	running = true

func stop() -> void:
	running = false

func on_tick(base_subdiv: int, base_ticks_per_round: int, subdiv: int) -> void:
	if not running:
		return

	base_tick += 1

	# ✅ float로 나눠서 경고 제거
	var spawn_step: int = int(float(base_subdiv) / float(subdiv))
	if spawn_step < 1:
		spawn_step = 1

	if (base_tick % spawn_step) == 0:
		note_seq += 1
		spawn_requested.emit(note_seq)

	if base_tick >= base_ticks_per_round:
		running = false
		round_time_over.emit()
