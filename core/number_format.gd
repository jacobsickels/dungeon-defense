class_name NumberFormat
extends RefCounted
## Every number shown to the player goes through here. Values are truncated, not rounded,
## so the display never shows more than the player actually has.

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
## Fixes float error so that, for example, 1.23 doesn't truncate to 1.22.
const _EPSILON: float = 1e-9


## Examples: 999 -> "999", 1234 -> "1.23K", 12345 -> "12.3K", 1e40 -> "1.00e40".
static func short(value: float) -> String:
	if is_nan(value):
		return "NaN"
	if is_inf(value):
		return "-∞" if value < 0.0 else "∞"
	var sign := "-" if value < 0.0 else ""
	var a := absf(value)
	if a < 1000.0:
		return sign + str(int(floorf(a + _EPSILON)))

	var tier := 0
	while a >= 1000.0 and tier < SUFFIXES.size() - 1:
		a /= 1000.0
		tier += 1
	if a < 1000.0:
		return sign + _three_digits(a) + SUFFIXES[tier]

	# Past the last suffix, switch to scientific notation.
	var mantissa := absf(value)
	var exponent := 0
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	return "%s%.2fe%d" % [sign, _truncate(mantissa, 2), exponent]


## Three significant digits: 1.23, 12.3, 123.
static func _three_digits(a: float) -> String:
	if a < 10.0:
		return "%.2f" % _truncate(a, 2)
	if a < 100.0:
		return "%.1f" % _truncate(a, 1)
	return "%d" % int(floorf(a + _EPSILON))


static func _truncate(a: float, decimals: int) -> float:
	var scale := pow(10.0, decimals)
	return floorf(a * scale + _EPSILON) / scale
