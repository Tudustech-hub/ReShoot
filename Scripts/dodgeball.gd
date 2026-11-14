extends CharacterBody2D
class_name Dodgeball

enum State {
	INERT,
	HAZARDOUS,
	THROWN,
	BOUNCING,
	RETURNING
}

@export var state: State = State.INERT
@export var speed: float = 420.0
@export var bounce_damping: float = 0.94
@export var max_bounces: int = 8

var current_bounces: int = 0
var shooter_node: Node = null
var return_target: Node2D = null
var active_modifier: int = -1
var ball_type: int = -1

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var pickup_area: Area2D = $PickupArea

var normal_tex: Texture2D = preload("res://Assets/Ball.png")
var slime_tex: Texture2D = preload("res://Assets/SlimeBall.png")
var tennis_tex: Texture2D = preload("res://Assets/TennisBall.png")
var bowling_tex: Texture2D = preload("res://Assets/Modifier_BOWLINGball.png")

func _ready() -> void:
	update_collision()
	apply_modifier_visuals()

func launch_from_turret(origin: Vector2, direction: Vector2, ball_speed: float, turret_source: Node, mod_type: int = -1) -> void:
	global_position = origin
	state = State.HAZARDOUS
	shooter_node = turret_source
	current_bounces = 0
	return_target = null
	active_modifier = mod_type
	ball_type = mod_type
	if active_modifier == 0:
		bounce_damping = 0.98
		max_bounces = 16
		velocity = direction.normalized() * ball_speed
	elif active_modifier == 2:
		bounce_damping = 0.992
		max_bounces = 24
		velocity = direction.normalized() * (ball_speed * 1.25)
	elif active_modifier == 3:
		bounce_damping = 0.6
		max_bounces = 5
		velocity = direction.normalized() * (ball_speed * 0.9)
	else:
		bounce_damping = 0.94
		max_bounces = 8
		velocity = direction.normalized() * ball_speed
	apply_modifier_visuals()
	update_collision()

func throw_by_player(origin: Vector2, direction: Vector2, throw_speed: float, mod_type: int = -1) -> void:
	global_position = origin
	state = State.THROWN
	shooter_node = null
	current_bounces = 0
	return_target = null
	active_modifier = mod_type
	ball_type = mod_type
	if active_modifier == 0:
		bounce_damping = 0.98
		max_bounces = 16
		velocity = direction.normalized() * throw_speed
	elif active_modifier == 2:
		bounce_damping = 0.992
		max_bounces = 24
		velocity = direction.normalized() * 780.0
	elif active_modifier == 3:
		bounce_damping = 0.6
		max_bounces = 5
		velocity = direction.normalized() * 580.0
	else:
		bounce_damping = 0.94
		max_bounces = 8
		velocity = direction.normalized() * throw_speed
	apply_modifier_visuals()
	update_collision()

func bounce_back(reflect_dir: Vector2, reflect_speed: float = 720.0, mod_type: int = -1) -> void:
	shooter_node = null
	current_bounces = 0
	return_target = null
	if mod_type != -1:
		active_modifier = mod_type
		ball_type = mod_type
	if active_modifier == 0:
		bounce_damping = 0.98
		max_bounces = 16
		velocity = reflect_dir.normalized() * reflect_speed
	elif active_modifier == 2:
		bounce_damping = 0.992
		max_bounces = 24
		velocity = reflect_dir.normalized() * 840.0
	elif active_modifier == 3:
		bounce_damping = 0.6
		max_bounces = 5
		velocity = reflect_dir.normalized() * 640.0
	else:
		bounce_damping = 0.94
		max_bounces = 8
		velocity = reflect_dir.normalized() * reflect_speed
	state = State.THROWN
	apply_modifier_visuals()
	update_collision()
	var squish_vec := Vector2(0.18, 0.36) if active_modifier == 2 else (Vector2(0.62, 0.35) if active_modifier == 3 else Vector2(0.24, 0.52))
	squish(squish_vec)

func recall_to_player(player: Node2D) -> void:
	if state == State.INERT or state == State.BOUNCING:
		state = State.RETURNING
		return_target = player
		update_collision()

