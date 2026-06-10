extends Node

func trigger_ability(battle_manager_reference, card_with_ability, input_manager_reference, trigger_event):
	
	if trigger_event == "card_placed":
		input_manager_reference.inputs_disabled = true
		battle_manager_reference.end_turn_button_enabled(false)
		
		await battle_manager_reference.wait(1.0)
		
		# Deal 1 damage to opponent's main HP
		AudioManager.play_itak()
		battle_manager_reference.direct_damage(1, battle_manager_reference.multiplayer.get_unique_id())
		
		await battle_manager_reference.wait(1.0)

		battle_manager_reference.end_turn_button_enabled(true)
		input_manager_reference.inputs_disabled = false

func end_turn_reset():
	pass
