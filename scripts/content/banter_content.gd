extends RefCounted
class_name BanterContent

# "Overheard" lines for the map's banter panel. Original cast, original
# jokes: Hilde Barrowdust (dwarf), Ormond (wizard), Pip Nettle (scout),
# Sabine (bard). Never the source comic's characters, names or gags.

static func get_all() -> Array[Dictionary]:
	return [
		{"line": "Left at the skull, right at the other skull. Which skull?", "who": "Hilde, to a corridor with no skulls in it"},
		{"line": "I'm not saying it's a trap. I'm saying it's a trapdoor with a sign that says 'trap'.", "who": "Pip Nettle, ignored"},
		{"line": "It's a rat's nest. — It's a rat's nest with excellent acoustics.", "who": "Sabine, overruled"},
		{"line": "Whose turn is it to carry the torch? — Whoever asked.", "who": "party rule number seven"},
		{"line": "That door was locked from the other side. — So we're on the wrong side. — We're on OUR side.", "who": "Hilde, settling it"},
		{"line": "It says 'Beware'. It doesn't say of what. — That's the bewaring part.", "who": "Ormond, helpfully"},
		{"line": "I counted twelve stairs down and eleven up. — Then we're one stair ahead.", "who": "Hilde, doing the maths"},
		{"line": "Stop poking it. — It's a chest. — It's breathing.", "who": "Pip Nettle, correctly"},
		{"line": "If we split up, we cover more ground. — If we split up, the ground covers us.", "who": "Hilde"},
		{"line": "Someone wrote 'turn back' on this wall. — In what? — Let's say ink.", "who": "Ormond, not looking closer"},
		{"line": "I have a good feeling about this corridor. — You had a good feeling about the last one. — It was a good corridor. Briefly.", "who": "Hilde"},
		{"line": "The map says 'here be dragons'. — That's a soup stain. — Dragons eat soup.", "who": "Ormond, unbothered"},
		{"line": "Sabine, stop composing. — It's a ballad about our deaths. — We're not dead. — It's a first draft.", "who": "Sabine, tuning"},
	]

static func get_overheard(rng: RandomNumberGenerator) -> Dictionary:
	var source: RandomNumberGenerator = rng
	if source == null:
		source = RandomNumberGenerator.new()
		source.randomize()
	var all := get_all()
	return all[source.randi_range(0, all.size() - 1)]
