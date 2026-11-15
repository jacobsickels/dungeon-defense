extends GutTest
## Adventurer movement, the blood economy, and the room line through the Simulation.

const F = preload("res://tests/fixtures/content_fixture.gd")

var _sim: Simulation


func before_each() -> void:
	_sim = F.make_sim()


func _peasant() -> AdventurerDef:
	return _sim.content.adventurers[&"peasant"]


## Room def ids along the path from the Entrance to the Treasure Pit.
func _line() -> Array[StringName]:
	var d := _sim.dungeon
	var out: Array[StringName] = []
	for id: int in d.path(d.entrance_id, d.nearest_treasure(d.entrance_id)):
		out.append(d.get_room(id).def.id)
	return out


func test_starting_line_is_entrance_then_treasure() -> void:
	assert_eq(_line(), [&"entrance", &"treasure"] as Array[StringName])
	assert_eq(_sim.blood, Balance.STARTING_BLOOD)


func test_adventurer_walks_the_line_and_falls_through_the_trapdoor() -> void:
	_sim.blood = 1000.0
	_sim.buy_room(&"spikes")
	var adv := _sim.spawn_adventurer(_peasant())
	var visited: Array[StringName] = []
	for i: int in 500:
		if _sim.adventurers.is_empty():
			break
		var here := _sim.dungeon.get_room(adv.room_id).def.id
		if visited.is_empty() or visited.back() != here:
			visited.append(here)
		_sim.tick(Balance.TICK_DT)
	assert_eq(visited, [&"entrance", &"spikes", &"treasure"] as Array[StringName])
	assert_eq(_sim.fallen, 1)
	assert_eq(_sim.visitors, 1)


func test_first_purchase_builds_the_room_in_the_line() -> void:
	assert_eq(_sim.room_level(&"spikes"), 0)
	assert_eq(_sim.room_cost(&"spikes"), F.SPIKES_COST)
	assert_true(_sim.buy_room(&"spikes"))
	assert_eq(_sim.blood, Balance.STARTING_BLOOD - F.SPIKES_COST)
	assert_eq(_sim.room_level(&"spikes"), 1)
	assert_eq(_line(), [&"entrance", &"spikes", &"treasure"] as Array[StringName])


func test_rooms_take_their_set_place_whatever_order_they_are_bought() -> void:
	_sim.blood = 1e6
	assert_true(_sim.buy_room(&"blades"))
	assert_true(_sim.buy_room(&"spikes"))
	assert_eq(_line(), [&"entrance", &"spikes", &"blades", &"treasure"] as Array[StringName],
			"spikes (order 10) goes before blades (order 20) even when bought second")


func test_buying_again_upgrades_instead_of_adding_a_room() -> void:
	_sim.blood = 1e6
	_sim.buy_room(&"spikes")
	var rooms_before := _sim.dungeon.rooms.size()
	var room := _sim.room_of_type(&"spikes")
	var upgraded := [0]
	_sim.room_upgraded.connect(func(_r: DungeonRoom) -> void: upgraded[0] += 1)

	var blood_before := _sim.blood
	assert_eq(_sim.room_cost(&"spikes"), F.SPIKES_COST * F.ROOM_GROWTH)
	assert_true(_sim.buy_room(&"spikes"))
	assert_eq(_sim.blood, blood_before - F.SPIKES_COST * F.ROOM_GROWTH)
	assert_eq(_sim.dungeon.rooms.size(), rooms_before, "no new room")
	assert_eq(room.level, 2)
	assert_eq(room.hazard_count(), 2, "one spike per level")
	assert_eq(room.hazard_damage_per_crossing(), F.SPIKE_HIT * 2.0)
	assert_eq(upgraded[0], 1)
	assert_eq(_sim.room_cost(&"spikes"), F.SPIKES_COST * F.ROOM_GROWTH * F.ROOM_GROWTH)


func test_cannot_buy_without_blood_or_unbuildable_rooms() -> void:
	_sim.blood = F.SPIKES_COST - 1.0
	assert_false(_sim.buy_room(&"spikes"))
	_sim.blood = 1e6
	assert_false(_sim.buy_room(&"treasure"), "the Treasure Pit isn't for sale")
	assert_false(_sim.buy_room(&"hallway"))
	assert_false(_sim.buy_room(&"nope"))
	assert_eq(_sim.room_cost(&"nope"), INF)
	assert_eq(_line(), [&"entrance", &"treasure"] as Array[StringName])


func test_no_damage_means_no_blood() -> void:
	_sim.spawn_adventurer(_peasant())
	F.run_until_empty(_sim)
	assert_eq(_sim.blood, Balance.STARTING_BLOOD)


