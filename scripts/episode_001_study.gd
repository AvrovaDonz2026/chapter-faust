@tool
extends Node3D

const BEATS := [&"key_hook", &"read", &"look_up", &"shadow", &"knock", &"key", &"open"]
const BOOK_COLORS := ["765244", "444d4d", "582e39", "535038", "36434f"]
const KEY_REST := Vector3(0.34, 1.16, 0.68)

@onready var camera: Camera3D = $Camera3D
@onready var room: Node3D = $Architecture
@onready var desk: Node3D = $Desk
@onready var faust: Node3D = $Faust
@onready var threshold: Node3D = $Threshold

var palette: Dictionary = {}
var head: Node3D
var arm: Node3D
var arm_rest_rotation := Vector3.ZERO
var arm_rest_position := Vector3.ZERO
var flame: Node3D
var wick_light: OmniLight3D
var crimson_light: OmniLight3D
var door: Node3D
var shadow: Node3D
var key: Node3D
var scene_sets: Dictionary = {}
var current_scene := "study"

func _ready() -> void:
	_build_room()
	_build_desk()
	_build_faust()
	_build_threshold()
	_light_study()
	_build_alternate_scenes()
	set_scene("study")
	camera.look_at(Vector3(0.1, 1.32, -0.9))

func supports(spec: Dictionary) -> bool:
	if not StringName(str(spec.get("beat", ""))) in BEATS:
		return false
	for field in ["camera_from", "camera_to", "target_from", "target_to"]:
		var coordinates: Variant = spec.get(field)
		if not coordinates is Array or coordinates.size() != 3:
			return false
		for coordinate in coordinates:
			if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
				return false
	return true

func _vector(coordinates: Array) -> Vector3:
	return Vector3(coordinates[0], coordinates[1], coordinates[2])

func set_scene(scene_id: String) -> void:
	if scene_id.is_empty(): scene_id = "study"
	if current_scene == scene_id and scene_sets.size() > 0: return
	current_scene = scene_id if scene_sets.has(scene_id) else "study"
	for id in scene_sets:
		scene_sets[id].visible = id == current_scene
	room.visible = current_scene == "study"
	desk.visible = current_scene == "study" or current_scene == "contract"
	threshold.visible = current_scene in ["study", "contract", "threshold"]
	faust.visible = current_scene != "threshold"
	if wick_light: wick_light.light_color = Color("ffab62") if current_scene in ["study", "contract"] else Color("8da8ff")
	if crimson_light: crimson_light.light_energy = 1.5 if current_scene in ["contract", "threshold"] else 0.65

