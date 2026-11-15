extends Node3D
## An animated sword hovering beside the path, bobbing slowly. Slashes when its hazard hits.

const MODEL := "res://assets/third_party/kaykit/props/sword_1handed.gltf"
const BOB_HEIGHT: float = 0.25
const BOB_SPEED: float = 1.6

var _sword: Node3D
var _time: float = 0.0


func _ready() -> void:
	_sword = (load(MODEL) as PackedScene).instantiate()
	add_child(_sword)
	# Point down, tilted toward the path.
	_sword.rotation = Vector3(0.35, 0.0, PI)


func set_phase(phase: float) -> void:
	_time = phase * 5.0


func _process(delta: float) -> void:
	_time += delta
	_sword.position.y = sin(_time * BOB_SPEED) * BOB_HEIGHT


func trigger() -> void:
	var tween := create_tween()
	tween.tween_property(_sword, "rotation:x", 1.6, 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_sword, "rotation:x", 0.35, 0.3).set_trans(Tween.TRANS_BACK)
