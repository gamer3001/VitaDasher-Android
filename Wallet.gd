extends Node

# Autoload (singleton) : monnaie persistante entre les parties (pièces +
# 4 familles de fruits), skins débloqués/sélectionné et réserve de
# résurrections. Enregistré dans project.godot sous [autoload] :
# Wallet="*res://Wallet.gd"

var total_coins = 0
var revives = 0
var unlocked_skins = ["default"]
var selected_skin = "default"

# 4 familles de fruits (lignes de Asset/sprites/fruit.png : vert/orange/
# rose/rouge, 3 variantes visuelles chacune mais une seule monnaie par
# couleur) : fruits[0]=vertes, [1]=oranges, [2]=roses, [3]=rouges.
var fruits = [0, 0, 0, 0]
const FRUIT_NAMES = ["vertes", "oranges", "roses", "rouges"]

const SAVE_PATH = "user://wallet.save"

# Skins = teinte + stats de gameplay (avantage/inconvénient), débloqués
# avec les fruits de la couleur correspondante (ou un mix fruits+pièces).
const SKIN_COLORS = {
	"default": Color(1, 1, 1, 1),
	"grimpeur": Color(0.55, 0.95, 0.55, 1),   # vert
	"increvable": Color(1.0, 0.7, 0.3, 1),    # orange
	"felin": Color(1.0, 0.6, 0.85, 1),        # rose
	"acrobate": Color(1.0, 0.4, 0.4, 1),      # rouge
}
# Index de la famille de fruit (voir FRUIT_NAMES) requise pour chaque skin.
const SKIN_FRUIT = {
	"grimpeur": 0,
	"increvable": 1,
	"felin": 2,
	"acrobate": 3,
}
# Modificateurs appliqués par Player.gd (voir _ready()). Champs possibles :
# no_dash, double_jump, wall_stamina_mult, jump_mult, speed_mult,
# dash_cooldown_mult, wall_jump_mult, stamina_drain_mult.
const SKIN_STATS = {
	"grimpeur": {"no_dash": true, "double_jump": true},
	"increvable": {"wall_stamina_mult": 2.0, "jump_mult": 0.85},
	"felin": {"speed_mult": 1.2, "dash_cooldown_mult": 1.5},
	"acrobate": {"wall_jump_mult": 1.3, "stamina_drain_mult": 1.3},
}
# Description courte (avantage / inconvénient) affichée dans la boutique.
const SKIN_DESCRIPTIONS = {
	"grimpeur": "Double-saut au lieu du dash (plus de hauteur, mais plus d'esquive rapide)",
	"increvable": "Endurance au mur x2 (mais saut 15% moins haut)",
	"felin": "Vitesse +20% (mais dash avec un cooldown 50% plus long)",
	"acrobate": "Wall-jump +30% de portée (mais endurance au mur se vide 30% plus vite)",
}

const SKIN_FRUIT_COST = 100 # option 1 : tout en fruits
const SKIN_FRUIT_PARTIAL = 10 # option 2 : un peu de fruits...
const SKIN_PARTIAL_COIN_COST = 500 # ...+ beaucoup de pièces
const REVIVE_COST = 20

func _ready():
	load_wallet()

func add_coins(amount: int) -> void:
	total_coins += amount
	save_wallet()

func add_fruit(family: int, amount: int = 1) -> void:
	if family < 0 or family >= fruits.size():
		return
	fruits[family] += amount
	save_wallet()

func can_afford(cost: int) -> bool:
	return total_coins >= cost

func buy_skin(skin_name: String) -> bool:
	if skin_name in unlocked_skins:
		return true
	var family = SKIN_FRUIT.get(skin_name, -1)
	if family == -1:
		return false
	if fruits[family] >= SKIN_FRUIT_COST:
		fruits[family] -= SKIN_FRUIT_COST
		unlocked_skins.append(skin_name)
		save_wallet()
		return true
	if fruits[family] >= SKIN_FRUIT_PARTIAL and total_coins >= SKIN_PARTIAL_COIN_COST:
		fruits[family] -= SKIN_FRUIT_PARTIAL
		total_coins -= SKIN_PARTIAL_COIN_COST
		unlocked_skins.append(skin_name)
		save_wallet()
		return true
	return false

func buy_revive() -> bool:
	if not can_afford(REVIVE_COST):
		return false
	total_coins -= REVIVE_COST
	revives += 1
	save_wallet()
	return true

func use_revive() -> bool:
	if revives <= 0:
		return false
	revives -= 1
	save_wallet()
	return true

func get_skin_color() -> Color:
	return SKIN_COLORS.get(selected_skin, Color(1, 1, 1, 1))

func get_skin_stats() -> Dictionary:
	return SKIN_STATS.get(selected_skin, {})

func save_wallet() -> void:
	var f = File.new()
	f.open(SAVE_PATH, File.WRITE)
	f.store_var({
		"total_coins": total_coins,
		"revives": revives,
		"unlocked_skins": unlocked_skins,
		"selected_skin": selected_skin,
		"fruits": fruits,
	})
	f.close()

func load_wallet() -> void:
	var f = File.new()
	if not f.file_exists(SAVE_PATH):
		return
	f.open(SAVE_PATH, File.READ)
	var data = f.get_var()
	f.close()
	if typeof(data) == TYPE_DICTIONARY:
		total_coins = data.get("total_coins", 0)
		revives = data.get("revives", 0)
		unlocked_skins = data.get("unlocked_skins", ["default"])
		selected_skin = data.get("selected_skin", "default")
		fruits = data.get("fruits", [0, 0, 0, 0])
