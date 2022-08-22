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
		if node is CollisionPolygon2D:
			points[node] = intersect_polygon(begin_pos, end_pos, node, eps)
		elif node is CollisionShape2D:
			points[node] = intersect_shape(begin_pos, end_pos, node, eps)
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
	elif shape is CircleShape2D:
		return intersect_circle(begin_pos, end_pos, node, shape, eps)
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
	shape: CircleShape2D,
	eps: float
) -> Array:
	var center: Vector2 = node.global_position
	var radius := shape.radius
	var intersection := _line_circle_intersection(begin_pos, end_pos, center, radius, eps)
	var points := []
	var p3 := begin_pos
	var p4 := end_pos
	for i in range(intersection.size() - 1, -1, -1):
		if not _segment_has_point(intersection[i], begin_pos, end_pos):
			intersection.remove(i)
	if intersection.size() == 2:
		var p1: Vector2 = intersection[0]
		var p2: Vector2 = intersection[1]
		if _squared_length(p1, p3) >= _squared_length(p2, p3):
			var t := p1
			p1 = p2
			p2 = t
		points.push_back({ 'p': p1, 's': 1.0 })
		points.push_back({ 'p': p2, 's': -1.0 })
	elif intersection.size() == 1:
		var p: Vector2 = intersection[0]
		var squared_radius: = radius * radius
		if _squared_length(p3, center) > squared_radius:
			points.push_back({ 'p': p, 's': 1.0 })
		elif _squared_length(p4, center) > squared_radius:
			points.push_back({ 'p': p, 's': -1.0 })
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

static func _line_circle_intersection(p1: Vector2, p2: Vector2, c: Vector2, r: float, eps: float) -> Array:
	var al := _a_coefficient(p1, p2)
	var bl := _b_coefficient(p1, p2)
	var aq := al * al + 1.0
	var bq := 2.0 * (al * bl - c.x - al * c.y)
	var cq := c.x * c.x - r * r + (bl - c.y) * (bl - c.y)
	var xs := _cubic_solve(aq, bq, cq, eps)
	var points := []
	if xs.size() > 1:
		for x in xs:
			var y: float = al * x + bl
			points.push_back(Vector2(x, y))
	return points

static func _side(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	var d := (p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)
	return sign(d)

static func _a_coefficient(a: Vector2, b: Vector2) -> float:
	return (a.y - b.y) / (a.x - b.x)

static func _b_coefficient(a: Vector2, b: Vector2) -> float:
	return (b.y * (a.x - b.x) - b.x * (a.y - b.y)) / (a.x - b.x)

static func _cubic_solve(a: float, b: float, c: float, eps: float) -> Array:
	var solution := []
	var D := b * b - 4.0 * a * c
	if D >= eps:
		var sqrt_D := sqrt(D)
		var double_a := 2.0 * a
		var x1 := (-b + sqrt_D) / double_a
		var x2 := (-b - sqrt_D) / double_a
		solution.push_back(x1)
		solution.push_back(x2)
	elif abs(D) < eps:
		var x := -b / (2.0 * a)
		solution.push_back(x)
	return solution

static func _segment_has_point(p: Vector2, a: Vector2, b: Vector2) -> bool:
	if a.x != b.x:
		var k := (p.x - a.x) / (b.x - a.x)
		return k >= 0.0 and k <= 1.0
	else:
		var k := (p.y - a.y) / (b.y - a.y)
		return k >= 0.0 and k <= 1.0

static func _squared_length(a: Vector2, b: Vector2) -> float:
	var dx = a.x - b.x
	var dy = a.y - b.y
	return dx * dx + dy * dy
