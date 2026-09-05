extends Control

func _on_start_button_pressed():
	if SaveManager.has_save(1):
		SaveManager.load_game(1)
	get_tree().change_scene_to_file("res://world.tscn")

func _on_settings_button_pressed():
	$SettingsPanel.visible = not $SettingsPanel.visible

func _on_quit_button_pressed():
	get_tree().quit()

func _on_back_button_pressed():
	$SettingsPanel.visible = false

func _on_volume_slider_value_changed(value):
	AudioServer.set_bus_volume_db(0, (value - 1.0) * -60.0)
