extends Reference
class_name MultipointRayCastCast

const DEFAULT_EPS := 0.00001

static func intersect(
	begin_pos: Vector2,
	end_pos: Vector2,
	exclude: Array,
	space_state: Physics2DDirectSpaceState,
	endpoints: bool = true,
	eps: float = DEFAULT_EPS
) -> Dictionary:
	var points := {}
	var nodes := _segment_cast(begin_pos, end_pos, exclude, space_state)
	for node in nodes:
		if node is CollisionPolygon2D:
			points[node] = intersect_polygon(begin_pos, end_pos, node, eps)
		elif node is CollisionShape2D:
			points[node] = intersect_shape(begin_pos, end_pos, node, eps)
	if endpoints:
		_endpoints(begin_pos, end_pos, points)
	return points

static func intersect_shape(
	begin_pos: Vector2,
	end_pos: Vector2,
	node: CollisionShape2D,
	eps: float
) -> Array:
	var shape := node.shape
	if shape is RectangleShape2D:
		var left_top := Vector2(-shape.extents.x, -shape.extents.y)
		var right_bottom := Vector2(shape.extents.x, shape.extents.y)
		var polygon := [
			left_top,
			Vector2(right_bottom.x, left_top.y),
			right_bottom,
			Vector2(left_top.x, right_bottom.y)
		]
		return intersect_polygon_points(begin_pos, end_pos, node, polygon, eps)
	elif shape is ConvexPolygonShape2D:
		var polygon := (shape as ConvexPolygonShape2D).points
		return intersect_polygon_points(begin_pos, end_pos, node, polygon, eps)
	elif shape is CircleShape2D:
		return intersect_circle(begin_pos, end_pos, node, shape)
	return []

static func intersect_polygon(
	begin_pos: Vector2,
	end_pos: Vector2,
	node: CollisionPolygon2D,
	eps: float
) -> Array:
	return intersect_polygon_points(begin_pos, end_pos, node, node.polygon, eps)

static func intersect_polygon_points(
	begin_pos: Vector2,
	end_pos: Vector2,
	node: Node2D,
	polygon: Array,
	eps: float
) -> Array:
	var pos := node.global_position
	var rot := node.global_rotation
	begin_pos = (begin_pos - pos).rotated(-rot)
	end_pos = (end_pos - pos).rotated(-rot)
	var points := []
	for index in polygon.size():
		var next_index: int = (index + 1) % polygon.size()
		# var p1: Vector2 = pos + polygon[index].rotated(rot)
		# var p2: Vector2 = pos + polygon[next_index].rotated(rot)
		var p1: Vector2 = polygon[index]
		var p2: Vector2 = polygon[next_index]
		var p3 := begin_pos
		var p4 := end_pos
		# NOTE: Линия нулевой длины
		if p1 == p2:
			if abs((p3.x - p4.x) * (p1.y - p4.y) - (p1.x - p4.x) * (p3.y - p4.y)) < eps:
				var p := p1.rotated(rot) + pos
				points.push_back({ 'p': p, 's': 1.0 })
				points.push_back({ 'p': p, 's': -1.0 })
		# NOTE: Луч нулевой длины
		elif p3 == p4:
			if abs((p1.x - p2.x) * (p3.y - p2.y) - (p3.x - p2.x) * (p1.y - p2.y)) < eps:
				var p := p3.rotated(rot) + pos
				points.push_back({ 'p': p, 's': 1.0 })
				points.push_back({ 'p': p, 's': -1.0 })
		else:
			var intersection := _line_line_intersection(p1, p2, p3, p4, eps)
			if (
				intersection.d and
				(intersection.t >= 0.0 and intersection.t < 1.0) and
				(intersection.u >= 0.0 and intersection.u <= 1.0)
			):
				var s := _side(p1, p2, p3)
				var p: Vector2 = intersection.p
				p = p.rotated(rot) + pos
				points.push_back({ 'p': p, 's': s })
	return points

