extends Node2D

const RECTANGLE_MAX_EXTENTS := Vector2(16.0, 32.0)
const CIRCLE_MAX_RADIUS := 32.0
const ROTATION_CONE := 30.0 / 180.0 * PI
const ROTATION_STEP := 1.0

enum ShapeType {
	RECTANGLE,
	CIRCLE,
	CAPSULE
}

export(ShapeType) var shape_type := ShapeType.RECTANGLE
export var N := 1000

onready var _body := $'static-body'
onready var _ray := $ray
onready var _points := $points

var _rotation_dir := 1.0

func _ready() -> void:
	randomize()
	for _i in N:
		var collision := _collision_factory()
		_body.add_child(collision)

func _physics_process(delta: float) -> void:
	_ray.rotation += _rotation_dir * ROTATION_STEP * delta
	if _ray.rotation > ROTATION_CONE:
		_rotation_dir = -1.0
	elif _ray.rotation < -ROTATION_CONE:
		_rotation_dir = 1.0
	_ray.cast()
	# _points.set_points(_ray.cast())

func _collision_factory() -> Node2D:
	match shape_type:
		ShapeType.RECTANGLE, ShapeType.CIRCLE, ShapeType.CAPSULE:
			var collision := CollisionShape2D.new()
			collision.rotation = (randf() * 2.0 - 1.0) * PI
			collision.shape = _shape_factory()
			return collision
	return null

func _shape_factory() -> Shape2D:
	match shape_type:
		ShapeType.RECTANGLE:
			return _rectangle_factory()
		ShapeType.CIRCLE:
			return _circle_factory()
	return null

func _rectangle_factory() -> RectangleShape2D:
	var rectangle := RectangleShape2D.new()
	rectangle.extents = Vector2(
		randf() * RECTANGLE_MAX_EXTENTS.x,
		randf() * RECTANGLE_MAX_EXTENTS.y
	)
	return rectangle

func _circle_factory() -> CircleShape2D:
	var circle := CircleShape2D.new()
	circle.radius = randf() * CIRCLE_MAX_RADIUS
	return circle
