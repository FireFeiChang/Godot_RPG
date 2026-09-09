extends Node2D
## 风车：自动旋转的装饰物。

@export var frame_width := 64
@export var frame_height := 64
@export var fps := 8.0

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready():
	_build_sprite_frames()
	sprite.play()

func _build_sprite_frames():
	var texture = load("res://World/windmill/windmill.png")
	if texture == null:
		return

	var frames = SpriteFrames.new()
	frames.add_animation("rotate")
	var frames_x = int(texture.get_width() / frame_width)

	for i in range(frames_x):
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = texture
		atlas_tex.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("rotate", atlas_tex, 1.0 / fps)

	sprite.sprite_frames = frames
