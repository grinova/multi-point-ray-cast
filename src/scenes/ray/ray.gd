tool
extends Line2D
class_name Ray

export var _cast_to := Vector2(50, 0) setget set_cast_to, get_cast_to

func set_cast_to(cast_to: Vector2) -> void:
	_cast_to = cast_to
	points[1] = _cast_to

func get_cast_to() -> Vector2:
	return _cast_to

func cast() -> Dictionary:
	var begin_pos: Vector2 = position + points[0].rotated(rotation)
	var end_pos: Vector2 = position + points[1].rotated(rotation)
	var space_state := get_world_2d().get_direct_space_state()
	var points := MultipointRayCastCast.intersect(begin_pos, end_pos, [self], space_state)
	return points
