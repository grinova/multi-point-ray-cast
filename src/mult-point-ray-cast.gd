extends Reference
class_name MultipointRayCastCast

const DEFAULT_EPS := 0.00001

static func intersect(
	begin_pos: Vector2,
	end_pos: Vector2,
	exclude: Array,
	space_state: Physics2DDirectSpaceState,
	eps: float = DEFAULT_EPS
) -> Dictionary:
	var points := {}
	var nodes := _segment_cast(begin_pos, end_pos, exclude, space_state)
	for node in nodes:
		var node_points := []
		if node is CollisionPolygon2D:
			node_points = intersect_polygon(begin_pos, end_pos, node, eps)
		elif node is CollisionShape2D:
			node_points = intersect_shape(begin_pos, end_pos, node, eps)
		points[node] = node_points
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
	var points := []
	for index in polygon.size():
		var next_index: int = (index + 1) % polygon.size()
		var p1: Vector2 = (
			node.global_position +
			polygon[index].rotated(node.global_rotation)
		)
		var p2: Vector2 = (
			node.global_position +
			polygon[next_index].rotated(node.global_rotation)
		)
		var p3 := begin_pos
		var p4 := end_pos
		# NOTE: Линия нулевой длины
		if p1 == p2:
			if abs((p3.x - p4.x) * (p1.y - p4.y) - (p1.x - p4.x) * (p3.y - p4.y)) < eps:
				points.push_back({ 'p': p1, 's': 1.0 })
				points.push_back({ 'p': p1, 's': -1.0 })
		# NOTE: Луч нулевой длины
		elif p3 == p4:
			if abs((p1.x - p2.x) * (p3.y - p2.y) - (p3.x - p2.x) * (p1.y - p2.y)) < eps:
				points.push_back({ 'p': p3, 's': 1.0 })
				points.push_back({ 'p': p3, 's': -1.0 })
		else:
			var intersection := _line_line_intersection(p1, p2, p3, p4, eps)
			if (
				intersection.d and
				(intersection.t >= 0.0 and intersection.t < 1.0) and
				(intersection.u >= 0.0 and intersection.u <= 1.0)
			):
				var s := _side(p1, p2, p3)
				points.push_back({ 'p': intersection.p, 's': s })
	return points

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

static func _line_line_intersection(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, eps: float) -> Dictionary:
	# NOTE: Делитель равен нулю если:
	#  - Длина хотябы одного из отрезков p1-p2, p3-p4 равна нулю
	#  - Прямые паралельны
	#  - Прямые совпадают либо одна прямая перекрывает другую
	var denominator := (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
	if abs(denominator) < eps:
		return { 'd': false }
	var t := ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denominator
	var u := ((p1.x - p3.x) * (p1.y - p2.y) - (p1.y - p3.y) * (p1.x - p2.x)) / denominator
	var p := p1 + (p2 - p1) * t
	return { 'd': true, 't': t, 'u': u, 'p': p }

static func _side(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	var d := (p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)
	return sign(d)

static func _a_coefficient(a: Vector2, b: Vector2) -> float:
	return (a.y - b.y) / (a.x - b.x)

static func _b_coefficient(a: Vector2, b: Vector2) -> float:
	return (b.y * (a.x - b.x) - b.x * (a.y - b.y)) / (a.x - b.x)
