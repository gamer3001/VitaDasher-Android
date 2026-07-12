extends Node2D

# Ce niveau est fini (contrairement aux modes infinis) : le sommet
# est la plateforme du but (~4800px plus haut que le départ), donc
# le dégradé va du bleu de jour en bas jusqu'à l'espace pile au but.
const SKY_TRANSITION_HEIGHT = 5300.0

onready var player = $Player
onready var sky_color = $BackgroundLayer/SkyColor
onready var sky_gradient = SkyGradient.build_gradient()

var start_y = 0.0

func _ready():
	start_y = player.position.y

func _process(delta):
	var height = max(0.0, start_y - player.position.y)
	var progress = clamp(height / SKY_TRANSITION_HEIGHT, 0.0, 1.0)
	sky_color.color = SkyGradient.get_sky_color(sky_gradient, progress)
	$BackgroundLayer/StarsParticles.modulate.a = SkyGradient.get_stars_alpha(progress)

func _on_Obstacles_body_entered(body):
	if body.name == "Player":
		get_tree().reload_current_scene()

func _on_Goal_body_entered(body):
	if body.name == "Player":
		$UI/LabelVictory.show()
		get_tree().paused = true
