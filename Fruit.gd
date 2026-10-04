extends Area2D

# Fruit collectible (feuille fruit.png, 4 lignes de couleur x 3 variantes de
# 16x16). La VARIANTE est purement visuelle ; seule la FAMILLE (la ligne,
# donc la couleur) compte pour la monnaie, cf. Wallet.FRUIT_NAMES.
const CELL = 16
const COLS = 3
const ROWS = 4

var family = 0

onready var sprite = $Sprite

func _ready():
	family = randi() % ROWS
	var col = randi() % COLS
	sprite.region_rect = Rect2(col * CELL, family * CELL, CELL, CELL)
	connect("body_entered", self, "_on_body_entered")

func _on_body_entered(body):
	if body.name == "Player":
		Wallet.add_fruit(family, 1)
		queue_free()
