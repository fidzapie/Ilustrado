extends Node

const SMALL_CARD_SCALE = 0.32
const MOVE_SPEED = 0.2
const STARTING_HEALTH = 10
const BATTLE_POS_OFFSET= 25

var battle_timer
var opponent_cards_on_battlefield = []
var player_cards_on_battlefield = []
var player_cards_that_attacked_this_turn = []
var player_health
var opponent_health

var current_round = 1
var player_mana = 1
var opponent_mana = 1

var is_my_attacking_phase: bool = false
var has_priority: bool = false
var defender_has_passed: bool = false
var has_attacker_acted_this_turn: bool = false

# NEW: Track turn phase for proper button visibility
var round_has_started: bool = false  # Tracks if anyone has played a card this round
var attacker_can_only_pass: bool = true  # Only true at the very start of attacker's turn in a round
var defender_played_card_this_turn: bool = false  # Defender played a card on their turn

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	battle_timer = $"../BattleTimer"
	battle_timer.one_shot = true
	battle_timer.wait_time = 1.0
	
	if multiplayer.is_server():
		is_my_attacking_phase = true
		has_priority = true
	else:
		is_my_attacking_phase = false
		has_priority = false
		
	defender_has_passed = true # Attacker starts being able to attack HP until they play a card
	
	update_mana_ui()
	update_status_ui()
	apply_priority_state()

func update_status_ui():
	var my_status = "Attacking" if is_my_attacking_phase else "Defending"
	var opp_status = "Defending" if is_my_attacking_phase else "Attacking"
	
	if $"../".has_node("StatusLabel"):
		$"../StatusLabel".text = my_status
	var opponent_field = get_parent().get_parent().get_node_or_null("OpponentField")
	if opponent_field and opponent_field.has_node("StatusLabel"):
		opponent_field.get_node("StatusLabel").text = opp_status

func apply_priority_state() -> void:
	var end_turn_button: TextureButton = $"../ENDTURNBUTTON"
	var pass_button: TextureButton = $"../PASSBUTTON"
	var main_node: Node = get_parent().get_parent()
	var opponent_end_turn: TextureButton = main_node.get_node_or_null("OpponentField/ENDTURNBUTTON")
	var opponent_pass: TextureButton = main_node.get_node_or_null("OpponentField/PASSBUTTON")
	
	if has_priority:
		$"../InputManager".inputs_disabled = false
		
		if is_my_attacking_phase:
			# ATTACKER PHASE LOGIC
			# Scenario 1: Round Start - Attacker can ONLY PASS (no cards played yet this round)
			if not round_has_started:
				end_turn_button.visible = false
				end_turn_button.disabled = true
				pass_button.visible = true
				pass_button.disabled = false
			# Scenario 2: Attacker has priority after defender played a card
			# Now attacker can attack OR EndTurn (no PASS option anymore)
			else:
				end_turn_button.visible = true
				end_turn_button.disabled = false
				pass_button.visible = false
				pass_button.disabled = true
		else:
			# DEFENDER PHASE LOGIC
			# Scenario 1: Attacker passed at round start - show END TURN
			if not round_has_started:
				end_turn_button.visible = true
				end_turn_button.disabled = false
				pass_button.visible = false
				pass_button.disabled = true
			# Scenario 2: Cards have been played - show PASS
			else:
				end_turn_button.visible = false
				end_turn_button.disabled = true
				pass_button.visible = true
				pass_button.disabled = false
		
		# Hide opponent buttons
		if opponent_end_turn:
			opponent_end_turn.visible = false
			opponent_end_turn.disabled = true
		if opponent_pass:
			opponent_pass.visible = false
			opponent_pass.disabled = true
	else:
		$"../InputManager".inputs_disabled = true
		# Hide all buttons when player doesn't have priority
		end_turn_button.visible = false
		end_turn_button.disabled = true
		pass_button.visible = false
		pass_button.disabled = true
		if opponent_end_turn:
			opponent_end_turn.visible = false
			opponent_end_turn.disabled = true
		if opponent_pass:
			opponent_pass.visible = false
			opponent_pass.disabled = true

func update_mana_ui():
	if $"../".has_node("PlayerMana"):
		$"../PlayerMana".text = str(player_mana)
	var opponent_field = get_parent().get_parent().get_node_or_null("OpponentField")
	if opponent_field and opponent_field.has_node("OpponentMana"):
		opponent_field.get_node("OpponentMana").text = str(opponent_mana)

func use_mana(amount: int):
	player_mana = max(0, player_mana - amount)
	update_mana_ui()
	rpc("deduct_opponent_mana", amount)

