extends CanvasLayer

# Autoload : ajoute tout seul, par-dessus la scène active, un bouton
# "Boutique" sur le menu principal et un bouton pause tactile en haut de
# l'écran pendant une partie (Infini/Survie). N'importe la scène active en
# surveillant son nom chaque frame, sans jamais modifier MainMenu.tscn,
# InfiniteMode.tscn ou SurvivalMode.tscn : plus sûr que de deviner leur
# structure interne. Enregistré dans project.godot sous [autoload] :
# HudOverlay="*res://HudOverlay.gd"

const MENU_SCENE = "res://MainMenu.tscn"
const SHOP_SCENE = "res://Shop.tscn"
# Noms des scènes où le bouton pause doit apparaître.
const GAMEPLAY_SCENES = ["InfiniteMode", "SurvivalMode", "World"]

var current_scene_name = ""
var shop_button
var pause_button
var pause_overlay

func _ready():
	# Reste actif même quand get_tree().paused = true (sinon le bouton
	# "Reprendre" ne répondrait jamais au clic une fois en pause).
	pause_mode = Node.PAUSE_MODE_PROCESS
	layer = 100 # au-dessus de tout le reste

func _process(_delta):
	var scene = get_tree().current_scene
	if scene == null:
		return
	if scene.name != current_scene_name:
		current_scene_name = scene.name
		_rebuild(scene.name)

func _rebuild(scene_name):
	if shop_button:
		shop_button.queue_free()
		shop_button = null
	if pause_button:
		pause_button.queue_free()
		pause_button = null
	_close_pause_overlay()

	if scene_name == "MainMenu":
		_add_shop_button()
	elif scene_name in GAMEPLAY_SCENES:
		_add_pause_button()

func _add_shop_button():
	shop_button = Button.new()
	shop_button.text = "Boutique"
	var vp = get_viewport().size
	shop_button.rect_size = Vector2(160, 48)
	shop_button.rect_position = Vector2(vp.x - 180, 20)
	add_child(shop_button)
	shop_button.connect("pressed", self, "_on_shop_pressed")

func _on_shop_pressed():
	get_tree().change_scene(SHOP_SCENE)

func _add_pause_button():
	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.rect_size = Vector2(50, 50)
	pause_button.rect_position = Vector2(10, 10)
	add_child(pause_button)
	pause_button.connect("pressed", self, "_on_pause_pressed")

func _on_pause_pressed():
	get_tree().paused = true
	_open_pause_overlay()

func _open_pause_overlay():
	if pause_overlay:
		return
	var vp = get_viewport().size

	pause_overlay = ColorRect.new()
	pause_overlay.pause_mode = Node.PAUSE_MODE_PROCESS
	pause_overlay.color = Color(0, 0, 0, 0.72)
	pause_overlay.rect_size = vp
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pause_overlay)

	var title = Label.new()
	title.text = "PAUSE"
	title.add_color_override("font_color", Color(1, 1, 1, 1))
	title.rect_position = Vector2(vp.x / 2.0 - 40, vp.y / 2.0 - 140)
	pause_overlay.add_child(title)

	var resume_btn = Button.new()
	resume_btn.text = "Reprendre"
	resume_btn.rect_size = Vector2(220, 56)
	resume_btn.rect_position = Vector2(vp.x / 2.0 - 110, vp.y / 2.0 - 70)
	pause_overlay.add_child(resume_btn)
	resume_btn.connect("pressed", self, "_on_resume_pressed")

	var menu_btn = Button.new()
	menu_btn.text = "Retour au menu"
	menu_btn.rect_size = Vector2(220, 56)
	menu_btn.rect_position = Vector2(vp.x / 2.0 - 110, vp.y / 2.0 + 10)
	pause_overlay.add_child(menu_btn)
	menu_btn.connect("pressed", self, "_on_menu_pressed")

func _on_resume_pressed():
	get_tree().paused = false
	_close_pause_overlay()

func _on_menu_pressed():
	get_tree().paused = false
	_close_pause_overlay()
	get_tree().change_scene(MENU_SCENE)

func _close_pause_overlay():
	if pause_overlay:
		pause_overlay.queue_free()
		pause_overlay = null