func pose(spec: Dictionary, u: float, time: float, hook_lift := 0.0, hook_turn := 0.0) -> void:
	set_scene(str(spec.get("scene", current_scene)))
	# Sample poses directly so scrubbing, pauses, and fixed-FPS renders agree.
	var beat := StringName(spec.beat)
	var ease_u := smoothstep(0.0, 1.0, u)
	var camera_u := lerpf(ease_u, smoothstep(0.0, 0.36, u), 0.73) if beat == &"shadow" else ease_u
	var knocks := 0.0
	if beat == &"knock":
		for center in [0.22, 0.39, 0.56]:
			knocks += exp(-pow((u - float(center)) * 39.0, 2.0))
	camera.position = _vector(spec.camera_from).lerp(_vector(spec.camera_to), camera_u)
	camera.position += Vector3(0.012 * sin(time * 1.9), 0.012 * cos(time * 2.1), 0.10 * knocks)
	var aim := _vector(spec.target_from).lerp(_vector(spec.target_to), ease_u)
	aim.y += 0.19 * hook_lift
	camera.look_at(aim)
	camera.fov = lerpf(float(spec.get("fov_from", 40.0)), float(spec.get("fov_to", 40.0)), camera_u) + 1.3 * knocks
	var flicker := sin(time * 15.7) * 0.08 + sin(time * 24.1) * 0.045
	flame.scale = Vector3(1.0 - flicker, 1.0 + flicker + 0.45 * hook_lift, 1.0 - flicker)
	flame.rotation.z = flicker * 0.8 - 0.40 * hook_lift
	wick_light.light_energy = 1.7 + 2.5 * flicker + 1.05 * hook_lift
	head.rotation.x = -0.20 if beat == &"read" else lerpf(-0.20, 0.08, smoothstep(0.03, 0.55, u)) if beat == &"look_up" else 0.08
	head.rotation.y = 0.0 if beat in [&"read", &"look_up"] else 0.40
	head.rotation.x += 0.015 * sin(time * 2.8)
	var hand_motion := smoothstep(0.18, 0.77, u) if beat == &"key" else 0.0
	arm.rotation.x = lerpf(arm_rest_rotation.x, -1.08, hand_motion)
	arm.rotation.z = lerpf(arm_rest_rotation.z, 0.30, hand_motion)
	arm.position = arm_rest_position + Vector3(0.0, -0.10 * hand_motion, 0.12 * hand_motion)
	key.visible = beat in [&"key_hook", &"look_up", &"key"]
	key.position = KEY_REST + Vector3(-0.08, 0.48, 0.0) * hook_lift
	if beat not in [&"key_hook", &"look_up", &"key"]:
		key.position = KEY_REST + Vector3(0.0, 0.035, 0.0)
	key.rotation = Vector3(0.42 * hook_lift, -0.42 + TAU * hook_turn, 0.70 * hook_lift)
	key.scale = Vector3.ONE * (1.0 + 0.28 * hook_lift)
	if beat == &"key":
		var pickup := smoothstep(0.65, 0.91, u)
		key.position = KEY_REST.lerp(desk.to_local(arm.to_global(Vector3(0.05, -0.82, 0.10))), pickup)
		key.rotation.z = 0.83 * pickup
	shadow.visible = beat in [&"shadow", &"knock"]
	shadow.position.x = lerpf(-0.91, 0.42, smoothstep(0.03, 0.70, u)) if beat == &"shadow" else 0.42
	shadow.position.z = -3.263
	shadow.scale.y = (lerpf(0.82, 1.04, ease_u) if beat == &"shadow" else 1.04) + 0.018 * sin(time * 3.2)
	shadow.rotation.z = knocks * 0.08
	door.rotation.y = -1.37 * smoothstep(0.11, 0.81, u) if beat == &"open" else -0.035 * knocks
	crimson_light.light_energy = (1.55 + 1.25 * ease_u if beat == &"open" else 1.1) + knocks * 0.6 + 0.11 * sin(time * 2.7)

