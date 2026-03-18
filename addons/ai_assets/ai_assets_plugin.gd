@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/ai_assets/ai_asset_dock.tscn"

var _dock: Control


func _enter_tree() -> void:
	_dock = preload(DOCK_SCENE_PATH).instantiate()
	add_control_to_dock(DOCK_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
