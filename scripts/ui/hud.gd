class_name HUD
extends CanvasLayer

const HEALTH_MAX := 100.0

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	_refresh_health(HEALTH_MAX)


func _on_health_changed(new_health: float) -> void:
	_refresh_health(new_health)


func _refresh_health(value: float) -> void:
	health_bar.value = value
	health_label.text = "Health: %d" % int(value)
