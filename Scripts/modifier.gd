extends Area2D
class_name ModifierPickup

enum ModifierType {
	SLIME,
	TRANSLUCENT
}

@export var modifier_type: ModifierType = ModifierType.SLIME

@onready var sprite: Sprite2D = $Sprite2D

var slime_tex: Texture2D = preload("res://Assets/Modifier_SlimeProjectiles.png")
var trans_tex: Texture2D = preload("res://Assets/Modifier_TraslucidProjectiles.png")
var base_y: float = 0.0

func _ready() -> void:
	base_y = position.y
	update_texture()
	body_entered.connect(_on_body_entered)

func set_type(type: ModifierType) -> void:
	modifier_type = type
	if is_node_ready():
		update_texture()

func update_texture() -> void:
	if modifier_type == ModifierType.SLIME:
		sprite.texture = slime_tex
	else:
		sprite.texture = trans_tex

func _process(_delta: float) -> void:
	position.y = base_y + sin(Time.get_ticks_msec() * 0.005) * 4.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("apply_modifier"):
		body.apply_modifier(modifier_type)
		queue_free()
