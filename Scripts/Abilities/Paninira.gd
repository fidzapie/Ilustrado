extends Node

const ABILITY_TRIGGER_EVENT = "card_placed"

func trigger_ability(battle_manager_reference, card_with_ability, input_manager_reference, trigger_event):
	
	
	if ABILITY_TRIGGER_EVENT != trigger_event:
		return
	
	input_manager_reference.inputs_disabled = true
	battle_manager_reference.end_turn_button_enabled(false)
	
	await battle_manager_reference.wait(1.0)
	
	# Send RPC to apply damage on both sides
	AudioManager.play_paninira()
	var player_id: int = battle_manager_reference.multiplayer.get_unique_id()
	battle_manager_reference.rpc("apply_paninira_damage", player_id, str(card_with_ability.name))
	await battle_manager_reference.apply_paninira_damage(player_id, str(card_with_ability.name))
	
	battle_manager_reference.end_turn_button_enabled(true)
	input_manager_reference.inputs_disabled = false
