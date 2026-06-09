extends Node
class_name ProgressTracker

var target_total: int = 1
var value: int = 0
var pending: Dictionary = {}  # instance_id -> true
var bar: Range = null

func bind_bar(b: Range) -> void:
	bar = b
	_refresh_ui()

func reset_for_round(new_target_total: int) -> void:
	target_total = max(1, new_target_total)
	value = 0
	pending.clear()
	_refresh_ui()

func register_note(note: Node) -> void:
	if note == null:
		return
	var id := note.get_instance_id()
	if pending.has(id):
		return
	pending[id] = true
	note.tree_exited.connect(_on_note_tree_exited.bind(id))

func _on_note_tree_exited(id: int) -> void:
	if pending.has(id):
		pending.erase(id)
		value += 1
		_refresh_ui()

func _refresh_ui() -> void:
	if bar == null:
		return
	bar.min_value = 0.0
	bar.max_value = float(target_total)
	bar.value = float(value)
