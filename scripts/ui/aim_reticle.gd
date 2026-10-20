extends Control

@export var reticle_color: Color = Color(0.88, 0.96, 1.0, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 1.5, reticle_color)
	draw_line(center + Vector2(-9, 0), center + Vector2(-4, 0), reticle_color, 1.4, true)
	draw_line(center + Vector2(4, 0), center + Vector2(9, 0), reticle_color, 1.4, true)
	draw_line(center + Vector2(0, -9), center + Vector2(0, -4), reticle_color, 1.4, true)
	draw_line(center + Vector2(0, 4), center + Vector2(0, 9), reticle_color, 1.4, true)
