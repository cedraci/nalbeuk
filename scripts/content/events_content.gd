extends RefCounted
class_name EventsContent

static func get_all_events() -> Array[EventResource]:
	return [_make_toll_troll_event(), _make_unattended_cart_event()]

static func get_random_event(rng: RandomNumberGenerator) -> EventResource:
	var events := get_all_events()
	return events[rng.randi_range(0, events.size() - 1)]

static func _make_toll_troll_event() -> EventResource:
	var event := EventResource.new()
	event.id = &"toll_troll"
	event.description = "A toll-troll blocks the path, muttering about \"union rules\" and demanding payment."
	var pay := EventChoice.new()
	pay.label = "Pay the toll (10 gold)"
	pay.gold_delta = -10
	pay.hp_delta = 0
	pay.outcome_text = "The troll grunts approvingly and steps aside."
	var refuse := EventChoice.new()
	refuse.label = "Refuse and push through"
	refuse.gold_delta = 0
	refuse.hp_delta = -5
	refuse.outcome_text = "The troll wasn't bluffing about the shoving."
	var choices: Array[EventChoice] = [pay, refuse]
	event.choices = choices
	return event

static func _make_unattended_cart_event() -> EventResource:
	var event := EventResource.new()
	event.id = &"unattended_cart"
	event.description = "You find a cart of unattended supplies. No one's around."
	var take := EventChoice.new()
	take.label = "Take what you can"
	take.gold_delta = 8
	take.hp_delta = 0
	take.outcome_text = "Some coins were tucked under a tarp."
	var leave := EventChoice.new()
	leave.label = "Leave it be"
	leave.gold_delta = 0
	leave.hp_delta = 0
	leave.outcome_text = "Your conscience remains intact, for now."
	var choices: Array[EventChoice] = [take, leave]
	event.choices = choices
	return event
