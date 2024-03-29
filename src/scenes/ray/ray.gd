tool
extends Node2D
class_name Ray

export var _cast_to := Vector2(16, 0) setget set_cast_to, get_cast_to
export var disabled: bool = false

onready var _line := $line
onready var _arrow := $arrow

func _ready() -> void:
	set_cast_to(_cast_to)

func set_cast_to(cast_to: Vector2) -> void:
	_cast_to = cast_to
	if is_instance_valid(_line):
		_line.points[1] = _cast_to
	if is_instance_valid(_arrow):
		_arrow.rotation = _cast_to.angle()
		_arrow.position = _cast_to

func get_cast_to() -> Vector2:
	return _line.points[1]

func cast(endpoints: bool = true) -> Dictionary:
	if disabled:
		return {}
	_line.points[1] = _cast_to
	var begin_pos: Vector2 = global_position + _line.points[0].rotated(global_rotation)
	var end_pos: Vector2 = global_position + _line.points[1].rotated(global_rotation)
	var space_state := get_world_2d().get_direct_space_state()
	var points := MultipointRayCast.intersect(begin_pos, end_pos, [self], space_state, endpoints)
	return points
