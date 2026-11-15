class_name AdventurerModel
extends Node3D
## The 3D look of one adventurer. The view moves it. It turns to face where it's going and
## runs one-shot animations (flinches) on top of the running loop.

const LOCOMOTION: StringName = &"Running_A"
const BLEND: float = 0.15
const TURN_SPEED: float = 12.0
const FALL_DEPTH: float = 6.0
const FALL_TIME: float = 0.6

## Bookkeeping for the view's feedback: the room they were last seen in, and how much of
## their drained blood has been shown in popups.
var last_room_id: int = -1
var shown_blood: float = 0.0
var popup_timer: float = 0.0

var _player: AnimationPlayer
var _falling: bool = false


func setup(scene: PackedScene) -> void:
	if scene == null:
		return
	var model: Node3D = scene.instantiate()
	add_child(model)
	_player = CharacterAnimations.attach_player(model)
	_player.animation_finished.connect(_on_animation_finished)
	_play(LOCOMOTION)


## Turns smoothly toward a direction on the ground plane.
func face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 1e-6:
		return
	# The glTF models face +Z.
	var target := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(TURN_SPEED * delta, 0.0, 1.0))


func play_once(animation: StringName) -> void:
	if not _falling:
		_play(animation)


## A hit reaction. If one is already playing, it isn't restarted, so a row of spikes reads as
## a stumble rather than a twitch.
func flinch() -> void:
	if _falling or _player == null:
		return
	var current := _player.current_animation
	if current == CharacterAnimations.full_name(&"Hit_A") or current == CharacterAnimations.full_name(&"Hit_B"):
		return
	_play(&"Hit_A" if randf() < 0.5 else &"Hit_B")


## Drops through the trapdoor and frees itself.
func fall() -> void:
	_falling = true
	_play(&"Jump_Idle")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - FALL_DEPTH, FALL_TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector3.ONE * 0.6, FALL_TIME)
	tween.chain().tween_callback(queue_free)


func _play(animation: StringName) -> void:
	if _player == null:
		return
	var full := CharacterAnimations.full_name(animation)
	if _player.has_animation(full):
		_player.play(full, BLEND)


func _on_animation_finished(_name: StringName) -> void:
	if not _falling:
		_play(LOCOMOTION)
