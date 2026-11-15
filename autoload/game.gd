extends Node
## Autoload "Game". Owns the Simulation and runs it on a fixed tick.
## Scenes read state from Game.sim and connect to its signals.

## Most ticks to run in one frame. After a hitch, the rest of the backlog is dropped.
## Time spent away will be handled by offline progress, not by catching up here.
const MAX_TICKS_PER_FRAME: int = 10

var sim: Simulation

var _accumulator: float = 0.0


func _ready() -> void:
	sim = Simulation.new(ContentDB.load_default())


func _process(delta: float) -> void:
	_accumulator += delta
	var ticks := 0
	while _accumulator >= Balance.TICK_DT and ticks < MAX_TICKS_PER_FRAME:
		sim.tick(Balance.TICK_DT)
		_accumulator -= Balance.TICK_DT
		ticks += 1
	if ticks == MAX_TICKS_PER_FRAME:
		_accumulator = 0.0


## How far we are between the last tick and the next one (0..1), for smoothing visuals.
func tick_fraction() -> float:
	return clampf(_accumulator / Balance.TICK_DT, 0.0, 1.0)
