extends GutTest

func test_new_actor_starts_at_max_hp():
	var actor := CombatActor.new("Hero", 20)
	assert_eq(actor.current_hp, 20)
	assert_eq(actor.max_hp, 20)

func test_take_damage_reduces_hp():
	var actor := CombatActor.new("Hero", 20)
	actor.take_damage(5)
	assert_eq(actor.current_hp, 15)

func test_take_damage_is_absorbed_by_block_first():
	var actor := CombatActor.new("Hero", 20)
	actor.add_block(4)
	actor.take_damage(6)
	assert_eq(actor.block, 0)
	assert_eq(actor.current_hp, 18)

func test_take_damage_cannot_reduce_hp_below_zero():
	var actor := CombatActor.new("Hero", 10)
	actor.take_damage(999)
	assert_eq(actor.current_hp, 0)

func test_clear_block_resets_to_zero():
	var actor := CombatActor.new("Hero", 20)
	actor.add_block(5)
	actor.clear_block()
	assert_eq(actor.block, 0)

func test_status_stacks_default_to_zero_and_can_be_added():
	var actor := CombatActor.new("Hero", 20)
	assert_eq(actor.get_status_stacks(&"strength"), 0)
	actor.add_status(&"strength", 3)
	assert_eq(actor.get_status_stacks(&"strength"), 3)
	actor.add_status(&"strength", 2)
	assert_eq(actor.get_status_stacks(&"strength"), 5)

func test_died_signal_emitted_when_hp_reaches_zero():
	var actor := CombatActor.new("Hero", 5)
	watch_signals(actor)
	actor.take_damage(5)
	assert_signal_emitted(actor, "died")

func test_baseline_block_bonus_defaults_to_zero():
	var actor := CombatActor.new("Hero", 20)
	assert_eq(actor.baseline_block_bonus, 0)

func test_heal_increases_current_hp():
	var actor := CombatActor.new("Hero", 20)
	actor.take_damage(10)
	actor.heal(5)
	assert_eq(actor.current_hp, 15)

func test_heal_clamps_to_max_hp():
	var actor := CombatActor.new("Hero", 20)
	actor.take_damage(3)
	actor.heal(100)
	assert_eq(actor.current_hp, 20)

func test_heal_does_not_affect_block():
	var actor := CombatActor.new("Hero", 20)
	actor.add_block(4)
	actor.heal(5)
	assert_eq(actor.block, 4)
