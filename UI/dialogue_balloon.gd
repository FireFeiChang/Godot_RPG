extends CanvasLayer
## 对话框气球：使用 Kenney UI 素材重新设计。
## 显示角色名、对话文本、响应选项。

signal dialogue_finished
signal response_selected(response)

@export var dialogue_resource: DialogueResource
@export var start_from_title: String = ""
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"

var dialogue_line: DialogueLine = null
var is_waiting_for_input: bool = false
var temporary_game_states: Array = []

@onready var balloon: Control = $Balloon
@onready var character_label: RichTextLabel = $Balloon/CharacterLabel
@onready var dialogue_label: RichTextLabel = $Balloon/DialogueLabel
@onready var responses_vbox: VBoxContainer = $Balloon/ResponsesVBox
@onready var progress_indicator: Control = $Balloon/ProgressIndicator

func _ready():
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

func _process(_delta):
	if dialogue_line and is_waiting_for_input:
		progress_indicator.visible = dialogue_line.responses.size() == 0

func _unhandled_input(event: InputEvent):
	if not is_waiting_for_input:
		return
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
	elif event.is_action_pressed(next_action):
		advance()

func start(with_dialogue_resource: DialogueResource = null, title: String = ""):
	if with_dialogue_resource:
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	temporary_game_states = [self]
	show()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	apply_dialogue_line()

func apply_dialogue_line():
	if not dialogue_line:
		finish()
		return

	balloon.show()
	is_waiting_for_input = false

	# 角色名
	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = dialogue_line.character

	# 对话文本
	dialogue_label.text = dialogue_line.text
	dialogue_label.visible_characters = 0

	# 响应选项
	for child in responses_vbox.get_children():
		child.queue_free()
	responses_vbox.hide()

	# 打字机效果
	if not dialogue_line.text.is_empty():
		# 使用 Timer 实现打字机效果
		for i in range(dialogue_line.text.length()):
			if not is_instance_valid(dialogue_label):
				return
			dialogue_label.visible_characters = i + 1
			await get_tree().create_timer(0.03).timeout

	# 显示响应选项或等待输入
	if dialogue_line.responses.size() > 0:
		for response in dialogue_line.responses:
			var btn = Button.new()
			btn.text = response.text
			btn.pressed.connect(_on_response_pressed.bind(response))
			responses_vbox.add_child(btn)
		responses_vbox.show()
		# 给第一个选项焦点：这样 Enter / E（ui_accept）能直接确认，
		# 上下方向键也能在选项间移动。没有焦点时键盘完全无法操作选项。
		var first_btn := responses_vbox.get_child(0) as Button
		if first_btn != null:
			first_btn.grab_focus()
	else:
		is_waiting_for_input = true

func advance():
	dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.next_id, temporary_game_states)
	apply_dialogue_line()

func _on_response_pressed(response):
	emit_signal("response_selected", response)
	dialogue_line = await dialogue_resource.get_next_dialogue_line(response.next_id, temporary_game_states)
	apply_dialogue_line()

func finish():
	balloon.hide()
	emit_signal("dialogue_finished")
	queue_free()

func _on_mutated(_mutation):
	pass
