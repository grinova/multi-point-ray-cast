extends Node2D

const AUTO_RAY_RADIUS := 50.0
const AUTO_RAY_ROTATION_STEP := 0.2 * PI

export var autorotation := true

onready var _ray := $'ray'
onready var _points := $'points'
onready var _rectangle_a := $'static-body/rectangle-a'

onready var AUTO_RAY_POSITION: Vector2 = _ray.position

var _auto_ray_rotation := 0.0

func _ready() -> void:
	_cast()

func _physics_process(delta: float) -> void:
	if autorotation:
		_auto_ray_rotation += AUTO_RAY_ROTATION_STEP * delta
		_ray.position = AUTO_RAY_POSITION
		_ray.points[1] = Vector2(AUTO_RAY_RADIUS, 0.0).rotated(_auto_ray_rotation)
		_cast()

func _unhandled_input(event: InputEvent) -> void:
	if not autorotation and event is InputEventMouseMotion:
		_ray.position = AUTO_RAY_POSITION
		_ray.points[1] = to_global(get_global_mouse_position()) - _ray.position
		_cast()

func _cast() -> void:
	var begin_pos: Vector2 = _ray.position + _ray.points[0]
	var end_pos: Vector2 = _ray.position + _ray.points[1]
	_points.set_points(MultipointRayCast.intersect(begin_pos, end_pos, [self], get_world_2d().get_direct_space_state()))