func _build_alternate_scenes() -> void:
	var library := _pivot(self, "LibraryScene", Vector3.ZERO)
	for x in [-2.8, -1.4, 0.0, 1.4, 2.8]:
		_box(library, "LibraryShelf", Vector3(x, 1.92, -2.9), Vector3(1.12, 3.84, 0.30), "30283a")
		for y in [0.55, 1.28, 2.01, 2.74, 3.47]:
			_box(library, "Shelf", Vector3(x, y, -2.68), Vector3(1.10, 0.085, 0.56), "775044")
			for book in range(5):
				var h := 0.31 + float((book * 7 + int(x * 10)) % 5) * 0.075
				var tome := _box(library, "Tome", Vector3(x - 0.42 + book * 0.20, y + 0.08 + h * 0.5, -2.61), Vector3(0.145, h, 0.38), BOOK_COLORS[posmod(book + int(x * 10), BOOK_COLORS.size())])
				tome.rotation.z = [-0.035, 0.0, 0.025, 0.0, 0.04][book]
				_box(library, "Gilt", tome.position + Vector3(0, h * 0.29, 0.198), Vector3(0.105, 0.018, 0.012), "c1a46a", 0.08)
	for x in [-3.4, 3.4]:
		_box(library, "LibraryPillar", Vector3(x, 2.0, -2.5), Vector3(0.34, 4.0, 0.46), "57404a")
		_box(library, "PillarCap", Vector3(x, 3.88, -2.48), Vector3(0.48, 0.16, 0.58), "917052")
	_box(library, "LibraryFloor", Vector3(0, -0.05, -0.4), Vector3(7.8, 0.12, 7.0), "241f31")
	_box(library, "ReadingRug", Vector3(0, 0.02, 0.15), Vector3(4.8, 0.035, 3.3), "493344")
	_box(library, "RugBorder", Vector3(0, 0.043, 0.15), Vector3(4.45, 0.012, 2.95), "b18a62", 0.06)
	var corridor := _pivot(self, "CorridorScene", Vector3.ZERO)
	_box(corridor, "CorridorFloor", Vector3(0, -0.05, -0.4), Vector3(7.8, 0.12, 7.0), "26303b")
	for z in [-3.0, -1.3, 0.4, 2.1]:
		_box(corridor, "WindowRecess", Vector3(-3.0, 2.15, z), Vector3(0.16, 3.1, 1.22), "172333")
		_box(corridor, "WindowGlow", Vector3(-2.89, 2.15, z), Vector3(0.04, 2.76, 0.92), "607fa0", 0.48)
		for crossbar_y in [1.35, 2.15, 2.95]:
			_box(corridor, "WindowMullion", Vector3(-2.84, crossbar_y, z), Vector3(0.07, 0.045, 1.08), "34485e")
		_box(corridor, "Arch", Vector3(2.7, 2.0, z), Vector3(0.30, 3.8, 0.40), "493d48")
		_box(corridor, "ArchBase", Vector3(2.7, 0.14, z), Vector3(0.52, 0.28, 0.62), "76534b")
	_box(corridor, "CorridorCeiling", Vector3(0, 3.85, -0.45), Vector3(6.6, 0.18, 7.0), "20232f")
	_box(corridor, "RainReflection", Vector3(-0.8, 0.025, -1.4), Vector3(3.8, 0.035, 1.1), "466279", 0.32)
	for i in range(7):
		var rain := _box(corridor, "RainStreak", Vector3(-2.72, 0.035, -2.5 + i * 0.43), Vector3(0.018, 0.012, 0.38), "98b5ce", 0.18)
		rain.rotation.y = -0.18
	var contract := _pivot(self, "ContractScene", Vector3.ZERO)
	_box(contract, "MirrorWall", Vector3(-2.7, 2.1, -2.8), Vector3(0.12, 3.8, 5.8), "17202b", 0.24)
	for y in [0.8, 1.75, 2.7]:
		_box(contract, "MirrorFrame", Vector3(-2.57, y, -2.78), Vector3(0.09, 0.75, 1.88), "8d674a")
		_box(contract, "Mirror", Vector3(-2.51, y, -2.78), Vector3(0.025, 0.63, 1.72), "82909a", 0.22)
		_box(contract, "MirrorGlint", Vector3(-2.49, y + 0.18, -2.78), Vector3(0.018, 0.035, 1.40), "d9c7b5", 0.16)
	_box(contract, "ContractTable", Vector3(0.0, 1.08, -0.2), Vector3(3.0, 0.16, 1.2), "513437")
	for x in [-1.22, 1.22]:
		_box(contract, "TableLeg", Vector3(x, 0.54, -0.2), Vector3(0.16, 1.0, 0.90), "34252c")
	_box(contract, "ContractPaper", Vector3(0.0, 1.19, -0.2), Vector3(1.35, 0.025, 0.75), "c5a777", 0.04)
	_box(contract, "PaperBorder", Vector3(0.0, 1.208, -0.2), Vector3(1.26, 0.008, 0.66), "755440")
	for line in range(4):
		_box(contract, "ContractWriting", Vector3(-0.20, 1.216, -0.36 + line * 0.10), Vector3(0.64 - line * 0.06, 0.008, 0.018), "493940")
	for x in [-1.3, 1.3]:
		_taper(contract, "CandleSaucer", Vector3(x, 1.18, -0.2), 0.055, 0.15, 0.11, "b08a55", 16)
		_taper(contract, "RedCandle", Vector3(x, 1.45, -0.2), 0.48, 0.06, 0.075, "e05b55", 12)
		_oval(contract, "CandleFlame", Vector3(x, 1.72, -0.2), Vector3(0.06, 0.15, 0.055), "ffb55f", 1.0)
	var threshold_scene := _pivot(self, "ThresholdScene", Vector3.ZERO)
	_box(threshold_scene, "VoidFloor", Vector3(0, -0.08, -0.4), Vector3(8.0, 0.12, 7.0), "180f2b", 0.16)
	for i in range(9):
		var shard := _box(threshold_scene, "FloatingShard", Vector3(-3.2 + i * 0.8, 1.0 + (i % 4) * 0.55, -1.8 - (i % 3) * 0.5), Vector3(0.06, 0.9, 0.45), "b52c52", 0.65)
		shard.rotation.z = -0.3 + i * 0.17
		shard.rotation.y = -0.5 + float(i % 4) * 0.31
	for x in [-2.4, 2.4]:
		var rib := _box(threshold_scene, "PortalRib", Vector3(x, 2.0, -3.05), Vector3(0.09, 4.1, 0.17), "71314b", 0.25)
		rib.rotation.z = -0.09 if x < 0 else 0.09
	_box(threshold_scene, "PortalLintel", Vector3(0, 4.02, -3.05), Vector3(4.85, 0.12, 0.18), "71314b", 0.25)
	_box(threshold_scene, "RedPortal", Vector3(0, 2.0, -3.0), Vector3(2.7, 3.8, 0.08), "b52c52", 0.85)
	_box(threshold_scene, "PortalCore", Vector3(0, 2.0, -2.94), Vector3(1.75, 2.95, 0.035), "42152e", 0.72)
	_box(threshold_scene, "PortalHorizon", Vector3(0, 1.35, -2.91), Vector3(1.55, 0.035, 0.025), "ff6175", 1.1)
	scene_sets = {"library": library, "corridor": corridor, "contract": contract, "threshold": threshold_scene}

