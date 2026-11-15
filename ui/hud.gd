class_name Hud
extends CanvasLayer
## Blood, income, stats, and the shop: rooms (build once, then upgrade) and lures.

## Unbuilt rooms shown in the shop at once, in line order, like Cookie Clicker revealing
## buildings ahead of you.
const ROOMS_REVEALED_AHEAD: int = 2


## One shop entry: a name, its level, and a buy button.
class ShopRow:
	var box: HBoxContainer
	var level: Label
	var buy: Button


@onready var _blood_label: Label = %BloodLabel
@onready var _income_label: Label = %IncomeLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _shop_list: VBoxContainer = %ShopList
@onready var _lure_list: VBoxContainer = %LureList

var _room_rows: Dictionary[StringName, ShopRow] = {}
var _lure_rows: Dictionary[StringName, ShopRow] = {}


func _ready() -> void:
	for def: RoomDef in Game.sim.content.buildable_rooms():
		var tip := "%s\n\nPer level: %s damage per second" % [def.description, str(snappedf(def.dps, 0.01))]
		_room_rows[def.id] = _make_row(_shop_list, def.display_name, tip,
				func() -> void: Game.sim.buy_room(def.id))
	for def: LureDef in Game.sim.content.sorted_lures():
		var tip := "%s\n\nPer level: %s" % [def.description, _effect_summary(def)]
		_lure_rows[def.id] = _make_row(_lure_list, def.display_name, tip,
				func() -> void: Game.sim.buy_lure(def.id))


func _make_row(parent: Container, title: String, tooltip: String, on_buy: Callable) -> ShopRow:
	var row := ShopRow.new()
	var box := HBoxContainer.new()
	row.box = box
	parent.add_child(box)

	var name_label := Label.new()
	name_label.text = title
	name_label.tooltip_text = tooltip
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	box.add_child(name_label)

	row.level = Label.new()
	row.level.custom_minimum_size = Vector2(44, 0)
	row.level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.level.add_theme_font_size_override("font_size", 14)
	box.add_child(row.level)

	row.buy = Button.new()
	row.buy.focus_mode = Control.FOCUS_NONE
	row.buy.custom_minimum_size = Vector2(84, 0)
	row.buy.tooltip_text = tooltip
	row.buy.pressed.connect(on_buy)
	box.add_child(row.buy)
	return row


func _effect_summary(def: LureDef) -> String:
	var parts: Array[String] = []
	for pair: Array in [["spawn_rate_mult", "arrivals"], ["blood_mult", "blood per hit"],
			["speed_mult", "walking speed"]]:
		var mult: float = def.get(pair[0])
		if not is_equal_approx(mult, 1.0):
			parts.append("%s ×%s" % [pair[1], str(snappedf(mult, 0.01))])
	return ", ".join(parts)


func _process(_delta: float) -> void:
	var sim := Game.sim
	_blood_label.text = "Blood: %s" % NumberFormat.short(sim.blood)
	_income_label.text = "+%s blood/s" % _rate(sim.income_per_second)
	_stats_label.text = "Visitors: %d    Inside: %d" % [sim.visitors, sim.adventurers.size()]

	var unbuilt_shown := 0
	for id: StringName in _room_rows:  # in line order
		var row := _room_rows[id]
		var level := sim.room_level(id)
		if level == 0:
			unbuilt_shown += 1
		row.box.visible = level > 0 or unbuilt_shown <= ROOMS_REVEALED_AHEAD
		var cost := sim.room_cost(id)
		row.level.text = "Lv %d" % level if level > 0 else "—"
		row.buy.text = ("Build %s" if level == 0 else "▲ %s") % NumberFormat.short(cost)
		row.buy.disabled = sim.blood < cost

	for id: StringName in _lure_rows:
		var row := _lure_rows[id]
		var cost := sim.lure_cost(id)
		row.level.text = "Lv %d" % sim.lure_owned(id)
		row.buy.text = "MAX" if is_inf(cost) else "▲ %s" % NumberFormat.short(cost)
		row.buy.disabled = sim.blood < cost


## Blood per second with one decimal while small, so early income isn't shown as 0.
func _rate(value: float) -> String:
	if value < 100.0:
		return "%.1f" % maxf(value, 0.0)
	return NumberFormat.short(value)
