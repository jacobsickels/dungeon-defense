extends GutTest


func test_small_numbers_are_whole() -> void:
	assert_eq(NumberFormat.short(0.0), "0")
	assert_eq(NumberFormat.short(7.9), "7")
	assert_eq(NumberFormat.short(999.0), "999")


func test_suffixes_with_three_significant_digits() -> void:
	assert_eq(NumberFormat.short(1000.0), "1.00K")
	assert_eq(NumberFormat.short(1234.0), "1.23K")
	assert_eq(NumberFormat.short(12345.0), "12.3K")
	assert_eq(NumberFormat.short(123456.0), "123K")
	assert_eq(NumberFormat.short(999999.0), "999K", "truncates, never rounds up")
	assert_eq(NumberFormat.short(1e6), "1.00M")
	assert_eq(NumberFormat.short(2.5e9), "2.50B")


func test_scientific_past_last_suffix() -> void:
	assert_eq(NumberFormat.short(1e40), "1.00e40")


func test_negative() -> void:
	assert_eq(NumberFormat.short(-1234.0), "-1.23K")
	assert_eq(NumberFormat.short(-5.0), "-5")