func _material(color_code: String, emission := 0.0) -> StandardMaterial3D:
	var id := "%s:%s" % [color_code, emission]
	if not palette.has(id):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color_code)
		mat.roughness = 0.82
		mat.metallic = 0.12 if color_code in ["e1b768", "896b4c", "b89261", "c1a46a"] else 0.0
		if emission > 0.0:
			mat.emission_enabled = true
			mat.emission = Color(color_code)
			mat.emission_energy_multiplier = emission
		palette[id] = mat
	return palette[id]

func _mesh(parent: Node3D, label: String, shape: PrimitiveMesh, at: Vector3, color: String, glow := 0.0) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	item.position = at
	shape.material = _material(color, glow)
	item.mesh = shape
	parent.add_child(item)
	return item

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, color: String, glow := 0.0) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, label, shape, at, color, glow)

func _taper(parent: Node3D, label: String, at: Vector3, height: float, top: float, bottom: float, color: String, sides := 12) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.height = height
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.radial_segments = sides
	shape.rings = 0
	return _mesh(parent, label, shape, at, color)

func _oval(parent: Node3D, label: String, at: Vector3, size: Vector3, color: String, glow := 0.0) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 12
	shape.rings = 6
	var item := _mesh(parent, label, shape, at, color, glow)
	item.scale = size
	return item

func _pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var item := Node3D.new()
	item.name = label
	item.position = at
	parent.add_child(item)
	return item

func _build_room() -> void:
	_box(room, "Floor", Vector3(0, -0.09, 0), Vector3(8.2, 0.16, 9), "403032")
	_box(room, "BackWallInset", Vector3(0.05, 2.24, -3.20), Vector3(3.0, 3.60, 0.05), "39333f")
	_box(room, "WallPanelTop", Vector3(0.05, 3.75, -3.15), Vector3(3.1, 0.10, 0.08), "78635a")
	for x in [-1.43, 1.53]:
		_box(room, "WallPanelSide", Vector3(x, 2.2, -3.15), Vector3(0.08, 3.0, 0.08), "78635a")
	_box(room, "WallPanelBottom", Vector3(0.05, 0.72, -3.15), Vector3(3.1, 0.10, 0.08), "78635a")
	for i in range(17):
		_box(room, "Floorboard", Vector3(-4.0 + i * 0.50, -0.01, 0), Vector3(0.484, 0.032, 9), ["433438", "48383b", "4d3c3e"][i % 3])
	_box(room, "WestWall", Vector3(-4.10, 2.32, -0.5), Vector3(0.2, 4.8, 6.0), "424556")
	_box(room, "EastWall", Vector3(4.10, 2.32, -0.5), Vector3(0.2, 4.8, 6.0), "353849")
	_box(room, "BackWallWest", Vector3(-1.73, 2.32, -3.44), Vector3(4.74, 4.8, 0.35), "585460")
	_box(room, "BackWallEast", Vector3(3.01, 2.32, -3.44), Vector3(2.31, 4.8, 0.35), "494654")
	_box(room, "LintelWall", Vector3(1.32, 3.92, -3.44), Vector3(1.4, 1.6, 0.35), "56515c")
	for x in [-3.64, -1.93, 0.42, 2.34, 3.67]:
		_box(room, "VerticalTrim", Vector3(x, 2.15, -3.21), Vector3(0.12, 4.3, 0.14), "2e2831")
	for x in [-4.0, 4.0]:
		_box(room, "SideBeam", Vector3(x, 0.79, -0.3), Vector3(0.20, 0.14, 6.0), "38292f")
	var shelves := _pivot(room, "Bookcase", Vector3(-2.84, 0, -2.87))
	_box(shelves, "Back", Vector3(0, 1.66, -0.20), Vector3(1.46, 3.30, 0.15), "271f28")
	for x in [-0.73, 0.73]:
		_box(shelves, "Upright", Vector3(x, 1.69, 0), Vector3(0.12, 3.35, 0.59), "57404a")
	for row in range(5):
		var y := 0.36 + row * 0.68
		_box(shelves, "Shelf", Vector3(0, y, 0), Vector3(1.46, 0.09, 0.56), "654b4d")
		if row < 4:
			for book in range(9):
				if (row + book) % 7 == 0:
					continue
				var h := 0.25 + ((row * 3 + book * 7) % 5) * 0.061
				var pos := Vector3(-0.58 + book * 0.145, y + 0.05 + h / 2, 0.04)
				_box(shelves, "Spine", pos, Vector3(0.122, h, 0.36), BOOK_COLORS[(row + book) % BOOK_COLORS.size()])
				_box(shelves, "Gilt", pos + Vector3(0, h * 0.25, 0.184), Vector3(0.096, 0.012, 0.01), "917052")

