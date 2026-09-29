extends Node2D

# Hauteur (en pixels) à partir de laquelle le ciel a fini sa transition
# complète (jour -> coucher de soleil -> espace).
const SKY_TRANSITION_HEIGHT = 15000.0

# Largeur de l'écran de jeu (portrait, cf. project.godot).
const SCREEN_WIDTH = 540.0
const WALL_MARGIN = 60.0 # distance du bord de l'écran pour un mur
const SAFE_MARGIN = 90.0 # marge de sécurité pour les plateformes normales

# Murs invisibles sur les bords pour empêcher de tomber sur les côtés :
# très hauts pour couvrir toute la montée, quelle que soit la hauteur atteinte.
const SIDE_WALL_THICKNESS = 20.0
const SIDE_WALL_HALF_HEIGHT = 2500000.0

# --- Difficulté progressive ---
# Avec gravity=1000 et jump_force=-700, la hauteur max d'un saut vertical
# est d'environ 245px (v²/2g). MAX_GAP reste sous cette valeur.
const MIN_GAP = 150.0 # espacement vertical de base (départ)
const MAX_GAP = 220.0 # espacement vertical max (haute altitude)
const DIFFICULTY_HEIGHT = 20000.0 # hauteur pour atteindre la difficulté max

const MIN_WALL_CHANCE = 0.22
const MAX_WALL_CHANCE = 0.4
const MAX_SAFETY_PLATFORM_CHANCE = 0.9
const MIN_SAFETY_PLATFORM_CHANCE = 0.35
const MAX_GAP_ROW_CHANCE = 0.22

# Dimensions en multiples de la taille des tuiles : Biome pose autant de
# tuiles que nécessaire, sans jamais en étirer une.
# La collision d'une plateforme ne couvre que sa ligne du dessus
# (Biome.SURFACE_HEIGHT), le bloc plein dessous est purement décoratif.
const PLATFORM_WIDTH = 128.0 # 4 tuiles de 32px
const WALL_WIDTH = 16.0 # 1 tuile de 16px
const WALL_HEIGHT = 160.0 # 10 tuiles de 16px
const SAFETY_PLATFORM_WIDTH = 96.0 # 3 tuiles de 32px

var next_spawn_y = 400
var started = false
var last_row_was_gap = false

onready var player = $Player
onready var camera = $Camera2D
onready var score_label = $UI/LabelScore
onready var timer_label = $UI/LabelTimer
onready var sky_color = $BackgroundLayer/SkyColor
onready var sky_gradient = SkyGradient.build_gradient()
onready var text_gradient = Biome.build_text_gradient()

var time_elapsed = 0.0

func _ready():
	var pixel_font = Biome.load_pixel_font()
	score_label.add_font_override("font", pixel_font)
	timer_label.add_font_override("font", pixel_font)

	spawn_side_walls()
	# Génère les premières plateformes, un peu plus dense pour bien démarrer
	for i in range(8):
		spawn_chunk()

func spawn_side_walls():
	_spawn_side_wall(-SIDE_WALL_THICKNESS / 2.0)
	_spawn_side_wall(SCREEN_WIDTH + SIDE_WALL_THICKNESS / 2.0)

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

func _process(delta):
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

	# Transition du ciel : jour -> coucher de soleil -> espace
	var progress = clamp(float(height) / SKY_TRANSITION_HEIGHT, 0.0, 1.0)
	sky_color.color = SkyGradient.get_sky_color(sky_gradient, progress)
	$BackgroundLayer/StarsParticles.modulate.a = SkyGradient.get_stars_alpha(progress)

	# Le texte suit le même dégradé que le sol/le ciel.
	var text_color = Biome.get_text_color(text_gradient, progress)
	score_label.add_color_override("font_color", text_color)
	timer_label.add_color_override("font_color", text_color)

func get_difficulty():
	var height_climbed = max(0.0, 400.0 - next_spawn_y)
	return clamp(height_climbed / DIFFICULTY_HEIGHT, 0.0, 1.0)

# Palier visuel (herbe/terre/lave/glace) pour un y de spawn donné.
func get_tier_at(spawn_y: float) -> int:
	var height_here = max(0.0, -spawn_y + 400.0)
	var progress_here = clamp(height_here / SKY_TRANSITION_HEIGHT, 0.0, 1.0)
	return Biome.get_tier(progress_here)

func spawn_chunk():
	var difficulty = get_difficulty()
	var gap = lerp(MIN_GAP, MAX_GAP, difficulty)

	# Un vrai "trou" de temps en temps, jamais deux d'affilée.
	var gap_row_chance = lerp(0.0, MAX_GAP_ROW_CHANCE, difficulty)
	if not last_row_was_gap and randf() < gap_row_chance:
		last_row_was_gap = true
		next_spawn_y -= gap
		return
	last_row_was_gap = false

	var tier = get_tier_at(next_spawn_y)

	var wall_chance = lerp(MIN_WALL_CHANCE, MAX_WALL_CHANCE, difficulty)
	var is_wall = randf() < wall_chance

	var platform = StaticBody2D.new()
	var side = 0
	if is_wall:
		side = WALL_MARGIN if randf() < 0.5 else SCREEN_WIDTH - WALL_MARGIN
		platform.position = Vector2(side, next_spawn_y)
	else:
		platform.position = Vector2(rand_range(SAFE_MARGIN, SCREEN_WIDTH - SAFE_MARGIN), next_spawn_y)
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

	# Plateforme de secours à proximité du mur (pour le wall-jump), de plus
	# en plus rare en altitude.
	if is_wall:
		var safety_chance = lerp(MAX_SAFETY_PLATFORM_CHANCE, MIN_SAFETY_PLATFORM_CHANCE, difficulty)
		if randf() < safety_chance:
			var jump_platform = StaticBody2D.new()
			var platform_x = (rand_range(110, 195) if side > SCREEN_WIDTH / 2.0 else rand_range(345, 425))
			jump_platform.position = Vector2(platform_x, next_spawn_y + 50)
			add_child(jump_platform)

			Biome.add_platform_visual(jump_platform, SAFETY_PLATFORM_WIDTH, tier)

			var j_col = CollisionShape2D.new()
			var j_shape = RectangleShape2D.new()
			j_shape.extents = Vector2(SAFETY_PLATFORM_WIDTH / 2.0, Biome.SURFACE_HEIGHT / 2.0)
			j_col.shape = j_shape
			jump_platform.add_child(j_col)

	next_spawn_y -= gap