@rpc("any_peer")
func deduct_opponent_mana(amount: int):
	opponent_mana = max(0, opponent_mana - amount)
	update_mana_ui()

@rpc("any_peer", "call_local")
func advance_round():
	current_round += 1
	if current_round > 10:
		current_round = 10
	player_mana = min(player_mana + current_round, 10)
	opponent_mana = min(opponent_mana + current_round, 10)
	update_mana_ui()
	
	
	#player_health = STARTING_HEALTH
	#$"../PlayerHealth".text = str(player_health)
	#opponent_health = STARTING_HEALTH
	#$"../OpponentHealth".text = str(opponent_health)


func direct_damage(damage, player_id):
	apply_direct_damage(player_id, damage)
	rpc("apply_direct_damage", player_id, damage)

@rpc("any_peer")
func apply_direct_damage(player_id, damage):
	if multiplayer.get_unique_id() == player_id:
		opponent_health = max(0, opponent_health - damage)
		get_parent().get_parent().get_node("OpponentField/OpponentHealth").text = str(opponent_health)
	else:
		player_health = max(0, player_health - damage)
		$"../PlayerHealth".text = str(player_health)

func _on_end_turn_button_pressed() -> void:
	if is_my_attacking_phase:
		# ATTACKER ends turn
		has_priority = false
		is_my_attacking_phase = false
		defender_has_passed = false
		apply_priority_state()
		
		$"../CardManager".unselect_selected_tauhan()
		for card in player_cards_that_attacked_this_turn:
			if card.ability_script != null and card.ability_script.has_method("end_turn_reset"):
				card.ability_script.end_turn_reset()
		player_cards_that_attacked_this_turn = []
		update_status_ui()
		rpc("change_turn_to_opponent")
	else:
		# DEFENDER ends turn - end the round
		has_priority = false
		apply_priority_state()
		update_status_ui()
		rpc("change_turn_to_opponent")

func _on_pass_button_pressed() -> void:
	if is_my_attacking_phase:
		# Attacker passes at round start (no cards played) - give priority to defender
		has_priority = false
		has_attacker_acted_this_turn = false
		round_has_started = true  # Mark that the round interaction has begun
		defender_played_card_this_turn = false  # Reset for defender's turn
		apply_priority_state()
		update_status_ui()
		rpc("receive_priority", false)
	else:
		# Defender passes - give priority back to attacker
		# At this point, round has started, so attacker can only use EndTurn
		has_priority = false
		apply_priority_state()
		update_status_ui()
		rpc("receive_priority", false)

@rpc("any_peer")
func change_turn_to_opponent():
	if multiplayer.is_server():
		rpc("advance_round")
		
	$"../Deck".reset_draw()
	is_my_attacking_phase = true
	has_priority = true
	has_attacker_acted_this_turn = false  # Fresh attacker turn - no actions taken yet
	defender_has_passed = true # Start with true so attacker can attack if they don't play a card
	
	# NEW: Reset round flags for the new round
	round_has_started = false  # New round hasn't started yet
	attacker_can_only_pass = true  # Attacker can ONLY pass at the very beginning
	defender_played_card_this_turn = false  # Reset defender flag
	
	apply_priority_state()
	update_status_ui()
	$"../Deck".auto_draw()

func yield_priority_after_play():
	# Mark that someone has played a card
	round_has_started = true
	
	# Mark that the attacker has taken an action (played a card)
	if is_my_attacking_phase:
		has_attacker_acted_this_turn = true
	else:
		# Defender played a card
		defender_played_card_this_turn = true
	
	has_priority = false
	apply_priority_state()
	rpc("receive_priority", false)

@rpc("any_peer")
func receive_priority(passed: bool):
	if passed:
		defender_has_passed = true
	else:
		defender_has_passed = false
	
	# If attacker is getting priority back from defender, reset their action flag
	# IMPORTANT: If defender played a card, attacker action flag should NOT be reset
	# because they already had their turn and now get another one to attack/endturn
	if is_my_attacking_phase and not defender_played_card_this_turn:
		has_attacker_acted_this_turn = false
	
	has_priority = true
	apply_priority_state()
	update_status_ui()
	
func direct_attack(attacking_card):
	$"../InputManager".inputs_disabled = true
	end_turn_button_enabled(false)
	player_cards_that_attacked_this_turn.append(attacking_card)
	
	var player_id = multiplayer.get_unique_id()
	rpc ("direct_attack_here_and_replicate_client_opponent", player_id, str(attacking_card.name))
	await direct_attack_here_and_replicate_client_opponent(player_id, str(attacking_card.name))
	
	
	if attacking_card.ability_script:
		await attacking_card.ability_script.trigger_ability(self,attacking_card,$"../InputManager", "after_attack")
	$"../InputManager".inputs_disabled = false
	end_turn_button_enabled(true)
	
