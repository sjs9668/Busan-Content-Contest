extends Node

var stage_scores: Dictionary = {}
var total_score: int = 0
var last_stage: int = 0
var last_stage_score: int = 0

func add_stage_score(stage: int, score: int) -> void:
	stage_scores[stage] = score
	total_score += score

func record_game_over(stage: int, score: int) -> void:
	last_stage = stage
	last_stage_score = score

func reset() -> void:
	stage_scores.clear()
	total_score = 0
	last_stage = 0
	last_stage_score = 0
