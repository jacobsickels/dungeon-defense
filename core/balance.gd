class_name Balance
extends RefCounted
## Global tuning values. Numbers for individual rooms and adventurers live in their .tres defs.

## Simulation ticks per second.
const TICK_RATE: int = 10
const TICK_DT: float = 1.0 / TICK_RATE

const STARTING_BLOOD: float = 15.0

const CLICK_DAMAGE: float = 1.0

## Seconds between adventurer arrivals.
const SPAWN_INTERVAL: float = 4.0
## Delay before the very first adventurer arrives in a new game.
const FIRST_SPAWN_DELAY: float = 2.0
const MAX_ADVENTURERS: int = 50

## Seconds over which the blood-per-second display is averaged.
const INCOME_SMOOTHING_TIME: float = 20.0
