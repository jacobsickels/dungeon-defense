extends GutTest
## The other ways rooms hurt: lingering poison, pulses that hit everyone inside, and
## dungeon-wide bonuses. None of them depend on where a room sits in the line.

const F = preload("res://tests/fixtures/content_fixture.gd")

var _sim: Simulation


func before_each() -> void:
	_sim = F.make_sim()
	_sim.blood = 1e6


func _peasant() -> AdventurerDef:
	return _sim.content.adventurers[&"peasant"]


func _walk_one_through() -> Adventurer:
	_sim.blood = 0.0
	var adv := _sim.spawn_adventurer(_peasant())
	F.run_until_empty(_sim)
	return adv


# --- Poison -------------------------------------------------------------------

func test_poison_is_picked_up_on_entering_and_ticks_over_time() -> void:
	_sim.buy_room(&"feast")
	_sim.blood = 0.0
	var adv := _sim.spawn_adventurer(_peasant())
	while adv.room_id != _sim.room_of_type(&"feast").id:
		_sim.tick(Balance.TICK_DT)
	assert_eq(adv.poison_remaining, F.FEAST_POISON, "full dose on entering")
	_sim.tick(Balance.TICK_DT)
	var per_tick := F.FEAST_POISON / Balance.POISON_DURATION * Balance.TICK_DT
	assert_almost_eq(_sim.blood, per_tick, 1e-6, "then it ticks")


func test_poison_is_all_paid_even_if_they_fall_first() -> void:
	# The feast is right before the pit, so they fall long before POISON_DURATION is up.
	_sim.buy_room(&"feast")
	var adv := _walk_one_through()
	assert_almost_eq(_sim.blood, F.FEAST_POISON, 1e-6, "every point of poison counts")
	assert_eq(adv.poison_remaining, 0.0)


func test_poison_pays_the_same_wherever_the_room_is() -> void:
	# Alone, the feast is last before the pit. With rooms after it, poison has time to tick.
	_sim.buy_room(&"feast")
	_walk_one_through()
	var feast_last := _sim.blood

	var other := F.make_sim()
	other.blood = 1e6
	other.buy_room(&"feast")
	# Three empty hallways after the feast, so the poison has time to tick before the pit.
	for i: int in 3:
		var treasure := other.room_of_type(&"treasure")
		other.dungeon.insert_between(other.content.rooms[&"hallway"], treasure.parent_id, treasure.id)
	other.blood = 0.0
	other.spawn_adventurer(other.content.adventurers[&"peasant"])
	F.run_until_empty(other)
	assert_almost_eq(other.blood, feast_last, 1e-6)


func test_poison_scales_with_level() -> void:
	_sim.buy_room(&"feast")
	_sim.buy_room(&"feast")
	_walk_one_through()
	assert_almost_eq(_sim.blood, F.FEAST_POISON * 2.0, 1e-6)


# --- Pulses ---------------------------------------------------------------------

func test_pulse_hits_everyone_inside_at_once() -> void:
	_sim.buy_room(&"rock")
	_sim.blood = 0.0
	var rock := _sim.room_of_type(&"rock")
	var a := _sim.spawn_adventurer(_peasant())
	var b := _sim.spawn_adventurer(_peasant())
	var outside := _sim.spawn_adventurer(_peasant())
	for adv: Adventurer in [a, b]:
		adv.room_id = rock.id
		adv.progress = 0.0
	outside.progress = 0.0  # still in the Entrance
	var pulses: Array[int] = []
	_sim.room_pulsed.connect(func(_r: DungeonRoom, n: int) -> void: pulses.append(n))
	rock.pulse_timer = F.PULSE_INTERVAL - Balance.TICK_DT * 0.5
	_sim.tick(Balance.TICK_DT)
	assert_eq(pulses, [2] as Array[int], "two adventurers inside")
	assert_almost_eq(a.blood_drained, F.ROCK_PULSE, 1e-6)
	assert_almost_eq(b.blood_drained, F.ROCK_PULSE, 1e-6)
	assert_eq(outside.blood_drained, 0.0)


func test_pulses_keep_time_with_nobody_inside() -> void:
	_sim.buy_room(&"rock")
	var pulses := [0]
	_sim.room_pulsed.connect(func(_r: DungeonRoom, _n: int) -> void: pulses[0] += 1)
	for i: int in int(F.PULSE_INTERVAL * 4 / Balance.TICK_DT) + 1:
		_sim.tick(Balance.TICK_DT)
	assert_between(pulses[0], 3, 4)


# --- Global bonuses -------------------------------------------------------------

func test_blood_bonus_multiplies_all_blood() -> void:
	_sim.buy_room(&"spikes")
	_walk_one_through()
	var plain := _sim.blood
	_sim.blood = 1e6
	_sim.buy_room(&"gem")
	assert_almost_eq(_sim.global_blood_multiplier(), 1.0 + F.GEM_BONUS, 1e-9)
	_walk_one_through()
	assert_almost_eq(_sim.blood, plain * (1.0 + F.GEM_BONUS), 1e-6)


func test_blood_bonus_stacks_per_level() -> void:
	_sim.buy_room(&"gem")
	_sim.buy_room(&"gem")
	_sim.buy_room(&"gem")
	assert_almost_eq(_sim.global_blood_multiplier(), 1.0 + F.GEM_BONUS * 3.0, 1e-9)


func test_hit_bonus_adds_to_every_hit_including_clicks() -> void:
	_sim.buy_room(&"spikes")
	_sim.buy_room(&"spikes")  # 2 spikes
	_sim.buy_room(&"altar")
	assert_eq(_sim.global_hit_bonus(), F.ALTAR_HIT)
	_walk_one_through()
	assert_almost_eq(_sim.blood, 2.0 * (F.SPIKE_HIT + F.ALTAR_HIT), 1e-6, "both spike hits get the bonus")

	_sim.blood = 0.0
	var adv := _sim.spawn_adventurer(_peasant())
	_sim.hit_adventurer(adv.id)
	assert_almost_eq(_sim.blood, Balance.CLICK_DAMAGE + F.ALTAR_HIT, 1e-6, "clicks too")


func test_hit_bonus_does_not_apply_to_damage_over_time() -> void:
	_sim.buy_room(&"blades")
	_walk_one_through()
	var plain := _sim.blood
	var other := F.make_sim()
	other.blood = 1e6
	other.buy_room(&"blades")
	other.buy_room(&"altar")
	other.blood = 0.0
	other.spawn_adventurer(other.content.adventurers[&"peasant"])
	F.run_until_empty(other)
	assert_almost_eq(other.blood, plain, 1e-6)
