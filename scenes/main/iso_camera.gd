class_name IsoCamera
extends Camera3D
## Orthographic camera at a fixed isometric angle, looking from the south-east.
## Pan with middle-mouse drag or the arrow keys, zoom with the wheel.

const PITCH_DEG: float = -40.0
const YAW_DEG: float = 45.0
const DISTANCE: float = 80.0
const SIZE_MIN: float = 14.0
const SIZE_MAX: float = 120.0
const ZOOM_STEP: float = 1.1
## Fraction of the view crossed per second with the arrow keys.
const KEY_PAN_SPEED: float = 0.8

## Ground point the camera looks at.
var focus: Vector3 = Vector3.ZERO

var _dragging: bool = false


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	rotation = Vector3(deg_to_rad(PITCH_DEG), deg_to_rad(YAW_DEG), 0.0)
	_apply()


func look_at_ground(point: Vector3) -> void:
	focus = Vector3(point.x, 0.0, point.z)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					size = clampf(size / ZOOM_STEP, SIZE_MIN, SIZE_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					size = clampf(size * ZOOM_STEP, SIZE_MIN, SIZE_MAX)
			MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var units_per_pixel := size / get_viewport().get_visible_rect().size.y
		_pan_screen(-(event as InputEventMouseMotion).relative * units_per_pixel)


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		_pan_screen(dir * size * KEY_PAN_SPEED * delta)


## Moves the focus by a screen-space offset in world units (x right, y down).
func _pan_screen(offset: Vector2) -> void:
	var right := global_basis.x
	right.y = 0.0
	# "Up" on screen is away from the camera along the ground.
	var forward := -global_basis.z
	forward.y = 0.0
	# A screen unit up/down covers more ground because the view is tilted.
	var tilt := absf(sin(deg_to_rad(PITCH_DEG)))
	focus += right.normalized() * offset.x - forward.normalized() * offset.y / tilt
	_apply()


func _apply() -> void:
	global_position = focus + global_basis.z * DISTANCE
