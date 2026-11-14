extends CanvasLayer

signal countdown_finished

@onready var hearts_container: HBoxContainer = $TopBar/HeartsContainer
@onready var ball_indicator: TextureRect = $TopBar/BallIndicator
@onready var modifier_indicator: TextureRect = $TopBar/ModifierIndicator
@onready var dash_bar: ProgressBar = $TopBar/DashProgressBar
@onready var round_counter: TextureRect = $TopBar/RoundHBox/RoundCounter
@onready var round_top_label: Label = $TopBar/RoundHBox/RoundTopLabel

@onready var radial_backdrop: TextureRect = $RadialGradientBackdrop

@onready var round_announce_center: CenterContainer = $RoundAnnounceCenter
@onready var logo_rect: TextureRect = $RoundAnnounceCenter/VBox/LogoRect
@onready var round_announce_label: Label = $RoundAnnounceCenter/VBox/RoundLabel

@onready var modifier_select_center: CenterContainer = $ModifierSelectCenter
@onready var mod_title: Label = $ModifierSelectCenter/Panel/Margin/VBox/ModTitle
@onready var mod_icon: TextureRect = $ModifierSelectCenter/Panel/Margin/VBox/ModIcon
@onready var mod_name: Label = $ModifierSelectCenter/Panel/Margin/VBox/ModName

@onready var countdown_center: CenterContainer = $CountdownCenter
@onready var countdown_rect: TextureRect = $CountdownCenter/CountdownRect

@onready var game_over_panel: CenterContainer = $GameOverCenter
@onready var retry_button: TextureButton = $GameOverCenter/RetryButton
@onready var pause_center: CenterContainer = $PauseCenter
@onready var resume_button: Button = $PauseCenter/Panel/Margin/VBox/ButtonVBox/ResumeButton
@onready var restart_button: Button = $PauseCenter/Panel/Margin/VBox/ButtonVBox/RestartButton
@onready var stop_button: Button = $TopBar/StopButton
@onready var tick_audio: AudioStreamPlayer = $TickAudio
@onready var roll_audio: AudioStreamPlayer = $RollAudio

var count_3: Texture2D = preload("res://Assets/3_counter.png")
var count_2: Texture2D = preload("res://Assets/2_counter.png")
var count_1: Texture2D = preload("res://Assets/1_counter.png")
var count_go: Texture2D = preload("res://Assets/GO_counter.png")

var mod_slime: Texture2D = preload("res://Assets/Modifier_SlimeProjectiles.png")
var mod_trans: Texture2D = preload("res://Assets/Modifier_TraslucidProjectiles.png")
var mod_tennis: Texture2D = preload("res://Assets/Modifier_tennisBall.png")
var mod_bowling: Texture2D = preload("res://Assets/Modifier_BOWLINGballmodifierimag.png")

var sfx_confirm: AudioStream = preload("res://Assets/Confirm.mp3")
var sfx_game_confirm: AudioStream = preload("res://Assets/Sound Game confirm.mp3")
var sfx_walk: AudioStream = preload("res://Assets/Walking2.wav")
var sfx_powerup_mod: AudioStream = preload("res://Assets/Powerup⁄newmodifier.mp3")

var is_hovered: bool = false
var is_stop_menu_open: bool = false