static func intersect_circle(
	begin_pos: Vector2,
	end_pos: Vector2,
	node: CollisionShape2D,
	shape: CircleShape2D
) -> Array:
	var center: Vector2 = node.global_position
	var radius := shape.radius
	var intersections := _segment_circle_intersection(begin_pos, end_pos, center, radius)
	var points := []
	if intersections.size() > 0:
		var intersection: Dictionary = intersections[0]
		if intersection.t >= 0.0 and intersection.t <= 1.0:
			points.push_back({ 'p': intersection.p, 's': -1.0 })
	if intersections.size() > 1:
		var intersection: Dictionary = intersections[1]
		if intersection.t >= 0.0 and intersection.t <= 1.0:
			points.push_back({ 'p': intersection.p, 's': 1.0 })
	return points

static func _endpoints(begin_pos: Vector2, end_pos: Vector2, points: Dictionary) -> void:
	var has_points := false
	if points.size() > 0:
		for node in points:
			has_points = points[node].size() > 0
			if has_points:
				break
	if not has_points:
		# TODO: Случай когда луч находится внутри полигона
		#  либо накладывается на одну из сторон
		pass
	else:
		for node in points:
			var node_points: Array = points[node]
			var inside := 0
			var outside := 0
			for point in node_points:
				if point.s < 0.0:
					inside += 1
				elif point.s > 0.0:
					outside += 1
			if inside > outside:
				node_points.push_back({ 'p': begin_pos, 's': 1.0 })
			elif inside < outside:
				node_points.push_back({ 'p': end_pos, 's': -1.0 })
	if OS.is_debug_build():
		for node in points:
			var inside := 0
			var outside := 0
			for point in points[node]:
				if point.s < 0.0:
					inside += 1
				elif point.s > 0.0:
					outside += 1
			if inside != outside:
				pass
			assert(inside == outside)

static func _segment_cast(
	begin_pos: Vector2,
	end_pos: Vector2,
	exclude: Array,
	space_state: Physics2DDirectSpaceState
) -> Dictionary:
	var shape := SegmentShape2D.new()
	shape.set_a(begin_pos)
	shape.set_b(end_pos)
	var query := Physics2DShapeQueryParameters.new()
	query.set_shape(shape)
	query.set_exclude(exclude)
	var hits := space_state.intersect_shape(query)
	var nodes := {}
	for hit in hits:
		var owner_id: int = hit.collider.shape_find_owner(hit.shape)
		var shape_owner: Object = hit.collider.shape_owner_get_owner(owner_id)
		if not nodes.has(shape_owner):
			nodes[shape_owner] = true
	return nodes

# https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
static func _line_line_intersection(p: Vector2, pr: Vector2, q: Vector2, qs: Vector2, eps: float) -> Dictionary:
	var r := pr - p
	var s := qs - q
	if abs(r.cross(s)) < eps:
		if abs((q - p).cross(r)) < eps:
			# NOTE: Прямые колинеарны
			return { 'd': false }
		else:
			# NOTE: Прямые паралельны и не пересекаются
			return { 'd': false }
	else:
		var t := (q - p).cross(s) / r.cross(s)
		var u := (q - p).cross(r) / r.cross(s)
		return { 'd': true, 't': t, 'u': u, 'p': p + t * r }
		# return { 'd': true, 't': t, 'u': u, 'p': q + u * s }

# https://stackoverflow.com/questions/1073336/circle-line-segment-collision-detection-algorithm
static func _segment_circle_intersection(p1: Vector2, p2: Vector2, center: Vector2, r: float) -> Array:
	var result := []
	var d := p2 - p1
	var f := p1 - center
	var a: float = d.dot(d)
	var b: float = 2.0 * f.dot( d )
	var c: float = f.dot(f) - r * r
	# FIXME: Деление на ноль при a = 0
	var ts := _cubic_solve(a, b, c)
	for t in ts:
		var p: Vector2 = d * t + p1
		result.push_back({ 't': t, 'p': p })
	return result

static func _side(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	var d := (p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)
	return sign(d)

static func _cubic_solve(a: float, b: float, c: float) -> Array:
	var solution := []
	var D := b * b - 4.0 * a * c
	if D >= 0.0:
		var sqrt_D := sqrt(D)
		var x1 := (-b + sqrt_D) / (2.0 * a)
		var x2 := (-b - sqrt_D) / (2.0 * a)
		solution.push_back(x1)
		solution.push_back(x2)
	return solution
