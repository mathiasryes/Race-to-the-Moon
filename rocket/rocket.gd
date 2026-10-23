@tool
class_name Rocket
extends Node2D
## The owner's rocket. Visual only for now; the race logic (rocket vs. player speed) comes later.
## The node's origin is the bottom of the nozzle.

@export var engine_on: bool = false:
	set(value):
		engine_on = value
		if is_node_ready():
			_flame.visible = value

@onready var _flame: AnimatedSprite2D = $Flame


func _ready() -> void:
	_flame.visible = engine_on