func _ready() -> void:
	game_over_panel.visible = false
	pause_center.visible = false
	is_stop_menu_open = false
	countdown_center.visible = false
	modifier_indicator.visible = false
	round_announce_center.visible = false
	modifier_select_center.visible = false
	radial_backdrop.visible = false
	update_round(1)

	retry_button.pivot_offset = Vector2(128, 128)
	retry_button.mouse_entered.connect(func():
		is_hovered = true
	)
	retry_button.mouse_exited.connect(func():
		is_hovered = false
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		toggle_stop_menu()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if tick_audio:
		tick_audio.stop()
		tick_audio.stream = null
	if roll_audio:
		roll_audio.stop()
		roll_audio.stream = null

func _process(_delta: float) -> void:
	if game_over_panel.visible:
		var time := Time.get_ticks_msec() * 0.005
		var pulse := sin(time) * 0.05 + (1.1 if is_hovered else 1.0)
		retry_button.scale = Vector2(pulse, pulse)
		retry_button.modulate = Color(1.25, 1.25, 1.25, 1.0) if is_hovered else Color.WHITE

func play_sfx(pitch: float = 1.0) -> void:
	if tick_audio:
		tick_audio.stream = sfx_walk
		tick_audio.pitch_scale = pitch
		tick_audio.play()

func play_confirm_sfx() -> void:
	if tick_audio:
		tick_audio.stream = sfx_confirm
		tick_audio.pitch_scale = 1.0
		tick_audio.play()

func play_game_confirm_sfx() -> void:
	if tick_audio:
		tick_audio.stream = sfx_game_confirm
		tick_audio.pitch_scale = 1.0
		tick_audio.play()

func play_powerup_modifier_sfx() -> void:
	if tick_audio:
		tick_audio.stream = sfx_powerup_mod
		tick_audio.pitch_scale = 1.0
		tick_audio.play()

func show_radial_backdrop(fade_in: bool = true) -> void:
	if not radial_backdrop:
		return
	radial_backdrop.visible = true
	if fade_in:
		radial_backdrop.modulate.a = 0.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(radial_backdrop, "modulate:a", 1.0, 0.2)
	else:
		radial_backdrop.modulate.a = 1.0

func hide_radial_backdrop(fade_out: bool = true) -> void:
	if not radial_backdrop:
		return
	if fade_out:
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(radial_backdrop, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func(): radial_backdrop.visible = false)
	else:
		radial_backdrop.visible = false
		radial_backdrop.modulate.a = 0.0

func play_countdown() -> void:
	show_radial_backdrop(true)
	countdown_center.visible = true
	var steps := [count_3, count_2, count_1, count_go]
	for i in range(steps.size()):
		countdown_rect.texture = steps[i]
		if i == steps.size() - 1:
			play_confirm_sfx()
		else:
			play_sfx(1.2 + i * 0.25)
		await get_tree().create_timer(0.48, true).timeout
	countdown_center.visible = false
	hide_radial_backdrop(true)
	countdown_finished.emit()

func update_round(round_num: int) -> void:
	if not is_node_ready():
		await ready
	round_top_label.text = "ROUND %d" % round_num
	match round_num:
		1:
			round_counter.texture = count_1
		2:
			round_counter.texture = count_2
		3:
			round_counter.texture = count_3
		_:
			round_counter.texture = count_go

func announce_round(round_num: int) -> void:
	if not is_node_ready():
		await ready
	update_round(round_num)
	show_radial_backdrop(true)
	if logo_rect:
		logo_rect.visible = (round_num == 1)
	round_announce_label.text = "ROUND %d STARTED" % round_num
	round_announce_center.visible = true
	play_confirm_sfx()

	round_announce_label.pivot_offset = round_announce_label.size / 2.0
	round_announce_label.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(round_announce_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(1.2, true).timeout
	round_announce_center.visible = false
	hide_radial_backdrop(true)

func choose_random_modifier() -> int:
	get_tree().paused = true
	show_radial_backdrop(true)
	modifier_select_center.visible = true
	mod_title.text = "TURRET MODIFIER..."
	mod_name.text = ""

	var options: Array[int] = [0, 1, 2, 3]
	var textures: Array[Texture2D] = [mod_slime, mod_trans, mod_tennis, mod_bowling]
	var names: Array[String] = ["SLIME PROJECTILES", "TRANSLUCID PROJECTILES", "TENNIS BALL PROJECTILES", "BOWLING BALL PROJECTILES"]

	var winner: int = options.pick_random()

	if roll_audio:
		roll_audio.play()

	var total_flashes: int = 16
	var current_idx: int = randi() % options.size()
	for i in range(total_flashes):
		current_idx = (current_idx + 1) % options.size()
		mod_icon.texture = textures[current_idx]
		mod_name.text = names[current_idx]
		var delay: float = 0.06 + (float(i) / float(total_flashes)) * 0.12
		await get_tree().create_timer(delay, true).timeout

	mod_icon.texture = textures[winner]
	mod_name.text = names[winner]
	mod_title.text = "TURRETS GAINED:"
	mod_icon.modulate = Color(1.35, 1.35, 1.35, 1.0)
	play_powerup_modifier_sfx()
	await get_tree().create_timer(1.2, true).timeout
	mod_icon.modulate = Color.WHITE

	modifier_select_center.visible = false
	hide_radial_backdrop(true)
	get_tree().paused = false
	return winner

func update_health(hp: int) -> void:
	if not is_node_ready():
		await ready
	for i in range(hearts_container.get_child_count()):
		var heart := hearts_container.get_child(i) as TextureRect
		if heart:
			heart.visible = (i < hp)

func update_ball_status(has_ball: bool) -> void:
	if not is_node_ready():
		await ready
	ball_indicator.modulate = Color.WHITE if has_ball else Color(0.2, 0.2, 0.2, 1.0)

func update_modifier(mod_type: int) -> void:
	if not is_node_ready():
		await ready
	if mod_type == 0:
		modifier_indicator.visible = true
		modifier_indicator.texture = mod_slime
	elif mod_type == 1:
		modifier_indicator.visible = true
		modifier_indicator.texture = mod_trans
	elif mod_type == 2:
		modifier_indicator.visible = true
		modifier_indicator.texture = mod_tennis
	elif mod_type == 3:
		modifier_indicator.visible = true
		modifier_indicator.texture = mod_bowling
	else:
		modifier_indicator.visible = false

func update_dash(progress: float) -> void:
	if not is_node_ready():
		await ready
	dash_bar.value = progress * 100.0

func toggle_stop_menu() -> void:
	if game_over_panel.visible or modifier_select_center.visible or countdown_center.visible:
		return
	if is_stop_menu_open:
		close_stop_menu()
	else:
		open_stop_menu()

func open_stop_menu() -> void:
	is_stop_menu_open = true
	get_tree().paused = true
	show_radial_backdrop(true)
	pause_center.visible = true
	resume_button.grab_focus()

func close_stop_menu() -> void:
	is_stop_menu_open = false
	pause_center.visible = false
	hide_radial_backdrop(true)
	get_tree().paused = false

func _on_stop_button_pressed() -> void:
	play_confirm_sfx()
	toggle_stop_menu()

func _on_resume_button_pressed() -> void:
	play_confirm_sfx()
	close_stop_menu()

func _on_restart_button_pressed() -> void:
	play_confirm_sfx()
	get_tree().paused = false
	get_tree().reload_current_scene()

func show_game_over() -> void:
	if is_stop_menu_open:
		close_stop_menu()
	get_tree().paused = true
	show_radial_backdrop(true)
	game_over_panel.visible = true
	play_sfx(0.4)
	retry_button.grab_focus()

func _on_retry_button_pressed() -> void:
	play_confirm_sfx()
	get_tree().paused = false
	get_tree().reload_current_scene()
