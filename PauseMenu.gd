extends CanvasLayer

# Ce noeud doit avoir "Pause Mode" = "Process" dans l'inspecteur
# (ou pause_mode = 2 ici) pour continuer à recevoir les inputs
# même quand le jeu est en pause.

onready var panel_pause = $PanelPause
onready var panel_settings = $PanelSettings

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	panel_pause.hide()
	panel_settings.hide()

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_tree().set_input_as_handled()

func toggle_pause():
	if get_tree().paused:
		_resume()
	else:
		_open_pause()

func _open_pause():
	get_tree().paused = true
	panel_pause.show()
	panel_settings.hide()

func _resume():
	get_tree().paused = false
	panel_pause.hide()
	panel_settings.hide()

func _on_Resume_pressed():
	_resume()

func _on_Settings_pressed():
	panel_pause.hide()
	panel_settings.show()

func _on_SettingsBack_pressed():
	panel_settings.hide()
	panel_pause.show()

func _on_MainMenu_pressed():
	get_tree().paused = false
	get_tree().change_scene("res://MainMenu.tscn")
