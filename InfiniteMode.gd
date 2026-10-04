extends Node2D

# Hauteur (en pixels) à partir de laquelle le ciel a fini sa transition
# complète (jour -> coucher de soleil -> espace).
const SKY_TRANSITION_HEIGHT = 15000.0

# Largeur de terrain utilisable, en fraction de l'écran RÉEL du joueur
# (calculée dans _ready) : ipad, téléphone étroit ou large, peu importe,
# on génère toujours par rapport à ce que ce joueur voit vraiment.
const WALL_MARGIN_RATIO = 0.111 # ~60px sur un écran de référence de 540
const SAFE_MARGIN_RATIO = 0.167 # ~90px sur un écran de référence de 540

# Murs invisibles sur les bords pour empêcher de tomber sur les côtés :
# très hauts pour couvrir toute la montée, quelle que soit la hauteur atteinte.
const SIDE_WALL_THICKNESS = 20.0
const SIDE_WALL_HALF_HEIGHT = 2500000.0

# --- Difficulté progressive ---
# Avec gravity=1000 et jump_force=-700, la hauteur max d'un saut vertical
# est d'environ 245px (v²/2g). On garde une marge de sécurité en dessous
# de cette limite, ET on s'assure qu'aucune combinaison de générations
# (trou + plateforme suivante) ne dépasse jamais ce plafond : avant, un
# "trou" pouvait s'ajouter à un écart déjà grand et rendre la suite
# littéralement inatteignable (le bug de blocs "trop hauts").
const MIN_GAP = 150.0
const MAX_GAP = 195.0
const SAFE_MAX_JUMP_GAP = 225.0 # plafond ABSOLU, jamais dépassé même avec un "grand trou"
const DIFFICULTY_HEIGHT = 20000.0

const MIN_WALL_CHANCE = 0.22
const MAX_WALL_CHANCE = 0.4
const MAX_SAFETY_PLATFORM_CHANCE = 0.9
const MIN_SAFETY_PLATFORM_CHANCE = 0.35
const MAX_BIG_GAP_CHANCE = 0.22 # chance qu'un écart soit "grand" (mais toujours franchissable)
const BIG_GAP_MULTIPLIER = 1.35

# Dimensions en multiples de la taille des tuiles (16px) : Biome pose autant
# de tuiles que nécessaire, sans jamais en étirer une. La collision d'une
# plateforme ne couvre que sa ligne du dessus (Biome.SURFACE_HEIGHT), le
# bloc plein dessous est purement décoratif.
const PLATFORM_WIDTH = 128.0 # 8 tuiles de 16px
const WALL_WIDTH = 16.0 # 1 tuile
const WALL_HEIGHT = 160.0 # 10 tuiles de 16px
const SAFETY_PLATFORM_WIDTH = 96.0 # 6 tuiles de 16px

const COIN_SCENE = preload("res://Coin.tscn")
const COIN_CHANCE = 0.45 # chance qu'une pièce apparaisse au-dessus d'une plateforme normale
const FRUIT_SCENE = preload("res://Fruit.tscn")
const FRUIT_CHANCE = 0.12 # (indépendante de la pièce : jamais les deux au même endroit)

var next_spawn_y = 400
var started = false
var last_row_was_gap = false

var screen_width = 540.0
var left_wall
var right_wall
var wall_margin = 60.0
var safe_margin = 90.0

onready var player = $Player
onready var camera = $Camera2D
onready var score_label = $UI/LabelScore
onready var timer_label = $UI/LabelTimer
onready var sky_color = $BackgroundLayer/SkyColor
onready var sky_gradient = SkyGradient.build_gradient()
onready var text_gradient = Biome.build_text_gradient()
var coin_label

var time_elapsed = 0.0

