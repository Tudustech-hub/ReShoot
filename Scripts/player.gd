extends CharacterBody2D
class_name Player

signal health_changed(current_hp: int)
signal ball_status_changed(has_ball: bool)
signal dash_status_changed(progress: float)
signal modifier_changed(mod_type: int)
signal player_died

@export var speed: float = 240.0
@export var dash_speed: float = 580.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5
@export var max_health: int = 3

var health: int = 3
var has_ball: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0
var bounce_back_streak: int = 0
var walk_step_timer: float = 0.0
var current_modifier: int = -1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var held_ball_sprite: Sprite2D = $HeldBallSprite
@onready var aim_reticle: Sprite2D = $AimReticle
@onready var walk_audio: AudioStreamPlayer = $WalkAudio
@onready var throw_audio: AudioStreamPlayer = $ThrowAudio

const BALL_SCENE := preload("res://scenes/dodgeball.tscn")

var grass_steps: Array[AudioStream] = [
	preload("res://Assets/Walk on grass 1.mp3"),
	preload("res://Assets/Walk on grass 2.mp3"),
	preload("res://Assets/Walk on grass 3.mp3")
]

func _exit_tree() -> void:
	if walk_audio:
		walk_audio.stop()
		walk_audio.stream = null
	if throw_audio:
		throw_audio.stop()
		throw_audio.stream = null

func _ready() -> void:
	health = max_health
	health_changed.emit(health)
	ball_status_changed.emit(has_ball)
	modifier_changed.emit(current_modifier)
	update_ball_visuals()

func _physics_process(delta: float) -> void:
	if is_invulnerable:
		invulnerable_timer -= delta
		animated_sprite.visible = fmod(invulnerable_timer, 0.12) > 0.06
		if invulnerable_timer <= 0.0:
			is_invulnerable = false
			animated_sprite.visible = true

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		var progress := 1.0 - clampf(dash_cooldown_timer / dash_cooldown, 0.0, 1.0)
		dash_status_changed.emit(progress)
	else:
		dash_status_changed.emit(1.0)

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		move_and_slide()
		if dash_timer <= 0.0:
			is_dashing = false
		return

	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if input_vector.length() > 0.0:
		input_vector = input_vector.normalized()
		velocity = input_vector * speed
		animated_sprite.play("walk")
		if input_vector.x != 0.0:
			animated_sprite.flip_h = (input_vector.x < 0.0)
		walk_step_timer -= delta
		if walk_step_timer <= 0.0:
			walk_step_timer = 0.32
			if walk_audio and not walk_audio.playing:
				walk_audio.stream = grass_steps.pick_random()
				walk_audio.pitch_scale = randf_range(0.95, 1.05)
				walk_audio.play()
	else:
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		walk_step_timer = 0.05

	move_and_slide()

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		start_dash(input_vector)

	update_held_ball_position()

	if Input.is_action_just_pressed("throw"):
		if has_ball:
			throw_ball()
		else:
			try_parry_bounce_back()

	if Input.is_action_just_pressed("recall"):
		recall_balls()

func apply_modifier(mod_type: int) -> void:
	current_modifier = mod_type
	modifier_changed.emit(current_modifier)
	update_ball_visuals()

func get_current_modifier() -> int:
	return current_modifier

func try_parry_bounce_back() -> void:
	var balls := get_tree().get_nodes_in_group("dodgeballs")
	var mouse_pos := get_global_mouse_position()
	var aim_dir := (mouse_pos - global_position).normalized()
	
	for ball in balls:
		if ball is Dodgeball and is_instance_valid(ball):
			if ball.state == Dodgeball.State.HAZARDOUS:
				var dist := global_position.distance_to(ball.global_position)
				if dist < 65.0:
					ball.bounce_back(aim_dir, 740.0, current_modifier)
					on_bounce_back_success()
					return

func recall_balls() -> void:
	var balls := get_tree().get_nodes_in_group("dodgeballs")
	for ball in balls:
		if ball is Dodgeball and is_instance_valid(ball):
			if ball.state == Dodgeball.State.INERT or ball.state == Dodgeball.State.BOUNCING:
				ball.recall_to_player(self)

