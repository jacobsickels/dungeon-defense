extends GutTest
## Lures: buying levels, their effects, and income tracking.

const F = preload("res://tests/fixtures/content_fixture.gd")

var _sim: Simulation


func before_each() -> void:
	_sim = F.make_sim()
	_sim.blood = 1000.0


func _peasant() -> AdventurerDef:
	return _sim.content.adventurers[&"peasant"]


## Spikes in the line, then `seconds` of auto-spawning. Returns blood earned.
func _earn(sim: Simulation, seconds: float) -> float:
	sim.blood = 1e6
	sim.buy_room(&"spikes")
	sim.blood = 0.0
	sim.auto_spawn = true
	for i: int in int(seconds / Balance.TICK_DT):
		sim.tick(Balance.TICK_DT)
	return sim.blood


func test_buying_spends_blood_and_raises_cost() -> void:
	assert_eq(_sim.lure_cost(&"ads"), F.ADS_COST)
	assert_true(_sim.buy_lure(&"ads"))
	assert_eq(_sim.blood, 1000.0 - F.ADS_COST)
	assert_eq(_sim.lure_owned(&"ads"), 1)
	assert_eq(_sim.lure_cost(&"ads"), F.ADS_COST * F.LURE_GROWTH)


func test_cannot_buy_without_blood_or_unknown_lure() -> void:
	_sim.blood = F.ADS_COST - 1.0
	assert_false(_sim.buy_lure(&"ads"))
	assert_false(_sim.buy_lure(&"nope"))
	assert_eq(_sim.lure_owned(&"ads"), 0)


func test_max_level_stops_buying() -> void:
	(_sim.content.lures[&"heavy"] as LureDef).max_level = 2
	assert_true(_sim.buy_lure(&"heavy"))
	assert_true(_sim.buy_lure(&"heavy"))
	assert_eq(_sim.lure_cost(&"heavy"), INF)
	var blood := _sim.blood
	assert_false(_sim.buy_lure(&"heavy"))
	assert_eq(_sim.lure_owned(&"heavy"), 2)
	assert_eq(_sim.blood, blood)


func test_unavailable_lure_is_hidden_and_cannot_be_bought() -> void:
	(_sim.content.lures[&"heavy"] as LureDef).available = false
	assert_false(_sim.content.sorted_lures().any(func(d: LureDef) -> bool: return d.id == &"heavy"))
	assert_eq(_sim.lure_cost(&"heavy"), INF)
	assert_false(_sim.buy_lure(&"heavy"))


func test_levels_scale_new_adventurers() -> void:
	_sim.buy_lure(&"plump")
	_sim.buy_lure(&"plump")  # blood ×9
	_sim.buy_lure(&"heavy")  # speed ×0.5
	var adv := _sim.spawn_adventurer(_peasant())
	assert_eq(adv.bleed, 9.0)
	assert_eq(adv.speed, 0.5)


func test_plump_multiplies_blood_per_hit() -> void:
	_sim.buy_lure(&"plump")
	var adv := _sim.spawn_adventurer(_peasant())
	var before := _sim.blood
	_sim.hit_adventurer(adv.id, 2.0)
	assert_eq(_sim.blood, before + 2.0 * 3.0)


func test_arrival_and_blood_lures_raise_income() -> void:
	var base := _earn(F.make_sim(), 120.0)
	assert_gt(base, 0.0)
	for id: StringName in [&"ads", &"plump"]:
		var sim := F.make_sim()
		sim.blood = 1000.0
		assert_true(sim.buy_lure(id))
		var earned := _earn(sim, 120.0)
		assert_gt(earned, base * 1.5, "%s should clearly raise income" % id)


func test_income_tracks_blood_rate_and_ignores_spending() -> void:
	_sim.blood = F.SPIKES_COST
	assert_true(_sim.buy_room(&"spikes"))
	assert_eq(_sim.income_per_second, 0.0, "building isn't income")
	_sim.auto_spawn = true
	for i: int in int(120.0 / Balance.TICK_DT):
		_sim.tick(Balance.TICK_DT)
	# Each visitor walks past the one spike.
	var expected := F.SPIKE_HIT / Balance.SPAWN_INTERVAL
	assert_almost_eq(_sim.income_per_second, expected, expected * 0.25)


func test_slower_walkers_bleed_more_over_time_but_not_from_spikes() -> void:
	# Spikes hit once per spike whatever the speed. Damage over time grows with time inside.
	var spike_blood: Array[float] = []
	var blade_blood: Array[float] = []
	for heavy: bool in [false, true]:
		var sim := F.make_sim()
		sim.blood = 1e6
		if heavy:
			sim.buy_lure(&"heavy")
		sim.buy_room(&"spikes")
		sim.buy_room(&"blades")
		sim.blood = 0.0
		var adv := sim.spawn_adventurer(sim.content.adventurers[&"peasant"])
		var spikes_id := sim.room_of_type(&"spikes").id
		var from_spikes := 0.0
		for i: int in 2000:
			if sim.adventurers.is_empty():
				break
			var in_spikes := adv.room_id == spikes_id
			var before := sim.blood
			sim.tick(Balance.TICK_DT)
			if in_spikes:
				from_spikes += sim.blood - before
		spike_blood.append(from_spikes)
		blade_blood.append(sim.blood - from_spikes)
	assert_eq(spike_blood[0], spike_blood[1], "spikes don't care about speed")
	# Half speed means about twice the time inside (tick rounding makes it not exact).
	assert_gt(blade_blood[1], blade_blood[0] * 1.7, "slower walkers bleed more over time")
