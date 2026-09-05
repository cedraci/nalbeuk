extends GutTest

func test_equipment_resource_holds_configured_fields():
	var item := EquipmentResource.new()
	item.id = &"test_weapon"
	item.display_name = "Test Weapon"
	item.slot = EquipmentResource.Slot.WEAPON
	item.description = "A test weapon."
	item.strength_delta = 3
	item.block_delta = 0
	item.passive_id = &""
	assert_eq(item.slot, EquipmentResource.Slot.WEAPON)
	assert_eq(item.strength_delta, 3)

func test_relic_resource_holds_configured_fields():
	var relic := RelicResource.new()
	relic.id = &"test_relic"
	relic.display_name = "Test Relic"
	relic.description = "A test relic."
	relic.vitality_delta = 3
	relic.gold_bonus_per_reward = 5
	assert_eq(relic.vitality_delta, 3)
	assert_eq(relic.gold_bonus_per_reward, 5)

func test_potion_resource_apply_grants_strength_stacks_when_set():
	var potion := PotionResource.new()
	potion.strength_stacks = 3
	var actor := CombatActor.new("Hero", 20)
	potion.apply(actor)
	assert_eq(actor.get_status_stacks(&"strength"), 3)

func test_potion_resource_apply_heals_when_heal_amount_set():
	var potion := PotionResource.new()
	potion.heal_amount = 10
	var actor := CombatActor.new("Hero", 20)
	actor.take_damage(15)
	potion.apply(actor)
	assert_eq(actor.current_hp, 15)

func test_potion_resource_apply_does_both_when_both_set():
	var potion := PotionResource.new()
	potion.heal_amount = 5
	potion.strength_stacks = 2
	var actor := CombatActor.new("Hero", 20)
	actor.take_damage(10)
	potion.apply(actor)
	assert_eq(actor.current_hp, 15)
	assert_eq(actor.get_status_stacks(&"strength"), 2)