func play_sfx(pitch: float = 1.0) -> void:
	if walk_audio:
		walk_audio.pitch_scale = pitch
		walk_audio.play()

func on_bounce_back_success() -> void:
	bounce_back_streak += 1
	play_sfx(2.2)
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(12.0, 0.3)

	if health < max_health and bounce_back_streak >= 2:
		health = mini(max_health, health + 1)
		health_changed.emit(health)
		bounce_back_streak = 0

func update_held_ball_position() -> void:
	if not has_ball:
		aim_reticle.visible = false
		return
	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - global_position).normalized()
	held_ball_sprite.position = dir * 18.0
	aim_reticle.visible = true
	aim_reticle.global_position = mouse_pos

func start_dash(input_dir: Vector2) -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	is_invulnerable = true
	invulnerable_timer = dash_duration + 0.05
	play_sfx(1.3)
	
	if input_dir.length() > 0.1:
		dash_direction = input_dir.normalized()
	else:
		var mouse_pos := get_global_mouse_position()
		dash_direction = (mouse_pos - global_position).normalized()

func can_pick_up_ball() -> bool:
	return not has_ball

func pick_up_ball(mod_type: int = -1) -> void:
	has_ball = true
	if mod_type != -1:
		current_modifier = mod_type
		modifier_changed.emit(current_modifier)
	ball_status_changed.emit(true)
	update_ball_visuals()
	play_sfx(1.7)

func throw_ball() -> void:
	has_ball = false
	ball_status_changed.emit(false)
	update_ball_visuals()
	if throw_audio:
		throw_audio.pitch_scale = randf_range(0.95, 1.05)
		throw_audio.play()

	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - global_position).normalized()
	
	var ball := BALL_SCENE.instantiate() as Dodgeball
	get_parent().add_child(ball)
	var throw_spd: float = 780.0 if current_modifier == 2 else (580.0 if current_modifier == 3 else 650.0)
	ball.throw_by_player(global_position + dir * 22.0, dir, throw_spd, current_modifier)

var ball_tex: Texture2D = preload("res://Assets/Ball.png")
var slime_ball_tex: Texture2D = preload("res://Assets/SlimeBall.png")
var tennis_ball_tex: Texture2D = preload("res://Assets/TennisBall.png")
var bowling_ball_tex: Texture2D = preload("res://Assets/Modifier_BOWLINGball.png")

func update_ball_visuals() -> void:
	held_ball_sprite.visible = has_ball
	if not has_ball:
		return
	if current_modifier == 0:
		held_ball_sprite.texture = slime_ball_tex
		held_ball_sprite.scale = Vector2(0.38, 0.38)
		held_ball_sprite.modulate = Color.WHITE
	elif current_modifier == 1:
		held_ball_sprite.texture = ball_tex
		held_ball_sprite.scale = Vector2(0.38, 0.38)
		held_ball_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
	elif current_modifier == 2:
		held_ball_sprite.texture = tennis_ball_tex
		held_ball_sprite.scale = Vector2(0.24, 0.24)
		held_ball_sprite.modulate = Color.WHITE
	elif current_modifier == 3:
		held_ball_sprite.texture = bowling_ball_tex
		held_ball_sprite.scale = Vector2(0.48, 0.48)
		held_ball_sprite.modulate = Color.WHITE
	else:
		held_ball_sprite.texture = ball_tex
		held_ball_sprite.scale = Vector2(0.38, 0.38)
		held_ball_sprite.modulate = Color.WHITE

func take_damage(amount: int = 1) -> void:
	if is_invulnerable:
		return
	
	health = maxi(0, health - amount)
	bounce_back_streak = 0
	health_changed.emit(health)
	play_sfx(0.45)
	
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(10.0, 0.25)

	is_invulnerable = true
	invulnerable_timer = 1.0

	if health <= 0:
		die()

func die() -> void:
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	animated_sprite.visible = false
	held_ball_sprite.visible = false
	aim_reticle.visible = false
	player_died.emit()
