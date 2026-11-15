class_name FloatingText3D
extends Label3D
## A short popup in the world (damage, blood) that floats up, fades out, and frees itself.

const RISE: float = 2.0
const DURATION: float = 0.9


static func spawn(parent: Node3D, pos: Vector3, text: String, color: Color, font_size: int = 64) -> void:
	var label := FloatingText3D.new()
	label.text = text
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.02
	parent.add_child(label)
	label.global_position = pos

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", pos.y + RISE, DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "outline_modulate:a", 0.0, DURATION).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