func _build_desk() -> void:
	_box(desk, "DeskTop", Vector3(-0.29, 1.04, 0.35), Vector3(2.83, 0.16, 1.38), "654438")
	_box(desk, "DeskInlay", Vector3(-0.29, 1.125, 0.35), Vector3(2.62, 0.012, 1.17), "98704d")
	_box(desk, "DeskWritingSurface", Vector3(-0.29, 1.135, 0.35), Vector3(2.54, 0.012, 1.09), "564044")
	_box(desk, "Apron", Vector3(-0.29, 0.91, 0.93), Vector3(2.66, 0.18, 0.13), "432e2e")
	for x in [-1.52, 0.94]:
		for z in [-0.19, 0.91]:
			_box(desk, "DeskLeg", Vector3(x, 0.48, z), Vector3(0.16, 0.96, 0.16), "423035")
			_box(desk, "Foot", Vector3(x, 0.055, z), Vector3(0.30, 0.08, 0.28), "35272d")
	_box(desk, "Drawer", Vector3(-0.29, 0.88, 0.98), Vector3(1.05, 0.30, 0.12), "543839")
	for x in [-0.63, 0.05]:
		_box(desk, "DrawerMolding", Vector3(x, 0.88, 1.047), Vector3(0.08, 0.19, 0.02), "8a634c")
		_oval(desk, "DrawerPull", Vector3(x, 0.88, 1.07), Vector3(0.07, 0.055, 0.035), "c19a61")
	for i in range(3):
		var closed := _pivot(desk, "ClosedBook", Vector3(-1.2, 1.16 + i * 0.099, 0.55))
		closed.rotation.y = -0.10 + 0.14 * i
		_box(closed, "Pages", Vector3.ZERO, Vector3(0.39, 0.074, 0.29), "b09a7c")
		for y in [-0.042, 0.042]:
			_box(closed, "Leather", Vector3(0, y, 0), Vector3(0.43, 0.014, 0.33), BOOK_COLORS[i])
	var book := _pivot(desk, "OpenFolio", Vector3(-0.52, 1.15, 0.27))
	book.rotation.y = -0.13
	for side in [-1, 1]:
		var page := _pivot(book, "PageBlock", Vector3(side * 0.20, 0.0, 0))
		page.rotation.z = -side * 0.09
		_box(page, "Cover", Vector3(0, -0.018, 0), Vector3(0.415, 0.025, 0.53), "492a29")
		_box(page, "Paper", Vector3(0, 0.013, 0), Vector3(0.397, 0.032, 0.50), "e5cc9e")
		for i in range(8):
			_box(page, "InkLine", Vector3(0, 0.030, -0.185 + i * 0.047), Vector3(0.27 - (i % 3) * 0.031, 0.002, 0.007), "826749")
	_taper(desk, "BrassSaucer", Vector3(0.49, 1.155, 0.18), 0.059, 0.19, 0.145, "896b4c", 20)
	_taper(desk, "SaucerWell", Vector3(0.49, 1.188, 0.18), 0.012, 0.115, 0.115, "413037", 20)
	_taper(desk, "Wax", Vector3(0.49, 1.36, 0.18), 0.36, 0.061, 0.069, "ecdcb2", 18)
	_taper(desk, "Wick", Vector3(0.49, 1.552, 0.18), 0.04, 0.01, 0.011, "281c24")
	flame = _pivot(desk, "FlameScale", Vector3(0.49, 1.63, 0.18))
	var shell := _oval(flame, "Flame", Vector3.ZERO, Vector3.ONE, "ffab4d", 1.0)
	var flame_shape := SphereMesh.new()
	flame_shape.radius = 0.046
	flame_shape.height = 0.158
	flame_shape.radial_segments = 12
	flame_shape.rings = 6
	shell.mesh = flame_shape
	_oval(flame, "FlameCore", Vector3(0, -0.022, 0.034), Vector3(0.038, 0.088, 0.023), "fff1b0", 1.2)
	wick_light = _omni(desk, "Candlelight", Vector3(0.49, 1.70, 0.24), Color("ffab62"), 1.7, 4.2, true)
	key = _pivot(desk, "BrassKey", KEY_REST)
	key.rotation.y = -0.42
	var ring := TorusMesh.new()
	ring.inner_radius = 0.062
	ring.outer_radius = 0.099
	ring.rings = 16
	ring.ring_segments = 12
	_mesh(key, "Bow", ring, Vector3(-0.125, 0, 0), "e1b768", 0.12)
	var inset := TorusMesh.new()
	inset.inner_radius = 0.040
	inset.outer_radius = 0.052
	inset.rings = 16
	inset.ring_segments = 8
	_mesh(key, "BowInset", inset, Vector3(-0.125, 0, 0.002), "584631")
	_box(key, "Shaft", Vector3(0.064, 0, 0), Vector3(0.26, 0.044, 0.036), "e1b768", 0.12)
	_box(key, "ShaftCollar", Vector3(0.0, 0, 0), Vector3(0.07, 0.064, 0.046), "c1a46a")
	for x in [0.155, 0.225]:
		_box(key, "Tooth", Vector3(x, -0.017, 0.035), Vector3(0.038, 0.070, 0.066), "e1b768", 0.12)
	key.hide()