func squish(squash_scale: Vector2 = Vector2.ZERO) -> void:
	if not sprite:
		return
	var orig_scale := Vector2(0.24, 0.24) if active_modifier == 2 else (Vector2(0.48, 0.48) if active_modifier == 3 else Vector2(0.38, 0.38))
	if squash_scale == Vector2.ZERO:
		squash_scale = Vector2(0.32, 0.16) if active_modifier == 2 else (Vector2(0.62, 0.35) if active_modifier == 3 else Vector2(0.5, 0.26))
	sprite.scale = squash_scale
	var tw := create_tween()
	tw.tween_property(sprite, "scale", orig_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func apply_modifier_visuals() -> void:
	if not is_node_ready():
		return
	if active_modifier == 0:
		sprite.texture = slime_tex
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(0.38, 0.38)
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = 12.0
	elif active_modifier == 1:
		sprite.texture = normal_tex
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
		sprite.scale = Vector2(0.38, 0.38)
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = 12.0
	elif active_modifier == 2:
		sprite.texture = tennis_tex
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(0.24, 0.24)
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = 8.0
	elif active_modifier == 3:
		sprite.texture = bowling_tex
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(0.48, 0.48)
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = 16.0
	else:
		sprite.texture = normal_tex
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(0.38, 0.38)
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = 12.0

func _physics_process(delta: float) -> void:
	if state == State.RETURNING:
		if is_instance_valid(return_target):
			var to_player := return_target.global_position - global_position
			velocity = to_player.normalized() * 700.0
			global_position += velocity * delta
			sprite.rotation += 20.0 * delta
			if to_player.length() < 35.0:
				if return_target.has_method("pick_up_ball") and return_target.can_pick_up_ball():
					return_target.pick_up_ball(ball_type)
					queue_free()
				else:
					set_inert()
		else:
			set_inert()
		return

	if state == State.INERT:
		velocity = Vector2.ZERO
		return

	if velocity.length() > 5.0:
		sprite.rotation += velocity.length() * delta * 0.03

	var collision := move_and_collide(velocity * delta)
	if collision:
		handle_collision(collision)

	var friction: float = 20.0 if ball_type == 2 else (70.0 if ball_type == 3 else 50.0)
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	var stop_speed: float = 40.0 if ball_type == 2 else (75.0 if ball_type == 3 else 60.0)
	if velocity.length() < stop_speed and state != State.INERT:
		set_inert()

func handle_collision(collision: KinematicCollision2D) -> void:
	var collider := collision.get_collider()
	
	if state == State.THROWN and collider and collider.is_in_group("turrets"):
		var damage_amount: int = 2 if ball_type == 3 else 1
		collider.take_damage(damage_amount)
		squish(Vector2(0.32, 0.16) if ball_type == 2 else (Vector2(0.62, 0.35) if ball_type == 3 else Vector2(0.52, 0.24)))
		if ball_type == 3:
			var cam = get_viewport().get_camera_2d()
			if cam and cam.has_method("shake"):
				cam.shake(12.0, 0.3)
		if active_modifier == 1 or active_modifier == 3:
			return
		velocity = velocity.bounce(collision.get_normal()) * 0.6
		current_bounces += 1
		state = State.BOUNCING
		update_collision()
		return

	if state == State.HAZARDOUS and collider and collider.is_in_group("player"):
		if collider.is_dashing:
			var mouse_pos := get_global_mouse_position()
			var reflect_dir := (mouse_pos - global_position).normalized()
			var mod_from_player := -1
			if collider.has_method("get_current_modifier"):
				mod_from_player = collider.get_current_modifier()
			bounce_back(reflect_dir, 740.0, mod_from_player)
			if collider.has_method("on_bounce_back_success"):
				collider.on_bounce_back_success()
			return
		else:
			collider.take_damage(1)
			set_inert()
			return

	velocity = velocity.bounce(collision.get_normal()) * bounce_damping
	squish(Vector2(0.32, 0.16) if ball_type == 2 else (Vector2(0.62, 0.35) if ball_type == 3 else Vector2(0.5, 0.26)))
	current_bounces += 1

	if ball_type == 3:
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("shake"):
			cam.shake(3.5, 0.12)

	var min_bounce_speed: float = 50.0 if ball_type == 2 else (90.0 if ball_type == 3 else 80.0)
	if current_bounces >= max_bounces or velocity.length() < min_bounce_speed:
		set_inert()
	else:
		if state == State.HAZARDOUS or state == State.THROWN:
			state = State.BOUNCING
		update_collision()

func set_inert() -> void:
	state = State.INERT
	velocity = Vector2.ZERO
	return_target = null
	if ball_type == 2 or ball_type == 3:
		active_modifier = ball_type
	else:
		active_modifier = -1
	apply_modifier_visuals()
	update_collision()

func update_collision() -> void:
	if not is_node_ready():
		return
	match state:
		State.INERT, State.RETURNING:
			collision_layer = 0
			collision_mask = 1
		State.HAZARDOUS:
			collision_layer = 4
			collision_mask = 1 + 2
		State.THROWN:
			collision_layer = 4
			collision_mask = 1 + 8
		State.BOUNCING:
			collision_layer = 4
			collision_mask = 1 + 2 + 8

func _on_pickup_area_body_entered(body: Node2D) -> void:
	if (state == State.INERT or state == State.RETURNING) and body.is_in_group("player"):
		if body.can_pick_up_ball():
			body.pick_up_ball(ball_type)
			queue_free()