func _ready():
	# On génère le terrain par rapport à la largeur RÉELLE de l'écran du
	# joueur (iPad, PC, téléphone...), pas une valeur fixe pensée pour un
	# seul format de téléphone.
	screen_width = OS.window_size.x
	wall_margin = screen_width * WALL_MARGIN_RATIO
	safe_margin = screen_width * SAFE_MARGIN_RATIO
	get_viewport().connect("size_changed", self, "_on_viewport_resized")

	# Recentre le joueur (et donc la caméra, qui le suit) sur l'écran RÉEL
	# du joueur, quelle que soit sa résolution : sans ça le personnage
	# démarrait toujours à une position pensée pour un écran de téléphone
	# (540px), et tout le terrain généré sur un écran plus large qu'un
	# téléphone se retrouvait très excentré vers la droite.
	player.position.x = screen_width / 2.0
	camera.current = true

	var pixel_font = Biome.load_pixel_font()
	score_label.add_font_override("font", pixel_font)
	timer_label.add_font_override("font", pixel_font)

	coin_label = Label.new()
	coin_label.add_font_override("font", pixel_font)
	coin_label.add_color_override("font_color", Color(1, 0.9, 0.3, 1))
	coin_label.rect_position = Vector2(screen_width - 260, 10)
	$UI.add_child(coin_label)

	spawn_side_walls()
	for i in range(8):
		spawn_chunk()

func spawn_side_walls():
	left_wall = _spawn_side_wall(-SIDE_WALL_THICKNESS / 2.0)
	right_wall = _spawn_side_wall(screen_width + SIDE_WALL_THICKNESS / 2.0)

func _spawn_side_wall(x):
	var wall = StaticBody2D.new()
	wall.position = Vector2(x, 0)
	wall.add_to_group("screen_edge")
	add_child(wall)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(SIDE_WALL_THICKNESS / 2.0, SIDE_WALL_HALF_HEIGHT)
	col.shape = shape
	wall.add_child(col)
	return wall

# Appelé par Godot chaque fois que la fenêtre change de taille (le
# joueur l'agrandit, la maximise, tourne son iPad...). Sans ça, le jeu
# continuait à générer le terrain pour la taille de fenêtre du tout
# premier lancement, d'où les plateformes coincées dans une bande étroite
# sur un écran de PC redimensionné.
# Appelée au signal "size_changed" ET à chaque frame depuis _process (voir
# plus bas) : certains environnements ne déclenchent pas le signal de façon
# fiable (redimensionnement par l'OS, plein écran, changement de moniteur),
# donc on revérifie en continu plutôt que de ne compter que sur le signal.
# OS.window_size est utilisé plutôt que get_viewport_rect().size : c'est la
# taille réelle de la fenêtre en pixels, sans ambiguïté liée au stretch mode.
func _on_viewport_resized():
	_sync_screen_size()

func _sync_screen_size():
	var new_width = OS.window_size.x
	if new_width == screen_width:
		return
	screen_width = new_width
	wall_margin = screen_width * WALL_MARGIN_RATIO
	safe_margin = screen_width * SAFE_MARGIN_RATIO
	if left_wall:
		left_wall.position.x = -SIDE_WALL_THICKNESS / 2.0
	if right_wall:
		right_wall.position.x = screen_width + SIDE_WALL_THICKNESS / 2.0
	if coin_label:
		coin_label.rect_position.x = screen_width - 260

func _process(delta):
	_sync_screen_size()
	# Suivi de caméra fait ici en dur (plutôt que de dépendre du
	# RemoteTransform2D de la scène, qui ne suivait pas de façon fiable) :
	camera.global_position = player.global_position

	if started:
		time_elapsed += delta
	update_ui()

	if not started and player.velocity.y < 0:
		started = true

	if player.position.y < next_spawn_y + 800:
		spawn_chunk()

func update_ui():
	timer_label.text = "Temps: %02d:%02d" % [int(time_elapsed / 60), int(fmod(time_elapsed, 60))]

	var height = int(max(0, -player.position.y + 400))
	score_label.text = "Hauteur: %d" % height

	var progress = clamp(float(height) / SKY_TRANSITION_HEIGHT, 0.0, 1.0)
	sky_color.color = SkyGradient.get_sky_color(sky_gradient, progress)
	$BackgroundLayer/StarsParticles.modulate.a = SkyGradient.get_stars_alpha(progress)

	var text_color = Biome.get_text_color(text_gradient, progress)
	score_label.add_color_override("font_color", text_color)
	timer_label.add_color_override("font_color", text_color)

	coin_label.text = "Pièces: %d" % Wallet.total_coins

