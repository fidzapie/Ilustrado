extends Node

const ABILITY_TRIGGER_EVENT = "after_attack"

var already_activated = false

func trigger_ability(battle_manager_reference, card_with_ability, input_manager_reference, trigger_event):
	
	if ABILITY_TRIGGER_EVENT != trigger_event:
		return
	
	
	if already_activated:
		return
	
	if card_with_ability in battle_manager_reference.player_cards_that_attacked_this_turn:
		battle_manager_reference.player_cards_that_attacked_this_turn.erase(card_with_ability)
		already_activated = true

func end_turn_reset():
	print("test")
	already_activated = false
