extends Node2D

export var endpoints := false

onready var _samples := $samples
onready var _points := $points

func _ready() -> void:
	_points.set_points(_samples_cast())

func _samples_cast() -> Dictionary:
	var points := {}
	for sample in _samples.get_children():
		var rays: Node2D = sample.get_node('rays')
		for ray in rays.get_children():
			var ray_points: Dictionary = ray.cast(endpoints)
			for node in ray_points:
				if not points.has(node):
					points[node] = []
				points[node].append_array(ray_points[node])
	return points