func get_difficulty():
	var height_climbed = max(0.0, 400.0 - next_spawn_y)
	return clamp(height_climbed / DIFFICULTY_HEIGHT, 0.0, 1.0)

func get_tier_at(spawn_y: float) -> int:
	var height_here = max(0.0, -spawn_y + 400.0)
	var progress_here = clamp(height_here / SKY_TRANSITION_HEIGHT, 0.0, 1.0)
	return Biome.get_tier(progress_here)

func spawn_chunk():
	var difficulty = get_difficulty()
	var gap = lerp(MIN_GAP, MAX_GAP, difficulty)

	# Un écart occasionnellement plus grand pour casser le rythme, mais
	# JAMAIS au-delà de SAFE_MAX_JUMP_GAP : contrairement à l'ancien système
	# (une rangée vide de temps en temps), on ne saute plus JAMAIS deux
	# écarts à la suite, donc plus de "trou double" impossible à franchir.
	var big_gap_chance = lerp(0.0, MAX_BIG_GAP_CHANCE, difficulty)
	if randf() < big_gap_chance:
		gap = min(gap * BIG_GAP_MULTIPLIER, SAFE_MAX_JUMP_GAP)

	var tier = get_tier_at(next_spawn_y)

	var wall_chance = lerp(MIN_WALL_CHANCE, MAX_WALL_CHANCE, difficulty)
	var is_wall = randf() < wall_chance

	var platform = StaticBody2D.new()
	var side = 0.0
	if is_wall:
		side = wall_margin if randf() < 0.5 else screen_width - wall_margin
		platform.position = Vector2(side, next_spawn_y)
	else:
		platform.position = Vector2(rand_range(safe_margin, screen_width - safe_margin), next_spawn_y)
	add_child(platform)

	if is_wall:
		Biome.add_wall_visual(platform, WALL_WIDTH, WALL_HEIGHT, tier)
	else:
		Biome.add_platform_visual(platform, PLATFORM_WIDTH, tier)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	if is_wall:
		shape.extents = Vector2(WALL_WIDTH / 2.0, WALL_HEIGHT / 2.0)
	else:
		shape.extents = Vector2(PLATFORM_WIDTH / 2.0, Biome.SURFACE_HEIGHT / 2.0)
	col.shape = shape
	platform.add_child(col)

	if not is_wall and randf() < COIN_CHANCE:
		var coin = COIN_SCENE.instance()
		coin.position = platform.position + Vector2(0, -28)
		add_child(coin)
	elif not is_wall and randf() < FRUIT_CHANCE:
		var fruit = FRUIT_SCENE.instance()
		fruit.position = platform.position + Vector2(0, -28)
		add_child(fruit)

	# Plateforme de secours à proximité du mur (pour le wall-jump), de plus
	# en plus rare en altitude. Placée relativement au mur (pas à des
	# coordonnées fixes) pour rester cohérente quelle que soit la largeur
	# d'écran.
	if is_wall:
		var safety_chance = lerp(MAX_SAFETY_PLATFORM_CHANCE, MIN_SAFETY_PLATFORM_CHANCE, difficulty)
		if randf() < safety_chance:
			var jump_platform = StaticBody2D.new()
			var inward = 1.0 if side < screen_width / 2.0 else -1.0
			var platform_x = side + inward * rand_range(50, 135)
			jump_platform.position = Vector2(platform_x, next_spawn_y + 50)
			add_child(jump_platform)

			Biome.add_platform_visual(jump_platform, SAFETY_PLATFORM_WIDTH, tier)

			var j_col = CollisionShape2D.new()
			var j_shape = RectangleShape2D.new()
			j_shape.extents = Vector2(SAFETY_PLATFORM_WIDTH / 2.0, Biome.SURFACE_HEIGHT / 2.0)
			j_col.shape = j_shape
			jump_platform.add_child(j_col)

	next_spawn_y -= gap
