class_name CharacterAnimations
extends RefCounted
## The KayKit Rig_Medium animations, gathered into one library that every character shares
## (adventurers and skeletons use the same rig). Built the first time a character needs it.
## The files are loaded then rather than preloaded, because a script that preloads them
## can't compile until they've been imported.

const LIBRARY_NAME: StringName = &"kaykit"
const FILES: Array[String] = [
	"res://assets/third_party/kaykit/animations/Rig_Medium_General.glb",
	"res://assets/third_party/kaykit/animations/Rig_Medium_MovementBasic.glb",
	"res://assets/third_party/kaykit/animations/Rig_Medium_CombatMelee.glb",
	"res://assets/third_party/kaykit/animations/Rig_Medium_CombatRanged.glb",
	"res://assets/third_party/kaykit/animations/Rig_Medium_Special.glb",
]
## These loop. Every other animation plays once.
const LOOPING: Array[StringName] = [
	&"Idle_A", &"Idle_B", &"Walking_A", &"Walking_B", &"Walking_C", &"Running_A", &"Running_B",
	&"Skeletons_Idle", &"Skeletons_Walking", &"Melee_2H_Idle", &"Melee_Unarmed_Idle", &"Ranged_Bow_Idle",
]

static var _library: AnimationLibrary


static func get_library() -> AnimationLibrary:
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	for path: String in FILES:
		var file: PackedScene = load(path)
		var scene := file.instantiate()
		var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		for animation_name: StringName in player.get_animation_list():
			if _library.has_animation(animation_name):
				continue
			var animation: Animation = player.get_animation(animation_name).duplicate()
			animation.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(animation_name) else Animation.LOOP_NONE
			_library.add_animation(animation_name, animation)
		scene.free()
	return _library


## Adds an AnimationPlayer with the shared library to a freshly instanced KayKit model.
static func attach_player(model: Node3D) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(LIBRARY_NAME, get_library())
	return player


static func full_name(animation: StringName) -> StringName:
	return StringName("%s/%s" % [LIBRARY_NAME, animation])
