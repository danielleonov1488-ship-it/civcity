extends "res://scripts/test_tutor7.gd"
## Полная цепочка со снимками целей и проверкой стрелки между кадрами.

const TASK_DIR := "D:/CivCity/.work/stage6/tutor8b"


func _ready() -> void:
	await launcher_run("TUTOR8B", TASK_DIR + "/shots/", TASK_DIR + "/profiles")
