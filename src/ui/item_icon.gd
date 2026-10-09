class_name ItemIcon
extends Control
## Geometric icon for an item: an outer shape plus a unique inner glyph.
## Weapons gain a side per level (Lv1 triangle ... Lv6+ octagon); a weapon in its level-10 form becomes a gold star.

var kind := "weapon"
var item_id := ""
var level := 1
var evolved := false
var color := Balance.C_WEAPON


func _init(p_kind := "weapon", p_id := "", p_level := 1, p_evolved := false, size := 72.0) -> void:
	kind = p_kind
	item_id = p_id
	level = p_level
	evolved = p_evolved
	custom_minimum_size = Vector2(size, size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = icon_color(kind, evolved)


static func icon_color(k: String, evo: bool) -> Color:
	if evo:
		return Balance.C_GOLD
	match k:
		"passive":
			return Balance.C_PASSIVE
		"overclock":
			return Balance.C_OVERCLOCK
		"heal":
			return Balance.C_HEAL
	return Balance.C_WEAPON


func _draw() -> void:
	draw_icon(self, kind, item_id, level, evolved, size / 2.0, minf(size.x, size.y) * 0.4, color)


static func draw_icon(ci: CanvasItem, k: String, id: String, lv: int, evo: bool, c: Vector2, r: float, col: Color, w := 3.0) -> void:
	var tr := Transform2D(0.0, c)
	match k:
		"weapon":
			var sides := -5 if evo else clampi(lv + 2, 3, 8)
			Shapes.draw_neon_poly(ci, tr * Shapes.points(sides, r), col, w, 0.12)
			draw_glyph(ci, id, c, r * (0.34 if evo else 0.42), col)
		"passive":
			Shapes.draw_neon_poly(ci, tr * Shapes.points(4, r, 0.0), col, w, 0.1)
			draw_glyph(ci, id, c, r * 0.4, col)
		"overclock":
			Shapes.draw_neon_poly(ci, tr * Shapes.points(6, r, 0.0), col, w, 0.15)
			Shapes.draw_neon_line(ci, c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.15), col, w + 1.0)
			ci.draw_circle(c + Vector2(0, r * 0.4), w, col)
		"heal":
			Shapes.draw_neon_poly(ci, tr * Shapes.cross_points(r * 0.8), col, w, 0.15)


## Small unique symbol per item, drawn inside its frame.
static func draw_glyph(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color) -> void:
	var tr := Transform2D(0.0, c)
	var lw := maxf(1.5, r * 0.14)
	match id:
		"vertex_shot":
			ci.draw_colored_polygon(tr * Shapes.points(3, r * 0.8), col)
		"orbitals":
			for a in [0.0, PI / 2.0]:
				var d := Vector2.from_angle(a + PI / 4.0) * r
				ci.draw_line(c - d, c + d, col, lw * 1.3)
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.28, Vector2(r, r) * 0.56), col)
		"pulse_ring":
			ci.draw_arc(c, r * 0.35, 0.0, TAU, 16, col, lw)
			ci.draw_arc(c, r * 0.8, 0.0, TAU, 20, Color(col, 0.7), lw)
		"chain_arc":
			ci.draw_polyline(tr * PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(-r * 0.2, r * 0.2), Vector2(r * 0.1, -r * 0.4), Vector2(r, r * 0.6)]), col, lw)
		"area":
			ci.draw_arc(c, r * 0.8, 0.0, TAU, 20, col, lw)
			ci.draw_line(c, c + Vector2(r * 0.8, 0), col, lw)
		"cooldown":
			var pts := PackedVector2Array()
			for k in 13:
				var fx := -r + 2.0 * r * k / 12.0
				pts.append(c + Vector2(fx, sin(k / 12.0 * TAU * 1.5) * r * 0.5))
			ci.draw_polyline(pts, col, lw)
		"velocity":
			for off in [-0.35, 0.35]:
				ci.draw_polyline(tr * PackedVector2Array([Vector2(r * (off - 0.3), -r * 0.6), Vector2(r * (off + 0.3), 0), Vector2(r * (off - 0.3), r * 0.6)]), col, lw)
		"crit":
			for o in [Vector2(-0.5, -0.5), Vector2(0.5, -0.3), Vector2(-0.2, 0.2), Vector2(0.45, 0.55), Vector2(-0.55, 0.6)]:
				ci.draw_circle(c + o * r, lw * 0.9, col)
		"damage":
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.45, Vector2(r, r) * 0.9), col)
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), Color(col, 0.6), false, lw * 0.7)
		"hull":
			ci.draw_polyline(tr * _closed(Shapes.points(6, r * 0.85)), col, lw * 1.6)
		"agility":
			for off in [-0.45, 0.15]:
				ci.draw_polyline(tr * PackedVector2Array([Vector2(-r * 0.6, r * (off + 0.5)), Vector2(0, r * (off - 0.1)), Vector2(r * 0.6, r * (off + 0.5))]), col, lw * 1.3)
		"magnet":
			ci.draw_polyline(tr * PackedVector2Array([Vector2(-r * 0.6, -r * 0.8), Vector2(-r * 0.6, r * 0.2), Vector2(0, r * 0.75), Vector2(r * 0.6, r * 0.2), Vector2(r * 0.6, -r * 0.8)]), col, lw * 1.4)


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.append(p[0])
	return out
