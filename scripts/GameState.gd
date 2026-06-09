extends Node
class_name GameState

# 진행 상태
var stage: int = 1
var upgrades_taken: int = 0
var stage_upgrade_limit: int = 3

# 강화 상태
var active_key_count: int = 1   # 1~4
var subdiv: int = 1             # 1,2,3,6
var phase: int = 1              # upgrades_taken+1

# 점수/HP
var total_score: int = 0
var stage_score: int = 0
var combo: int = 0
var max_combo: int = 0
var miss_round: int = 0

# 플로우
var pending_stage_clear: bool = false  # 마지막 강화 끝난 뒤 FINAL ROUND 1번 더

# ✅ 게임 시작용 리셋(콤보 포함)
func reset_for_new_game() -> void:
	stage = 1
	upgrades_taken = 0
	stage_upgrade_limit = 3
	active_key_count = 1
	subdiv = 1
	phase = 1

	total_score = 0
	stage_score = 0
	combo = 0
	max_combo = 0
	miss_round = 0
	pending_stage_clear = false

func start_stage(new_stage: int, stage_upgrades: Array[int], stage_final: int) -> void:
	stage = clamp(new_stage, 1, stage_final)
	stage_upgrade_limit = stage_upgrades[stage - 1]

	upgrades_taken = 0
	active_key_count = 1
	subdiv = 1
	phase = 1

	pending_stage_clear = false

	# ✅ 스테이지 시작 상태 초기화(스테이지 점수/HP만)
	stage_score = 0
	miss_round = 0
	# ❌ combo = 0  (삭제)
	# ❌ max_combo = 0 (삭제)

func on_hit(add_score: int) -> void:
	combo += 1
	if combo > max_combo:
		max_combo = combo

	var mult: int = 1
	if combo >= 20:
		mult = 2

	stage_score += add_score * mult

func on_miss(hp_max: int) -> bool:
	miss_round += 1
	combo = 0
	return miss_round >= hp_max

func heal_on_upgrade_open() -> void:
	miss_round = 0

func close_upgrade_and_advance(stage_upgrade_limit_in: int) -> void:
	upgrades_taken += 1
	phase = upgrades_taken + 1
	if upgrades_taken >= stage_upgrade_limit_in:
		pending_stage_clear = true

func can_open_upgrade(stage_upgrade_limit_in: int) -> bool:
	return upgrades_taken < stage_upgrade_limit_in

func finish_stage() -> void:
	total_score += stage_score
