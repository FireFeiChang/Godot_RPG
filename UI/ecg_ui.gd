extends Control

@onready var ecg_machine = $ECGMachine
@onready var ecg_display = $ECGDisplay
@onready var health_label = $HealthLabel

var state = PlayerStates

func _ready():
	state.connect("health_changed", update_ecg)
	update_ecg(state.health)

func update_ecg(health):
	var health_ratio = health / state.max_health
	if health <= 0:
		ecg_display.texture = load("res://素材/原版/心电图死亡.png")
	elif health_ratio < 0.3:
		ecg_display.texture = load("res://素材/原版/心电图死亡.png")
	else:
		ecg_display.texture = load("res://素材/原版/心电图存活.png")
	health_label.text = str(health) + "/" + str(state.max_health)