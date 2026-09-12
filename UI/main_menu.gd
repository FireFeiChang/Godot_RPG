extends Control
## 主界面（开始菜单）：使用自定义按钮素材。
## 包含：开始游戏（木质）、继续游戏（石质）、设置（羊皮纸）+ 设置面板。

func _on_start_button_pressed():
	if SaveManager.has_save(1):
		SaveManager.delete_save(1)
	MapManager.begin_new_game(0)          # 清空重来
	get_tree().change_scene_to_file(MapManager.MAPS[MapManager.intended_map()])

func _on_continue_button_pressed():
	if SaveManager.has_save(1):
		# 真正的 load_game() 由 MapManager.install() 在地图就位后调用 ——
		# 在这里调的话 current_scene 还是主菜单，找不到 Player，位置还原会失效。
		MapManager.begin_new_game(1)
		get_tree().change_scene_to_file(MapManager.MAPS[MapManager.intended_map()])
	else:
		# 没有存档，等同于新游戏
		_on_start_button_pressed()

func _on_settings_button_pressed():
	$SettingsPanel.visible = not $SettingsPanel.visible

func _on_back_button_pressed():
	$SettingsPanel.visible = false

func _on_volume_slider_value_changed(value):
	AudioServer.set_bus_volume_db(0, (value - 1.0) * -60.0)