func _build_faust() -> void:
	_taper(faust, "Coat", Vector3(0, 1.28, 0), 1.34, 0.39, 0.56, "242938", 11)
	_oval(faust, "Shoulders", Vector3(0, 1.77, 0.026), Vector3(1.06, 0.43, 0.60), "333443")
	_box(faust, "LeftLapel", Vector3(-0.15, 1.77, 0.32), Vector3(0.19, 0.58, 0.045), "786056").rotation.z = -0.42
	_box(faust, "RightLapel", Vector3(0.15, 1.77, 0.32), Vector3(0.19, 0.58, 0.045), "786056").rotation.z = 0.42
	_taper(faust, "Collar", Vector3(0, 1.93, 0.045), 0.21, 0.244, 0.34, "5d4a4b", 9)
	_box(faust, "CoatClosure", Vector3(0, 1.48, 0.378), Vector3(0.03, 0.42, 0.029), "876651")
	head = _pivot(faust, "HeadPivot", Vector3(0, 2.00, 0.047))
	_oval(head, "Head", Vector3(0, 0.26, 0), Vector3(0.43, 0.59, 0.42), "856259")
	_oval(head, "HairCap", Vector3(0, 0.45, -0.045), Vector3(0.48, 0.38, 0.44), "302b36")
	_oval(head, "SideburnLeft", Vector3(-0.19, 0.28, 0.075), Vector3(0.12, 0.33, 0.19), "302b36")
	_oval(head, "SideburnRight", Vector3(0.19, 0.28, 0.075), Vector3(0.12, 0.33, 0.19), "302b36")
	_oval(head, "Nose", Vector3(0, 0.22, 0.218), Vector3(0.105, 0.153, 0.135), "a07862")
	_oval(head, "Beard", Vector3(0, 0.036, 0.139), Vector3(0.326, 0.40, 0.25), "423740")
	_oval(head, "BeardPoint", Vector3(0, -0.13, 0.13), Vector3(0.20, 0.25, 0.20), "423740")
	_oval(head, "MoustacheLeft", Vector3(-0.075, 0.14, 0.235), Vector3(0.16, 0.08, 0.09), "423740")
	_oval(head, "MoustacheRight", Vector3(0.075, 0.14, 0.235), Vector3(0.16, 0.08, 0.09), "423740")
	for x in [-0.109, 0.109]:
		var brow := _box(head, "Brow", Vector3(x, 0.317, 0.195), Vector3(0.115, 0.035, 0.04), "392e37")
		brow.rotation.z = signf(x) * 0.12
		_oval(head, "Eye", Vector3(x, 0.278, 0.195), Vector3(0.06, 0.021, 0.026), "bb9377")
	for side in [-1, 1]:
		var sleeve := _pivot(faust, "ArmPivot", Vector3(0.34 * side, 1.68, 0.09))
		sleeve.rotation.x = -0.63
		sleeve.rotation.z = side * 0.12
		_taper(sleeve, "Sleeve", Vector3(0, -0.37, 0), 0.69, 0.17, 0.12, "363341", 9)
		_taper(sleeve, "Cuff", Vector3(0, -0.72, 0), 0.09, 0.115, 0.102, "735956", 9)
		_oval(sleeve, "Hand", Vector3(0, -0.83, 0), Vector3(0.16, 0.23, 0.13), "aa836a")
		if side == 1:
			arm = sleeve
			arm_rest_rotation = sleeve.rotation
			arm_rest_position = sleeve.position