@rpc("any_peer")
func direct_attack_here_and_replicate_client_opponent(player_id, attacking_card_name):
	var attacking_card
	var attack_pos_y
	
	if multiplayer.get_unique_id() == player_id:
		attacking_card = $"../CardManager".get_node(attacking_card_name)
		attack_pos_y = 0 
	else: 
		attacking_card = get_parent().get_parent().get_node("OpponentField/CardManager/"+ attacking_card_name)
		attack_pos_y = 1080

	var new_pos = Vector2(attacking_card.position.x,attack_pos_y)
	
	attacking_card.z_index = 5
	
	var tween = get_tree().create_tween()
	tween.tween_property(attacking_card, "position", new_pos, MOVE_SPEED)
	await wait (0.15)

	if multiplayer.get_unique_id() == player_id:
		opponent_health = max(0, opponent_health - attacking_card.attack)
		get_parent().get_parent().get_node("OpponentField/OpponentHealth").text = str(opponent_health)
	else:
		player_health = max(0, player_health - attacking_card.attack)
		$"../PlayerHealth".text = str(player_health)

	# Animate the card back to its slot
	if attacking_card.card_slot_card_is_in:
		var tween2 = get_tree().create_tween()
		tween2.tween_property(attacking_card, "position", attacking_card.card_slot_card_is_in.position, MOVE_SPEED)

	attacking_card.z_index = 1
	await wait(1.0)


func attack(attacking_card, defending_card):
	$"../InputManager".inputs_disabled = true
	end_turn_button_enabled(false)
	$"../CardManager".selected_tauhan = null
	player_cards_that_attacked_this_turn.append(attacking_card)
	
	var player_id = multiplayer.get_unique_id()
	
	attack_here_and_replicate_client_opponent(player_id,str(attacking_card.name),str(defending_card.name))
	rpc("attack_here_and_replicate_client_opponent", player_id,str(attacking_card.name), str(defending_card.name))
	

	if attacking_card.ability_script:
		await attacking_card.ability_script.trigger_ability(self,attacking_card,$"../InputManager","after_attack")
	$"../InputManager".inputs_disabled = false
	end_turn_button_enabled(true)
	

@rpc("any_peer")
func attack_here_and_replicate_client_opponent(player_id, attacking_card_name, defending_card_name):
	var attacking_card
	var defending_card
	var y_offset

	if multiplayer.get_unique_id() == player_id:
		attacking_card = $"../CardManager".get_node(attacking_card_name)
		defending_card = get_parent().get_parent().get_node("OpponentField/CardManager/"+ defending_card_name)
		y_offset = BATTLE_POS_OFFSET
	
	else:
		attacking_card = get_parent().get_parent().get_node("OpponentField/CardManager/"+ attacking_card_name)
		defending_card = $"../CardManager".get_node(defending_card_name)
		y_offset = -BATTLE_POS_OFFSET
	
	
	attacking_card.z_index = 5
	defending_card.z_index = 5
	
	var new_pos = Vector2(defending_card.position.x,defending_card.position.y + y_offset)
	var tween = get_tree().create_tween()
	tween.tween_property(attacking_card, "position", new_pos, MOVE_SPEED)
	await wait (0.15)
	
	if attacking_card.card_slot_card_is_in:
		var tween2 = get_tree().create_tween()
		tween2.tween_property(attacking_card, "position", attacking_card.card_slot_card_is_in.position, MOVE_SPEED)
	else:
		push_error("attacking_card.card_slot_card_is_in is null for card: ", attacking_card.name)


	if defending_card.health != null:
		defending_card.health = max(0, defending_card.health - attacking_card.attack)
		defending_card.get_node("Health").text = str(defending_card.health)
	if attacking_card.health != null:
		attacking_card.health = max(0, attacking_card.health - defending_card.attack)
		attacking_card.get_node("Health").text = str(attacking_card.health)
	
	
	await wait(1.0)
	attacking_card.z_index = 1
	defending_card.z_index = 1
	
	var card_was_destroyed = false
	if attacking_card.health == 0:
		if multiplayer.get_unique_id() == player_id:
			destroy_card(attacking_card, "Player")
		else:
			destroy_card(attacking_card, "Opponent")
		card_was_destroyed = true
	if defending_card.health == 0:
		if multiplayer.get_unique_id() == player_id:
			destroy_card(defending_card, "Opponent")
		else:
			destroy_card(defending_card, "Player")
		card_was_destroyed = true

	if card_was_destroyed:
		await wait (1.0)
		
	

	

