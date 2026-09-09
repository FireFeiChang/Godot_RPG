extends Node2D
## 武器店：玩家靠近按 E 打开商店界面。

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interact_area: Area2D = $InteractArea
@onready var prompt: Label = $Prompt

var _player_near := false

func _ready():
	_build_sprite_frames()
	sprite.play("Idle")
	prompt.visible = false
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _process(_delta):
	prompt.visible = _player_near
	if Input.is_action_just_pressed("interact") and _player_near:
		open_shop()

func open_shop():
	print("WeaponShop: 打开武器店界面")
	# TODO: 连接商店 UI

func _build_sprite_frames():
	var texture = load("res://World/shop/weapon_shop.png")
	if texture == null:
		return

	var frames = SpriteFrames.new()
	frames.add_animation("Idle")
	var frames_x = int(texture.get_width() / 64)

	for i in range(frames_x):
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = texture
		atlas_tex.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame("Idle", atlas_tex, 0.15)

	sprite.sprite_frames = frames

func _on_body_entered(body):
	if body.has_method("player"):
		_player_near = true

func _on_body_exited(body):
	if body.has_method("player"):
		_player_near = false
