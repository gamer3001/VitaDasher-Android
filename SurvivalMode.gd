extends Node2D

# Même distance que dans InfiniteMode pour que l'espace arrive au
# même rythme dans les deux modes.
const SKY_TRANSITION_HEIGHT = 15000.0

const SAFE_MARGIN_RATIO = 0.167 # ~90px sur un écran de référence de 540

const SIDE_WALL_THICKNESS = 20.0
const SIDE_WALL_HALF_HEIGHT = 2500000.0

# --- Difficulté progressive ---
# Pas de mur ici, donc aucune aide au saut : on reste bien en dessous de la
# hauteur de saut max (~245px avec gravity=1000 / jump_force=-700), et on
# plafonne aussi les "grands écarts" pour ne jamais générer un passage
# impossible à sauter (l'ancien bug de blocs "trop hauts").
const MIN_GAP = 140.0
const MAX_GAP = 190.0
const SAFE_MAX_JUMP_GAP = 220.0
const DIFFICULTY_HEIGHT = 15000.0
const MAX_BIG_GAP_CHANCE = 0.15
const BIG_GAP_MULTIPLIER = 1.3

# Dimension en multiple de la taille de tuile (16px) : Biome pose autant de
# tuiles que nécessaire, sans jamais en étirer une.
const PLATFORM_WIDTH = 128.0 # 8 tuiles de 16px

var next_spawn_y = 400
var started = false
var base_speed = 50.0
var lava_speed = 50.0

var screen_width = 540.0
var safe_margin = 90.0

onready var player = $Player
onready var lava = $Lava
onready var sky_color = $BackgroundLayer/SkyColor
onready var sky_gradient = SkyGradient.build_gradient()
onready var text_gradient = Biome.build_text_gradient()
onready var score_label = $UI/LabelScore
onready var timer_label = $UI/LabelTimer
onready var anim_label = $UI/LabelEpic

var time_elapsed = 0.0
var last_milestone = 0

func _ready():
	# Terrain généré par rapport à la largeur RÉELLE de l'écran du joueur
	# (iPad, PC, téléphone...).
	screen_width = get_viewport_rect().size.x
	safe_margin = screen_width * SAFE_MARGIN_RATIO

	var pixel_font = Biome.load_pixel_font()
	score_label.add_font_override("font", pixel_font)
	timer_label.add_font_override("font", pixel_font)
	anim_label.add_font_override("font", pixel_font)

	spawn_side_walls()
	for i in range(8):
		spawn_chunk()
	lava.connect("body_entered", self, "_on_Lava_body_entered")
	anim_label.hide()

func spawn_side_walls():
	_spawn_side_wall(-SIDE_WALL_THICKNESS / 2.0)
	_spawn_side_wall(screen_width + SIDE_WALL_THICKNESS / 2.0)

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
		lava.position.y -= lava_speed * delta
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

	lava_speed = base_speed + (height / 1000) * 10

	var current_milestone = (height / 1000) * 1000
	if current_milestone > 0 and current_milestone > last_milestone:
		last_milestone = current_milestone
		show_epic_milestone(current_milestone, text_color)

func show_epic_milestone(dist, color):
	anim_label.text = str(dist) + " M !"
	anim_label.add_color_override("font_color", color)
	anim_label.show()

	var tween = Tween.new()
	add_child(tween)
	anim_label.rect_scale = Vector2(0.5, 0.5)
	tween.interpolate_property(anim_label, "rect_scale", Vector2(0.5, 0.5), Vector2(2, 2), 0.5, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	tween.interpolate_property(anim_label, "modulate:a", 1.0, 0.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.0)
	tween.start()
	tween.connect("tween_all_completed", anim_label, "hide", [], 4)

func _on_Lava_body_entered(body):
	if body.name == "Player":
		player.play_death()
		var reload_timer = Timer.new()
		reload_timer.wait_time = 0.4
		reload_timer.one_shot = true
		add_child(reload_timer)
		reload_timer.start()
		yield(reload_timer, "timeout")
		get_tree().reload_current_scene()

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

	# Écart occasionnellement plus grand, mais toujours plafonné à
	# SAFE_MAX_JUMP_GAP : sans mur ici pour rattraper le coup, il faut que
	# CHAQUE écart reste franchissable en un seul saut normal.
	var big_gap_chance = lerp(0.0, MAX_BIG_GAP_CHANCE, difficulty)
	if randf() < big_gap_chance:
		gap = min(gap * BIG_GAP_MULTIPLIER, SAFE_MAX_JUMP_GAP)

	var tier = get_tier_at(next_spawn_y)

	var platform = StaticBody2D.new()
	platform.position = Vector2(rand_range(safe_margin, screen_width - safe_margin), next_spawn_y)
	add_child(platform)

	Biome.add_platform_visual(platform, PLATFORM_WIDTH, tier)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(PLATFORM_WIDTH / 2.0, Biome.SURFACE_HEIGHT / 2.0)
	col.shape = shape
	platform.add_child(col)

	next_spawn_y -= gap
