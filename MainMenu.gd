extends Control

# --- Navigation ---
onready var buttons = $VBoxContainer.get_children()
onready var selection_arrow = $SelectionArrow

# --- Slideshow d'arrière-plan ---
onready var background_a = $BackgroundA
onready var background_b = $BackgroundB
onready var tween = $Tween
onready var bg_timer = $BackgroundTimer

const SLIDESHOW_FOLDER = "res://Asset/MainMenu"
const DISPLAY_DURATION = 6.0   # temps d'affichage d'une image avant de changer
const FADE_DURATION = 1.2      # durée du petit effet de fondu

var image_paths = []
var images = []
var current_idx = 0
var front_bg  # référence au TextureRect actuellement visible
var back_bg   # référence au TextureRect qui va recevoir la prochaine image

func _ready():
	_setup_navigation()
	_setup_slideshow()

# ---------------------------------------------------------------------------
# Navigation clavier / manette
# ---------------------------------------------------------------------------
func _setup_navigation():
	# Sélectionne le premier bouton par défaut
	if buttons.size() > 0:
		buttons[0].grab_focus()

	# Setup des voisins de focus pour la navigation (ui_up / ui_down)
	for i in range(buttons.size()):
		var prev_i = (i - 1 + buttons.size()) % buttons.size()
		var next_i = (i + 1) % buttons.size()
		buttons[i].focus_neighbour_top = buttons[prev_i].get_path()
		buttons[i].focus_neighbour_bottom = buttons[next_i].get_path()

		# La souris/tactile met aussi le bouton survolé en focus
		buttons[i].connect("mouse_entered", buttons[i], "grab_focus")
		# Quand un bouton prend le focus, on déplace la petite flèche à côté
		buttons[i].connect("focus_entered", self, "_on_button_focus_entered", [buttons[i]])

	# Positionne la flèche sur le premier bouton dès le départ
	if buttons.size() > 0:
		_on_button_focus_entered(buttons[0])

	# NOTE : la touche/bouton "saut" (ui_accept) valide déjà un bouton
	# ayant le focus, c'est un comportement natif de Godot (Control + ui_accept).
	# Aucun code supplémentaire n'est nécessaire pour ça.

func _on_button_focus_entered(button):
	var local_y = button.rect_global_position.y - rect_global_position.y
	selection_arrow.rect_position.y = local_y + button.rect_size.y / 2.0 - selection_arrow.rect_size.y / 2.0

# ---------------------------------------------------------------------------
# Slideshow d'arrière-plan (chargement auto + fondu enchaîné)
# ---------------------------------------------------------------------------
func _setup_slideshow():
	front_bg = background_a
	back_bg = background_b

	_load_slideshow_images()

	if images.size() > 0:
		front_bg.texture = images[0]
		front_bg.modulate.a = 1.0
		back_bg.modulate.a = 0.0
		current_idx = 0

		if images.size() > 1:
			bg_timer.wait_time = DISPLAY_DURATION
			bg_timer.connect("timeout", self, "_on_BackgroundTimer_timeout")
			bg_timer.start()

func _load_slideshow_images():
	var dir = Directory.new()
	if dir.open(SLIDESHOW_FOLDER) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var ext = file_name.get_extension().to_lower()
				if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp":
					image_paths.append(SLIDESHOW_FOLDER + "/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	image_paths.sort()

	for path in image_paths:
		var tex = load(path)
		if tex:
			images.append(tex)

func _on_BackgroundTimer_timeout():
	if images.size() <= 1:
		return

	current_idx = (current_idx + 1) % images.size()
	back_bg.texture = images[current_idx]
	back_bg.modulate.a = 0.0

	tween.interpolate_property(back_bg, "modulate:a", 0.0, 1.0, FADE_DURATION, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.interpolate_property(front_bg, "modulate:a", 1.0, 0.0, FADE_DURATION, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")

	var temp = front_bg
	front_bg = back_bg
	back_bg = temp

# ---------------------------------------------------------------------------
# Boutons du menu
# ---------------------------------------------------------------------------
func _on_Campaign_pressed():
	get_tree().change_scene("res://World.tscn")

func _on_Infinite_pressed():
	get_tree().change_scene("res://InfiniteMode.tscn")

func _on_Survival_pressed():
	get_tree().change_scene("res://SurvivalMode.tscn")
