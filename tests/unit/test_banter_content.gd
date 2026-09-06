extends GutTest

func test_there_are_at_least_twelve_distinct_lines():
	var all := BanterContent.get_all()
	assert_true(all.size() >= 12, "%d lines" % all.size())
	var seen: Dictionary = {}
	for entry in all:
		assert_ne(String(entry["line"]), "")
		assert_ne(String(entry["who"]), "")
		assert_false(seen.has(entry["line"]), "duplicate: %s" % entry["line"])
		seen[entry["line"]] = true

func test_get_overheard_is_deterministic_for_a_seeded_rng():
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 5
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 5
	assert_eq(BanterContent.get_overheard(rng_a)["line"], BanterContent.get_overheard(rng_b)["line"])

func test_get_overheard_tolerates_a_null_rng():
	var entry := BanterContent.get_overheard(null)
	assert_true(entry.has("line") and entry.has("who"))
