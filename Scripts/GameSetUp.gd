extends Node2D

const STARTING_HEALTH = 10

func host_set_up():
	AudioManager.play_bg_music()
	$PlayerHealth.text =str(STARTING_HEALTH)
	get_parent().get_node("OpponentField/OpponentHealth").text = str(STARTING_HEALTH)
	$BattleManager.player_health = STARTING_HEALTH
	$BattleManager.opponent_health = STARTING_HEALTH
	
	get_parent().get_node("OpponentField/OpponentDeck").deck_size = $Deck.player_deck.size()
	get_parent().get_node("OpponentField/OpponentDeck/CardCount").text = str($Deck.player_deck.size())
	
	
	await $Deck.draw_initial_hand()
	
	await get_tree().create_timer(1.0).timeout
	$Deck.auto_draw()
	
	# Initialize button visibility (will be set properly by BattleManager.apply_priority_state)
	$ENDTURNBUTTON.visible = false
	$ENDTURNBUTTON.disabled = true
	$PASSBUTTON.visible = false
	$PASSBUTTON.disabled = true
	
	$InputManager.inputs_disabled = false
	
	
func client_set_up():
	AudioManager.play_bg_music()
	$PlayerHealth.text =str(STARTING_HEALTH)
	get_parent().get_node("OpponentField/OpponentHealth").text = str(STARTING_HEALTH)
	$BattleManager.player_health = STARTING_HEALTH
	$BattleManager.opponent_health = STARTING_HEALTH
	
	get_parent().get_node("OpponentField/OpponentDeck").deck_size = $Deck.player_deck.size()
	get_parent().get_node("OpponentField/OpponentDeck/CardCount").text = str($Deck.player_deck.size())

	$Deck.draw_initial_hand()
