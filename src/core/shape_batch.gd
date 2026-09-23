class_name ShapeBatch
extends MultiMeshInstance2D
## Draws many copies of one mesh in a single draw call.
## Usage per frame: begin() -> add() xN -> commit().

const STRIDE := 12  # 8 floats transform + 4 floats color

var _buf := PackedFloat32Array()
var _n := 0
var _cap := 0


func setup(mesh: Mesh, capacity: int) -> ShapeBatch:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	# instances move every frame; skip bounds computation/culling entirely
	multimesh.custom_aabb = AABB(Vector3(-1e6, -1e6, -1.0), Vector3(2e6, 2e6, 2.0))
	material = Shapes.get_add_material()
	_resize(capacity)
	return self


func _resize(capacity: int) -> void:
	_cap = capacity
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	_buf.resize(capacity * STRIDE)


func begin() -> void:
	_n = 0


func add(x: float, y: float, rot: float, scl: float, c: Color) -> void:
	if _n >= _cap:
		var old := _buf
		_resize(_cap * 2)
		for i in old.size():
			_buf[i] = old[i]
	var cs := cos(rot) * scl
	var sn := sin(rot) * scl
	var o := _n * STRIDE
	_buf[o] = cs
	_buf[o + 1] = -sn
	_buf[o + 2] = 0.0
	_buf[o + 3] = x
	_buf[o + 4] = sn
	_buf[o + 5] = cs
	_buf[o + 6] = 0.0
	_buf[o + 7] = y
	_buf[o + 8] = c.r
	_buf[o + 9] = c.g
	_buf[o + 10] = c.b
	_buf[o + 11] = c.a
	_n += 1


## Stretched instance (for streak particles): length along the rotation axis, thickness across.
func add_stretched(x: float, y: float, rot: float, sx: float, sy: float, c: Color) -> void:
	add(x, y, rot, 1.0, c)
	var o := (_n - 1) * STRIDE
	_buf[o] *= sx
	_buf[o + 4] *= sx
	_buf[o + 1] *= sy
	_buf[o + 5] *= sy


func commit() -> void:
	multimesh.buffer = _buf
	multimesh.visible_instance_count = _n
