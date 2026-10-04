extends Area2D

# Pièce animée (feuille coin.png, 12 frames de 16x16) : rapporte 1 pièce au
# portefeuille (Wallet, persistant) au contact du joueur.
const FRAME_COUNT = 12
const FRAME_SIZE = 16
const SPIN_FPS = 12.0
const VALUE = 1

onready var sprite = $Sprite

var frame_timer = 0.0
var frame_index = 0

func _ready():
	sprite.region_rect = Rect2(0, 0, FRAME_SIZE, FRAME_SIZE)
	connect("body_entered", self, "_on_body_entered")

func _process(delta):
	frame_timer += delta
	if frame_timer >= 1.0 / SPIN_FPS:
		frame_timer = 0.0
		frame_index = (frame_index + 1) % FRAME_COUNT
		sprite.region_rect = Rect2(frame_index * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)

func _on_body_entered(body):
	if body.name == "Player":
		Wallet.add_coins(VALUE)
		queue_free()
