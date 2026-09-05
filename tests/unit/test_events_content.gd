extends GutTest

func test_get_all_events_returns_well_formed_events():
	var events := EventsContent.get_all_events()
	assert_true(events.size() >= 2)
	for event in events:
		assert_ne(event.description, "")
		assert_eq(event.choices.size(), 2)
		for choice in event.choices:
			assert_ne(choice.label, "")
			assert_ne(choice.outcome_text, "")

func test_get_random_event_returns_one_of_the_known_events():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var all_events := EventsContent.get_all_events()
	var all_ids: Array[StringName] = []
	for event in all_events:
		all_ids.append(event.id)
	var picked := EventsContent.get_random_event(rng)
	assert_true(all_ids.has(picked.id))