func destroy_card(card, card_owner):
	var new_pos
	if card_owner == "Player":
		
		card.get_node("Area2D/CollisionShape2D").disabled = true
		new_pos = $"../PlayerDiscard".position
		if card in player_cards_on_battlefield:
			player_cards_on_battlefield.erase(card)
		if card.card_slot_card_is_in:
			card.card_slot_card_is_in.get_node("Area2D/CollisionShape2D").disabled = false
	else:
		new_pos = get_parent().get_parent().get_node("OpponentField/OpponentDiscard").position
		if card in opponent_cards_on_battlefield:
			opponent_cards_on_battlefield.erase(card)
	
	
	card.defeated = true
	if card.card_slot_card_is_in:
		card.card_slot_card_is_in.card_in_slot = false
		card.card_slot_card_is_in = null
	
	card.z_index = 2  # Ensure discarded card appears above the discard pile sprite
	var tween = get_tree().create_tween()
	tween.tween_property(card,"position", new_pos, MOVE_SPEED)

func enemy_card_selected(defending_card):
	var attacking_card = $"../CardManager".selected_tauhan
	if attacking_card:
		if defending_card in opponent_cards_on_battlefield:
				$"../CardManager".selected_tauhan = null
				attack(attacking_card, defending_card)


@rpc("any_peer")
func replicate_ability_trigger(player_id: int, card_name: String, ability_trigger_event: String) -> void:
	var card: Node = null
	
	if multiplayer.get_unique_id() == player_id:
		card = $"../CardManager".get_node(card_name)
		# Only player cards have ability_script property
		if card and card.ability_script:
			await card.ability_script.trigger_ability(self, card, $"../InputManager", ability_trigger_event)
	else:
		# Opponent cards don't have abilities, so we don't need to do anything
		pass

@rpc("any_peer")
func apply_paninira_damage(player_id: int, paninira_card_name: String) -> void:
	var cards_to_damage: Array = []
	var target_owner_label: String = ""
	
	if multiplayer.get_unique_id() == player_id:
		# Perspective of the player who played Paninira: damage opponent cards
		cards_to_damage = opponent_cards_on_battlefield.duplicate()
		target_owner_label = "Opponent"
	else:
		# Perspective of the opponent: damage player cards
		cards_to_damage = player_cards_on_battlefield.duplicate()
		target_owner_label = "Player"
		
	const PANINIRA_DAMAGE: int = 1
	var cards_to_destroy: Array = []
	
	# Deal 1 damage to targeted cards
	for card in cards_to_damage:
		if card.health != null:
			card.health = max(0, card.health - PANINIRA_DAMAGE)
			card.get_node("Health").text = str(card.health)
			if card.health == 0:
				cards_to_destroy.append(card)
	
	await wait(1.0)
	
	# Destroy cards that reached 0 health
	for card in cards_to_destroy:
		destroy_card(card, target_owner_label)
	
	# Destroy the Paninira card itself
	var paninira_card: Node = null
	if multiplayer.get_unique_id() == player_id:
		paninira_card = $"../CardManager".get_node(paninira_card_name)
		destroy_card(paninira_card, "Player")
	else:
		var card_path = "OpponentField/CardManager/" + paninira_card_name
		paninira_card = get_parent().get_parent().get_node(card_path)
		destroy_card(paninira_card, "Opponent")
	
	await wait(1.0)

	
func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout
	

func end_turn_button_enabled(is_enabled: bool) -> void:
	var end_turn_button: TextureButton = $"../ENDTURNBUTTON"
	var pass_button: TextureButton = $"../PASSBUTTON"
	var main_node: Node = get_parent().get_parent()
	var opponent_end_turn: TextureButton = main_node.get_node_or_null("OpponentField/ENDTURNBUTTON")
	var opponent_pass: TextureButton = main_node.get_node_or_null("OpponentField/PASSBUTTON")
	
	if is_enabled:
		end_turn_button.visible = true
		end_turn_button.disabled = false
		pass_button.visible = false
		pass_button.disabled = false
		if opponent_end_turn:
			opponent_end_turn.visible = false
			opponent_end_turn.disabled = true
		if opponent_pass:
			opponent_pass.visible = false
			opponent_pass.disabled = true
	else:
		end_turn_button.visible = false
		end_turn_button.disabled = true
		pass_button.visible = false
		pass_button.disabled = true
		if opponent_end_turn:
			opponent_end_turn.visible = false
			opponent_end_turn.disabled = true
		if opponent_pass:
			opponent_pass.visible = false
			opponent_pass.disabled = true
