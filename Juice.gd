# Juice Implementation: Screenshake Helper
extends Node

func shake(camera: Camera2D, duration: float, magnitude: float):
	var elapsed = 0.0
	while elapsed < duration:
		camera.offset = Vector2(rand_range(-magnitude, magnitude), rand_range(-magnitude, magnitude))
		elapsed += get_process_delta_time()
		yield(get_tree(), "idle_frame")
	camera.offset = Vector2.ZERO
