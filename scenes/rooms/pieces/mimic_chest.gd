extends Node3D
## A treasure chest that's really a mimic. Its lid twitches now and then, and when its hazard
## hits it lunges and snaps.

const MODEL := "res://assets/third_party/kaykit/dungeon/chest.gltf"
const OPEN_ANGLE: float = -1.1

var _lid: Node3D
var _body: Node3D
var _time: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	_body = (load(MODEL) as PackedScene).instantiate()
	add_child(_body)
	_lid = _body.find_child("chest_lid", true, false)


func set_phase(phase: float) -> void:
	_phase = phase * 3.0


func _process(delta: float) -> void:
	_time += delta
	# An idle twitch: the lid lifts a crack every few seconds.
	if _lid != null and not _is_biting():
		var t := fmod(_time + _phase, 4.0)
		_lid.rotation.x = -0.15 * sin(t * 6.0) if t < 0.5 else 0.0


func trigger() -> void:
	if _lid == null:
		return
	var tween := create_tween()
	tween.tween_property(_lid, "rotation:x", OPEN_ANGLE, 0.08)
	tween.parallel().tween_property(_body, "position", Vector3(0, 0.4, 0.3), 0.08)
	tween.tween_property(_lid, "rotation:x", 0.0, 0.07)
	tween.parallel().tween_property(_body, "position", Vector3.ZERO, 0.12)
	set_meta(&"biting_until", _time + 0.2)


func _is_biting() -> bool:
	return _time < float(get_meta(&"biting_until", 0.0))
