class_name Treat
extends Area2D
## Dog treat pickup: refills the player's dash when touched, then disappears.
## The node's origin is the centre of the treat.

signal collected


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).refill_dash()
		collected.emit()
		queue_free()
