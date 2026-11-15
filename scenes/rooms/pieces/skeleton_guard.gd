extends Node3D
## A Skeleton Minion with a blade, standing beside the path. Swings when its hazard hits.

const MODEL := "res://assets/third_party/kaykit/skeletons/Skeleton_Minion.glb"
const BLADE := "res://assets/third_party/kaykit/skeletons/Skeleton_Blade.gltf"
const IDLE: StringName = &"Skeletons_Idle"
const ATTACKS: Array[StringName] = [&"Melee_1H_Attack_Chop", &"Melee_1H_Attack_Slice_Diagonal"]

var _player: AnimationPlayer


func _ready() -> void:
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skeleton != null:
		var hand := BoneAttachment3D.new()
		skeleton.add_child(hand)
		hand.bone_name = "handslot.r"
		hand.add_child((load(BLADE) as PackedScene).instantiate())
	_player = CharacterAnimations.attach_player(model)
	_player.animation_finished.connect(func(_n: StringName) -> void: _play(IDLE))
	_play(IDLE)


## Desyncs idle loops between neighbors.
func set_phase(phase: float) -> void:
	if _player != null and _player.is_playing():
		_player.seek(fmod(phase, 1.0), true)


func trigger() -> void:
	_play(ATTACKS[randi() % ATTACKS.size()])


func _play(animation: StringName) -> void:
	var full := CharacterAnimations.full_name(animation)
	if _player != null and _player.has_animation(full):
		_player.play(full, 0.1)
