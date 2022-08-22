extends Node2D

const POINT_SIZE := Vector2(1, 1)
const NEAR_POINT_COLOR := Color(0, 1, 0)
const FAR_POINT_COLOR := Color(1, 0, 0)

var points := {} setget set_points

func set_points(ps: Dictionary) -> void:
	points = ps
	update()

func _draw() -> void:
	for node in points:
		var node_points: Array = points[node]
		for point in node_points:
			var rect := Rect2(point.p - POINT_SIZE / 2.0, POINT_SIZE)
			if point.t:
				draw_rect(rect, NEAR_POINT_COLOR)
			else:
				draw_rect(rect, FAR_POINT_COLOR)
