extends Node3D
## A haunted library's spellbooks, flapping in loops over the room. One more per level.

const MODEL := "res://assets/third_party/kaykit/props/spellbook_open.gltf"
const MAX_BOOKS: int = 24

var _books: Array[Node3D] = []
## Per book: orbit radius, height, speed, and phase.
var _orbits: Array[Vector4] = []
var _time: float = 0.0


func set_room(room: DungeonRoom) -> void:
	var count := mini(room.level, MAX_BOOKS)
	var scene: PackedScene = load(MODEL)
	var rng := RandomNumberGenerator.new()
	while _books.size() < count:
		var i := _books.size()
		rng.seed = i
		var book: Node3D = scene.instantiate()
		book.scale = Vector3.ONE * 1.3
		add_child(book)
		_books.append(book)
		var radius := rng.randf_range(1.5, 4.5)
		var height := rng.randf_range(1.6, 3.6)
		var speed := rng.randf_range(0.5, 1.0) * (1.0 if i % 2 == 0 else -1.0)
		_orbits.append(Vector4(radius, height, speed, rng.randf_range(0.0, TAU)))


func _process(delta: float) -> void:
	_time += delta
	for i: int in _books.size():
		var o := _orbits[i]
		var angle := o.w + _time * o.z
		var book := _books[i]
		book.position = Vector3(cos(angle) * o.x, o.y + sin(_time * 2.0 + o.w) * 0.3, sin(angle) * o.x * 0.7)
		# Face along the flight, and flap.
		book.rotation.y = -angle + (PI if o.z > 0.0 else 0.0)
		book.rotation.z = sin(_time * 9.0 + o.w) * 0.5
