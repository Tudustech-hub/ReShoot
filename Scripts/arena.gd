extends Node2D

@export var ball_scene: PackedScene = preload("res://scenes/dodgeball.tscn")
@export var turret_scene: PackedScene = preload("res://scenes/turret.tscn")
@export var modifier_scene: PackedScene = preload("res://scenes/modifier.tscn")

@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var ball_container: Node2D = $BallContainer
@onready var turret_container: Node2D = $TurretContainer
@onready var ball_spawn_timer: Timer = $BallSpawnTimer

var current_wave: int = 1
var wave_active: bool = false
var turrets_in_wave: int = 0

var turret_spots: Array[Vector2] = [
	Vector2(576, 100),
	Vector2(320, 110),
	Vector2(832, 110),
	Vector2(160, 160),
	Vector2(992, 160),
	Vector2(576, 180)
]

func _ready() -> void:
	player.health_changed.connect(hud.update_health)
	player.ball_status_changed.connect(hud.update_ball_status)
	player.dash_status_changed.connect(hud.update_dash)
	player.modifier_changed.connect(hud.update_modifier)
	player.player_died.connect(hud.show_game_over)

	spawn_initial_balls(3)
	hud.update_round(1)
	await hud.announce_round(1)
	await hud.play_countdown()
	start_wave(1)

var current_turret_modifier: int = -1

func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	wave_active = true
	hud.update_round(wave_num)

	for child in turret_container.get_children():
		child.queue_free()

	var count: int = mini(2 + (wave_num - 1), turret_spots.size())
	turrets_in_wave = count

	var spots := turret_spots.duplicate()
	spots.shuffle()

	var mod_assignments: Array[int] = []
	if current_turret_modifier != -1:
		var num_modified: int = clampi(ceili(count / 2.0), 1, count - 1)
		for i in range(count):
			mod_assignments.append(current_turret_modifier if i < num_modified else -1)
		mod_assignments.shuffle()
	else:
		for i in range(count):
			mod_assignments.append(-1)

	for i in range(count):
		var turret := turret_scene.instantiate() as Turret
		turret_container.add_child(turret)
		turret.global_position = spots[i]
		turret.ball_speed = 360.0 + (wave_num * 25.0)
		turret.fire_rate = maxf(1.4, 2.8 - (wave_num * 0.25))
		turret.set_modifier(mod_assignments[i])
		turret.turret_destroyed.connect(_on_turret_destroyed)

func _on_turret_destroyed(_turret: Turret) -> void:
	turrets_in_wave -= 1
	if turrets_in_wave <= 0 and wave_active:
		wave_active = false
		get_tree().create_timer(0.6).timeout.connect(_on_wave_cleared)

func _on_wave_cleared() -> void:
	current_turret_modifier = await hud.choose_random_modifier()
	hud.update_modifier(current_turret_modifier)

	var balls := ball_container.get_tree().get_nodes_in_group("dodgeballs")
	if balls.size() < 2:
		spawn_initial_balls(2)

	var next_round := current_wave + 1
	await hud.announce_round(next_round)
	start_wave(next_round)

func spawn_initial_balls(count: int) -> void:
	var center_positions := [
		Vector2(576, 360),
		Vector2(480, 360),
		Vector2(672, 360),
		Vector2(384, 360),
		Vector2(768, 360)
	]
	for i in range(mini(count, center_positions.size())):
		var ball := ball_scene.instantiate() as Dodgeball
		ball_container.add_child(ball)
		ball.global_position = center_positions[i]
		ball.set_inert()

func _on_ball_spawn_timer_timeout() -> void:
	var balls := ball_container.get_tree().get_nodes_in_group("dodgeballs")
	if balls.size() < 3 and not player.has_ball:
		var ball := ball_scene.instantiate() as Dodgeball
		ball_container.add_child(ball)
		var spawn_x := randf_range(200, 950)
		var spawn_y := randf_range(280, 560)
		ball.global_position = Vector2(spawn_x, spawn_y)
		if current_turret_modifier != -1 and randf() < 0.4:
			ball.ball_type = current_turret_modifier
		ball.set_inert()