func _build_threshold() -> void:
	_box(threshold, "PassageDark", Vector3(0, 1.55, -0.84), Vector3(1.64, 3.1, 0.16), "210d1e", 0.21)
	for x in [-0.71, 0.71]:
		_box(threshold, "Jamb", Vector3(x, 1.53, 0.025), Vector3(0.18, 3.05, 0.27), "48333f")
		_box(threshold, "CrimsonSeam", Vector3(x * 0.9, 1.53, -0.04), Vector3(0.047, 3.02, 0.048), "bb2945", 0.74)
	_box(threshold, "Transom", Vector3(0, 3.05, 0.032), Vector3(1.67, 0.17, 0.29), "44323f")
	_box(threshold, "CrimsonLintel", Vector3(0, 2.984, -0.035), Vector3(1.29, 0.05, 0.046), "a32345", 0.65)
	_box(threshold, "Sill", Vector3(0, 0.05, 0.0), Vector3(1.52, 0.095, 0.43), "8a3b4c", 0.10)
	door = _pivot(threshold, "DoorHinge", Vector3(-0.62, 0, -0.03))
	_box(door, "DoorLeaf", Vector3(0.62, 1.51, 0), Vector3(1.24, 2.87, 0.12), "3f272c")
	for i in range(5):
		_box(door, "DoorPlank", Vector3(0.14 + i * 0.24, 1.52, 0.07), Vector3(0.22, 2.79, 0.05), ["4c2e34", "543039", "5c353d"][i % 3])
	for y in [0.57, 2.56]:
		_box(door, "Strap", Vector3(0.61, y, 0.105), Vector3(1.18, 0.12, 0.027), "271e2b")
	_oval(door, "Knob", Vector3(1.08, 1.33, 0.15), Vector3(0.115, 0.115, 0.13), "b89261")
	# Flat geometry hugs the wall to keep the supernatural shadow art-directed.
	shadow = _pivot(room, "WallShadow", Vector3(0.42, 0.22, -3.243))
	_taper(shadow, "ShadowCloak", Vector3(0, 1.05, 0), 1.9, 0.16, 0.56, "171326", 7).scale.z = 0.025
	_oval(shadow, "ShadowHead", Vector3(0.08, 2.11, 0.009), Vector3(0.41, 0.60, 0.033), "171326")
	_box(shadow, "ShadowReach", Vector3(-0.21, 1.53, 0.008), Vector3(0.71, 0.105, 0.022), "171326").rotation.z = 0.46
	shadow.hide()
	crimson_light = _omni(threshold, "CrimsonSpill", Vector3(0.33, 1.22, 0.36), Color("e83f63"), 1.1, 3.4, false)

func _omni(parent: Node3D, label: String, at: Vector3, color: Color, energy: float, reach: float, shadows: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = shadows
	parent.add_child(light)
	return light

func _light_study() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("231b2a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9a7c9")
	environment.ambient_light_energy = 0.40
	world.environment = environment
	add_child(world)
	_omni(self, "MoonFill", Vector3(-2.96, 3.66, 1.3), Color("999fda"), 1.24, 8.5, false)
	_omni(self, "WarmDeskFill", Vector3(0.08, 2.5, 1.95), Color("ffb380"), 0.76, 5.3, false)
