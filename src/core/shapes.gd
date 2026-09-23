class_name Shapes
extends RefCounted
## Neon shape generator. Meshes are white; tint them with modulate / instance color.
## Every shape = soft outer glow + bright outline + faint fill, drawn additively.

const CIRCLE_SIDES := 18

static var _mesh_cache := {}
static var add_material: CanvasItemMaterial
static var low_quality := false


static func get_add_material() -> CanvasItemMaterial:
	if add_material == null:
		add_material = CanvasItemMaterial.new()
		add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return add_material


## Outline points. sides: 0 = circle, >=3 = regular polygon, <0 = star with |sides| points.
static func points(sides: int, radius: float, angle := -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if sides < 0:
		var n := -sides
		for i in n * 2:
			var r := radius if i % 2 == 0 else radius * 0.48
			var a := angle + TAU * i / (n * 2)
			pts.append(Vector2(cos(a), sin(a)) * r)
		return pts
	var count := CIRCLE_SIDES if sides == 0 else sides
	for i in count:
		var a := angle + TAU * i / count
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


## Cross ("+") outline for heal pickups.
static func cross_points(size: float) -> PackedVector2Array:
	var a := size * 0.33
	var b := size
	return PackedVector2Array([
		Vector2(-a, -b), Vector2(a, -b), Vector2(a, -a), Vector2(b, -a), Vector2(b, a), Vector2(a, a),
		Vector2(a, b), Vector2(-a, b), Vector2(-a, a), Vector2(-b, a), Vector2(-b, -a), Vector2(-a, -a)])


static func poly_mesh(sides: int, radius: float, width := 3.0, glow := 7.0, fill := 0.14, angle := -PI / 2.0) -> ArrayMesh:
	var key := "p%d_%.1f_%.1f_%.1f_%.2f_%.2f_%s" % [sides, radius, width, glow, fill, angle, low_quality]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := outline_mesh(points(sides, radius, angle), width, glow, fill)
	_mesh_cache[key] = mesh
	return mesh


## Thin glowing streak used for particles, pointing along +X, length 1 (scale it).
static func streak_mesh() -> ArrayMesh:
	if _mesh_cache.has("streak"):
		return _mesh_cache["streak"]
	var pts := PackedVector2Array([Vector2(-6, 0), Vector2(0, -1.6), Vector2(6, 0), Vector2(0, 1.6)])
	var mesh := outline_mesh(pts, 1.5, 3.0, 0.9)
	_mesh_cache["streak"] = mesh
	return mesh


## Builds outline + glow + fill mesh around an arbitrary closed outline (must be star-shaped from origin).
static func outline_mesh(pts: PackedVector2Array, width: float, glow: float, fill: float) -> ArrayMesh:
	if low_quality:
		glow = 0.0
	var n := pts.size()
	# Make winding counter-clockwise so miter normals point outward.
	var area := 0.0
	for i in n:
		var p := pts[i]
		var q := pts[(i + 1) % n]
		area += p.x * q.y - q.x * p.y
	if area < 0.0:
		pts.reverse()
	var miters := PackedVector2Array()
	miters.resize(n)
	for i in n:
		var prev := pts[(i - 1 + n) % n]
		var cur := pts[i]
		var nxt := pts[(i + 1) % n]
		var e1 := (cur - prev).normalized()
		var e2 := (nxt - cur).normalized()
		var n1 := Vector2(e1.y, -e1.x)
		var n2 := Vector2(e2.y, -e2.x)
		var m := (n1 + n2).normalized()
		var d := maxf(m.dot(n1), 0.35)
		miters[i] = m / d
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var hw := width * 0.5
	# fill fan
	if fill > 0.0:
		verts.append(Vector2.ZERO)
		cols.append(Color(1, 1, 1, fill * 0.5))
		for i in n:
			verts.append(pts[i] - miters[i] * hw)
			cols.append(Color(1, 1, 1, fill))
		for i in n:
			idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	_strip(verts, cols, idx, pts, miters, -hw, 1.0, hw, 1.0)
	if glow > 0.0:
		_strip(verts, cols, idx, pts, miters, hw, 0.4, hw + glow, 0.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func _strip(verts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, pts: PackedVector2Array,
		miters: PackedVector2Array, off_a: float, alpha_a: float, off_b: float, alpha_b: float) -> void:
	var n := pts.size()
	var start := verts.size()
	for i in n:
		verts.append(pts[i] + miters[i] * off_a)
		cols.append(Color(1, 1, 1, alpha_a))
		verts.append(pts[i] + miters[i] * off_b)
		cols.append(Color(1, 1, 1, alpha_b))
	for i in n:
		var a := start + i * 2
		var b := start + ((i + 1) % n) * 2
		idx.append_array([a, a + 1, b + 1, a, b + 1, b])


# ---------------------------------------------------------------- immediate-mode helpers (for few, unique shapes)

static func draw_neon_poly(ci: CanvasItem, pts: PackedVector2Array, color: Color, width := 3.0, fill := 0.0) -> void:
	if fill > 0.0:
		ci.draw_colored_polygon(pts, Color(color, fill))
	var closed := pts.duplicate()
	closed.append(pts[0])
	if not low_quality:
		ci.draw_polyline(closed, Color(color, 0.22), width * 3.2)
	ci.draw_polyline(closed, color, width)


static func draw_neon_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 3.0) -> void:
	if not low_quality:
		ci.draw_line(a, b, Color(color, 0.22), width * 3.2)
	ci.draw_line(a, b, color, width)


static func draw_neon_polyline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width := 3.0) -> void:
	if not low_quality:
		ci.draw_polyline(pts, Color(color, 0.22), width * 3.2)
	ci.draw_polyline(pts, color, width)


static func draw_neon_ring(ci: CanvasItem, center: Vector2, radius: float, color: Color, width := 3.0, segs := 40) -> void:
	if not low_quality:
		ci.draw_arc(center, radius, 0.0, TAU, segs, Color(color, 0.2), width * 3.5)
	ci.draw_arc(center, radius, 0.0, TAU, segs, color, width)