func test_room_damage_bleeds_blood() -> void:
	_sim.buy_room(&"spikes")
	_sim.blood = 0.0
	var adv := _sim.spawn_adventurer(_peasant())
	F.run_until_empty(_sim)
	# Level 1: one spike, passed once.
	assert_eq(_sim.blood, F.SPIKE_HIT)
	assert_almost_eq(adv.blood_drained, _sim.blood, 1e-9)


func test_every_purchase_raises_blood_per_visitor() -> void:
	var earned: Array[float] = []
	for purchase: StringName in [&"", &"spikes", &"spikes", &"blades", &"spikes"]:
		if purchase != &"":
			_sim.blood = 1e6
			assert_true(_sim.buy_room(purchase))
		_sim.blood = 0.0
		_sim.spawn_adventurer(_peasant())
		F.run_until_empty(_sim)
		earned.append(_sim.blood)
	for i: int in range(1, earned.size()):
		assert_gt(earned[i], earned[i - 1], "each purchase adds blood: %s" % [earned])


func test_clicking_bleeds_blood() -> void:
	var adv := _sim.spawn_adventurer(_peasant())
	var reported: Array[float] = []
	_sim.adventurer_hit.connect(func(_a: Adventurer, _d: float, b: float) -> void: reported.append(b))
	assert_true(_sim.hit_adventurer(adv.id))
	assert_eq(_sim.blood, Balance.STARTING_BLOOD + Balance.CLICK_DAMAGE)
	assert_eq(reported, [Balance.CLICK_DAMAGE] as Array[float])
	assert_true(_sim.adventurers.has(adv.id), "adventurers can't die")


func test_cannot_hit_someone_who_fell() -> void:
	var adv := _sim.spawn_adventurer(_peasant())
	F.run_until_empty(_sim)
	assert_false(_sim.hit_adventurer(adv.id))


func test_new_room_reroutes_adventurer_already_walking() -> void:
	var adv := _sim.spawn_adventurer(_peasant())
	var treasure := _sim.room_of_type(&"treasure")
	assert_eq(adv.next_room_id, treasure.id)
	_sim.buy_room(&"spikes")
	assert_eq(adv.next_room_id, _sim.room_of_type(&"spikes").id, "next step is now the new room")


func test_new_room_behind_adventurer_fixes_prev_room() -> void:
	_sim.blood = 1e6
	_sim.buy_room(&"blades")
	var adv := _sim.spawn_adventurer(_peasant())
	for i: int in 15:
		_sim.tick(Balance.TICK_DT)
	assert_eq(adv.room_id, _sim.room_of_type(&"blades").id)
	assert_eq(adv.prev_room_id, _sim.dungeon.entrance_id)

	_sim.buy_room(&"spikes")  # goes between the Entrance and blades, behind them
	assert_eq(adv.prev_room_id, _sim.room_of_type(&"spikes").id, "came-from is the adjacent room again")


func test_debug_set_room_level_builds_and_sets_level_for_free() -> void:
	_sim.debug_set_room_level(&"blades", 5)
	_sim.debug_set_room_level(&"spikes", 3)
	assert_eq(_line(), [&"entrance", &"spikes", &"blades", &"treasure"] as Array[StringName])
	assert_eq(_sim.room_level(&"blades"), 5)
	assert_eq(_sim.room_level(&"spikes"), 3)
	assert_eq(_sim.blood, Balance.STARTING_BLOOD, "free")
	_sim.debug_set_room_level(&"spikes", 1)
	assert_eq(_sim.room_level(&"spikes"), 1, "can go back down")
	_sim.debug_set_room_level(&"spikes", 0)
	assert_eq(_sim.room_level(&"spikes"), 1, "0 is ignored")


func test_debug_set_room_level_updates_global_bonuses() -> void:
	_sim.debug_set_room_level(&"gem", 2)
	assert_almost_eq(_sim.global_blood_multiplier(), 1.0 + F.GEM_BONUS * 2.0, 1e-9)


func test_auto_spawn_respects_interval() -> void:
	_sim.auto_spawn = true
	var ticks := int(roundf(Balance.FIRST_SPAWN_DELAY / Balance.TICK_DT))
	for i: int in ticks - 1:
		_sim.tick(Balance.TICK_DT)
	assert_eq(_sim.adventurers.size(), 0)
	_sim.tick(Balance.TICK_DT)
	_sim.tick(Balance.TICK_DT)  # one extra tick to absorb float error
	assert_eq(_sim.adventurers.size(), 1)
