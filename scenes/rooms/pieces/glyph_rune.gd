extends Node3D
## A glowing rune on the floor (a glyph of warding). It pulses softly, and flares when its
## hazard goes off.

const TEXTURE := "res://assets/third_party/kenney_particles/circle_05.png"
const COLOR := Color(0.55, 0.2, 1.0)
const SIZE: float = 1.4

var _rune: MeshInstance3D
var _material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	_material = glow_material(load(TEXTURE), COLOR)
	# Mixed rather than added: an added glow washes out on the light floor tiles.
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_rune = _flat_quad(SIZE, _material)
	add_child(_rune)


func set_phase(phase: float) -> void:
	_time = phase * 4.0


func _process(delta: float) -> void:
	_time += delta
	_material.albedo_color.a = 0.8 + 0.2 * sin(_time * 2.0)


func trigger() -> void:
	var flash_material := glow_material(_material.albedo_texture, Color(1.0, 0.8, 1.0))
	var flash := _flat_quad(SIZE, flash_material)
	flash.position.y = 0.06
	add_child(flash)
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.6, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(flash.queue_free)


## An unshaded, additive material for glowing particle textures.
static func glow_material(texture: Texture2D, color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _flat_quad(size: float, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = material
	mi.position.y = 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
