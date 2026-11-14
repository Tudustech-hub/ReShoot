extends StaticBody2D
class_name Turret

signal turret_destroyed(turret: Turret)

@export var max_health: int = 1
@export var fire_rate: float = 2.8
@export var ball_speed: float = 380.0

var health: int = 1
var target_player: Node2D = null
var is_charging: bool = false
var charge_time: float = 0.5
var charge_timer: float = 0.0

@onready var pivot: Node2D = $CannonPivot
@onready var sprite: Sprite2D = $CannonPivot/Sprite2D
@onready var muzzle: Marker2D = $CannonPivot/Muzzle
@onready var fire_timer: Timer = $FireTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var shoot_audio: AudioStreamPlayer2D = $ShootAudio

const BALL_SCENE := preload("res://scenes/dodgeball.tscn")

var active_modifier: int = -1

func _ready() -> void:
	health = max_health
	fire_timer.wait_time = randf_range(fire_rate * 0.8, fire_rate * 1.2)
	fire_timer.start()
	apply_modifier_visuals()

func set_modifier(mod_type: int) -> void:
	active_modifier = mod_type
	if is_node_ready():
		apply_modifier_visuals()

func apply_modifier_visuals() -> void:
	if active_modifier == 0:
		sprite.modulate = Color(0.65, 1.25, 0.65, 1.0)
	elif active_modifier == 1:
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.38)
	elif active_modifier == 2:
		sprite.modulate = Color(1.25, 1.45, 0.45, 1.0)
	elif active_modifier == 3:
		sprite.modulate = Color(0.45, 0.7, 1.4, 1.0)
	else:
		sprite.modulate = Color.WHITE

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player")
		return

	var target_pos := target_player.global_position
	var desired_angle := (target_pos - global_position).angle()
	pivot.rotation = rotate_toward(pivot.rotation, desired_angle, 3.5 * delta)

	if is_charging:
		charge_timer -= delta
		if active_modifier == 1:
			sprite.modulate = Color(1.6, 1.6, 1.6, 0.65) if fmod(charge_timer, 0.1) > 0.05 else Color(1.0, 1.0, 1.0, 0.38)
		elif active_modifier == 0:
			sprite.modulate = Color(1.8, 2.2, 1.8, 1.0) if fmod(charge_timer, 0.1) > 0.05 else Color(0.65, 1.25, 0.65, 1.0)
		elif active_modifier == 2:
			sprite.modulate = Color(1.9, 2.3, 0.8, 1.0) if fmod(charge_timer, 0.1) > 0.05 else Color(1.25, 1.45, 0.45, 1.0)
		elif active_modifier == 3:
			sprite.modulate = Color(1.0, 1.8, 2.5, 1.0) if fmod(charge_timer, 0.1) > 0.05 else Color(0.45, 0.7, 1.4, 1.0)
		else:
			sprite.modulate = Color(2.0, 2.0, 2.0, 1.0) if fmod(charge_timer, 0.1) > 0.05 else Color.WHITE
		if charge_timer <= 0.0:
			fire_ball()

func _on_fire_timer_timeout() -> void:
	if health <= 0 or not is_instance_valid(target_player):
		return
	is_charging = true
	charge_timer = charge_time

func _exit_tree() -> void:
	if shoot_audio:
		shoot_audio.stop()
		shoot_audio.stream = null

func fire_ball() -> void:
	is_charging = false
	apply_modifier_visuals()
	if shoot_audio:
		shoot_audio.pitch_scale = randf_range(0.95, 1.05)
		shoot_audio.play()

	var shoot_dir := Vector2.RIGHT.rotated(pivot.rotation)
	var ball := BALL_SCENE.instantiate() as Dodgeball
	get_parent().add_child(ball)
	ball.launch_from_turret(muzzle.global_position, shoot_dir, ball_speed, self, active_modifier)

	var tween := create_tween()
	tween.tween_property(sprite, "position:x", -8.0, 0.06)
	tween.tween_property(sprite, "position:x", 0.0, 0.15)

	fire_timer.wait_time = randf_range(fire_rate * 0.85, fire_rate * 1.15)
	fire_timer.start()

func take_damage(amount: int = 1) -> void:
	health -= amount
	if health <= 0:
		destroy()

func destroy() -> void:
	set_physics_process(false)
	fire_timer.stop()
	collision_shape.set_deferred("disabled", true)

	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(8.0, 0.25)

	turret_destroyed.emit(self)
	
	var ball := BALL_SCENE.instantiate() as Dodgeball
	get_parent().call_deferred("add_child", ball)
	ball.global_position = global_position
	ball.set_inert()

	queue_free()
