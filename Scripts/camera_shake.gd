extends Camera2D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		var damping := shake_timer / shake_duration
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity) * damping,
			randf_range(-shake_intensity, shake_intensity) * damping
		)
		if shake_timer <= 0.0:
			offset = Vector2.ZERO

func shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration
