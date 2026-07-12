extends Area2D

func _on_Obstacles_body_entered(body):
	if body.name == "Player":
		# Trigger Death Logic
		get_tree().reload_current_scene()
