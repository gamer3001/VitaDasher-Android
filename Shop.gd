extends Control

# Boutique construite entièrement en code. Skins = teinte + stats de
# gameplay, débloqués avec les fruits de la couleur correspondante (ou un
# mélange fruits + pièces), plus achat de résurrections avec les pièces.
const SKIN_ORDER = ["grimpeur", "increvable", "felin", "acrobate"]

var coins_label
var revives_label
var fruit_labels = []
var skin_rows = {}

func _ready():
	var vp = get_viewport_rect().size

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1)
	bg.rect_size = vp
	add_child(bg)

	var font = Biome.load_pixel_font()
	var y = 30.0

	var title = Label.new()
	title.text = "BOUTIQUE"
	title.add_font_override("font", font)
	title.add_color_override("font_color", Color(1, 1, 1, 1))
	title.rect_position = Vector2(20, y)
	add_child(title)
	y += 44.0

	coins_label = Label.new()
	coins_label.add_font_override("font", font)
	coins_label.add_color_override("font_color", Color(1, 0.9, 0.3, 1))
	coins_label.rect_position = Vector2(20, y)
	add_child(coins_label)
	y += 32.0

	var fruit_colors = [Color(0.55, 0.95, 0.55, 1), Color(1.0, 0.7, 0.3, 1), Color(1.0, 0.6, 0.85, 1), Color(1.0, 0.4, 0.4, 1)]
	for i in range(4):
		var flabel = Label.new()
		flabel.add_font_override("font", font)
		flabel.add_color_override("font_color", fruit_colors[i])
		flabel.rect_position = Vector2(20, y)
		add_child(flabel)
		fruit_labels.append(flabel)
		y += 28.0

	y += 16.0

	for skin_name in SKIN_ORDER:
		var name_label = Label.new()
		name_label.add_font_override("font", font)
		name_label.add_color_override("font_color", Wallet.SKIN_COLORS[skin_name])
		name_label.rect_position = Vector2(20, y)
		add_child(name_label)
		y += 26.0

		var desc_label = Label.new()
		desc_label.add_font_override("font", font)
		desc_label.add_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		desc_label.text = Wallet.SKIN_DESCRIPTIONS[skin_name]
		desc_label.rect_position = Vector2(20, y)
		add_child(desc_label)
		y += 26.0

		var cost_label = Label.new()
		cost_label.add_font_override("font", font)
		cost_label.add_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		cost_label.rect_position = Vector2(20, y)
		add_child(cost_label)
		y += 30.0

		var btn = Button.new()
		btn.rect_position = Vector2(20, y)
		btn.rect_size = Vector2(240, 36)
		btn.connect("pressed", self, "_on_skin_pressed", [skin_name])
		add_child(btn)

		skin_rows[skin_name] = {"name": name_label, "cost": cost_label, "button": btn}
		y += 50.0

	y += 10.0
	var revive_btn = Button.new()
	revive_btn.text = "Acheter une résurrection (%d pièces)" % Wallet.REVIVE_COST
	revive_btn.rect_position = Vector2(20, y)
	revive_btn.rect_size = Vector2(vp.x - 40, 40)
	revive_btn.connect("pressed", self, "_on_buy_revive")
	add_child(revive_btn)
	y += 56.0

	revives_label = Label.new()
	revives_label.add_font_override("font", font)
	revives_label.add_color_override("font_color", Color(1, 1, 1, 1))
	revives_label.rect_position = Vector2(20, y)
	add_child(revives_label)
	y += 56.0

	var back_btn = Button.new()
	back_btn.text = "Retour"
	back_btn.rect_position = Vector2(20, y)
	back_btn.rect_size = Vector2(160, 40)
	back_btn.connect("pressed", self, "_on_back")
	add_child(back_btn)

	_refresh()

func _on_skin_pressed(skin_name):
	if skin_name in Wallet.unlocked_skins:
		Wallet.selected_skin = skin_name
		Wallet.save_wallet()
	else:
		Wallet.buy_skin(skin_name)
	_refresh()

func _on_buy_revive():
	Wallet.buy_revive()
	_refresh()

func _on_back():
	# Adapte le chemin si ton menu principal n'est pas res://MainMenu.tscn.
	get_tree().change_scene("res://MainMenu.tscn")

func _refresh():
	coins_label.text = "Pièces : %d" % Wallet.total_coins
	revives_label.text = "Résurrections en stock : %d" % Wallet.revives
	for i in range(4):
		fruit_labels[i].text = "Fruits %s : %d" % [Wallet.FRUIT_NAMES[i], Wallet.fruits[i]]

	for skin_name in SKIN_ORDER:
		var row = skin_rows[skin_name]
		var owned = skin_name in Wallet.unlocked_skins
		var family = Wallet.SKIN_FRUIT[skin_name]
		var fruit_name = Wallet.FRUIT_NAMES[family]

		row["name"].text = skin_name.capitalize() + (" (possédé)" if owned else "")

		if owned:
			row["cost"].text = ""
			row["button"].text = "Sélectionné" if Wallet.selected_skin == skin_name else "Choisir"
			row["button"].disabled = (Wallet.selected_skin == skin_name)
		else:
			row["cost"].text = "Coût : %d fruits %s, OU %d fruits %s + %d pièces" % [
				Wallet.SKIN_FRUIT_COST, fruit_name,
				Wallet.SKIN_FRUIT_PARTIAL, fruit_name, Wallet.SKIN_PARTIAL_COIN_COST,
			]
			row["button"].text = "Débloquer"
			var can_full = Wallet.fruits[family] >= Wallet.SKIN_FRUIT_COST
			var can_partial = Wallet.fruits[family] >= Wallet.SKIN_FRUIT_PARTIAL and Wallet.total_coins >= Wallet.SKIN_PARTIAL_COIN_COST
			row["button"].disabled = not (can_full or can_partial)
