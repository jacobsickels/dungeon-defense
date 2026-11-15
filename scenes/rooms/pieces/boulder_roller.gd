extends Node3D
## Rolls a boulder across the room each time the room pulses. Bigger at higher levels.

const MODEL := "res://assets/third_party/kaykit/forest/Rock_1_A_Color1.gltf"
## The rock model is about 0.6 across. Scale grows with level up to MAX_SCALE.
const MIN_SCALE: float = 3.5
const MAX_SCALE: float = 6.0
const SCALE_PER_LEVEL: float = 0.1
const ROLL_TIME: float = 1.1

var _scale: float = MIN_SCALE


func set_room(room: DungeonRoom) -> void:
	_scale = clampf(MIN_SCALE + SCALE_PER_LEVEL * (room.level - 1), MIN_SCALE, MAX_SCALE)


func pulse() -> void:
	var boulder: Node3D = (load(MODEL) as PackedScene).instantiate()
	var radius := 0.3 * _scale
	boulder.scale = Vector3.ONE * _scale
	boulder.position = Vector3(-6.5, 0.0, 0.0)
	add_child(boulder)
	var tween := boulder.create_tween().set_parallel(true)
	tween.tween_property(boulder, "position:x", 6.5, ROLL_TIME)
	# Roll: one turn per 2πr of travel, about the Z axis.
	tween.tween_property(boulder, "rotation:z", -13.0 / radius, ROLL_TIME)
	tween.chain().tween_property(boulder, "scale", Vector3.ZERO, 0.2)
	tween.chain().tween_callback(boulder.queue_free)
