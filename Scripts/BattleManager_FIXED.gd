class_name BattleManager
extends Node

# Battle constants
const SMALL_CARD_SCALE: float = 0.32
const MOVE_SPEED: float = 0.2
const STARTING_HEALTH: int = 10
const BATTLE_POS_OFFSET: int = 25
const MAX_MANA: int = 10

# Battle state
var battle_timer: Timer
var opponent_cards_on_battlefield: Array = []
var player_cards_on_battlefield: Array = []
var player_cards_that_attacked_this_turn: Array = []
var player_health: int
var opponent_health: int

# Round & Mana
var current_round: int = 1
var player_mana: int = 1
var opponent_mana: int = 1

# CORE GAME STATE - Priority and Turn Management
var is_my_attacking_phase: bool = false  # True if I am the attacker
var has_priority: bool = false  # True if I have priority this turn
var defender_has_passed: bool = false  # Track if defender passed

# ============================================================================
# THE KEY FLAG: Tracks if ANY card has been played this entire round
# This is the SINGLE SOURCE OF TRUTH for button visibility logic
# ============================================================================
var any_cards_played_this_round: bool = false

func _ready() -> void:
	battle_timer = $"../BattleTimer"
	battle_timer.one_shot = true
	battle_timer.wait_time = 1.0
	
	# Server starts as attacker with priority
	if multiplayer.is_server():
		is_my_attacking_phase = true
		has_priority = true
	else:
		is_my_attacking_phase = false
		has_priority = false
	
	defender_has_passed = true
	any_cards_played_this_round = false
	
	update_mana_ui()
	update_status_ui()
	apply_priority_state()

# ============================================================================
# UI UPDATES
# ============================================================================

func update_status_ui() -> void:
	var my_status: String = "Attacking" if is_my_attacking_phase else "Defending"
	var opp_status: String = "Defending" if is_my_attacking_phase else "Attacking"
	
	if $"../".has_node("StatusLabel"):
		$"../StatusLabel".text = my_status
	var opponent_field: Node = get_parent().get_parent().get_node_or_null("OpponentField")
	if opponent_field and opponent_field.has_node("StatusLabel"):
		opponent_field.get_node("StatusLabel").text = opp_status

func update_mana_ui() -> void:
	if $"../".has_node("PlayerMana"):
		$"../PlayerMana".text = str(player_mana)
	var opponent_field: Node = get_parent().get_parent().get_node_or_null("OpponentField")
	if opponent_field and opponent_field.has_node("OpponentMana"):
		opponent_field.get_node("OpponentMana").text = str(opponent_mana)

# ============================================================================
# PRIORITY & BUTTON LOGIC - STRICTLY FOLLOWS YOUR GAME RULES
# ============================================================================

func apply_priority_state() -> void:
	var end_turn_button: TextureButton = $"../ENDTURNBUTTON"
	var pass_button: TextureButton = $"../PASSBUTTON"
	var main_node: Node = get_parent().get_parent()
	var opponent_end_turn: TextureButton = main_node.get_node_or_null("OpponentField/ENDTURNBUTTON")
	var opponent_pass: TextureButton = main_node.get_node_or_null("OpponentField/PASSBUTTON")
	
	# Clear all buttons first
	_clear_all_buttons(end_turn_button, pass_button, opponent_end_turn, opponent_pass)
	
	if not has_priority:
		# If I don't have priority, no buttons visible and inputs disabled
		$"../InputManager".inputs_disabled = true
		return
	
	# I HAVE PRIORITY - Enable inputs
	$"../InputManager".inputs_disabled = false
	
	# ========================================================================
	# ATTACKER (Priority Player is attacker)
	# ========================================================================
	if is_my_attacking_phase:
		# RULE: At round start (no cards played), attacker can ONLY PASS
		if not any_cards_played_this_round:
			end_turn_button.visible = false
			end_turn_button.disabled = true
			pass_button.visible = true
			pass_button.disabled = false
		# RULE: After cards played, attacker can ONLY END TURN (or attack until they pass)
		else:
			end_turn_button.visible = true
			end_turn_button.disabled = false
			pass_button.visible = false
			pass_button.disabled = true
	# ========================================================================
	# DEFENDER (Priority Player is defender)
	# ========================================================================
	else:
		# RULE: Defender can ONLY PASS
		# Defender cannot end the round - only attacker can via END TURN
		end_turn_button.visible = false
		end_turn_button.disabled = true
		pass_button.visible = true
		pass_button.disabled = false

func _clear_all_buttons(end_turn_btn: TextureButton, pass_btn: TextureButton, 
						opp_end_btn: TextureButton, opp_pass_btn: TextureButton) -> void:
	end_turn_btn.visible = false
	end_turn_btn.disabled = true
	pass_btn.visible = false
	pass_btn.disabled = true
	if opp_end_btn:
		opp_end_btn.visible = false
		opp_end_btn.disabled = true
	if opp_pass_btn:
		opp_pass_btn.visible = false
		opp_pass_btn.disabled = true

# ============================================================================
# BUTTON CALLBACKS
# ============================================================================

func _on_pass_button_pressed() -> void:
	"""
	PASS: "I don't want to act right now"
	- Transfer priority to opponent
	- Mark that a card hasn't been played yet (attacker at round start case)
	- Does NOT end the round
	"""
	has_priority = false
	apply_priority_state()
	update_status_ui()
	rpc("receive_priority", true)  # true = opponent passed to us

func _on_end_turn_button_pressed() -> void:
	"""
	END TURN: "I want to end the current round"
	- Only available to attacker (after cards played)
	- Ends the round immediately
	- Switches attack token
	- Advances to next round
	"""
	# Only attacker can end turn
	if not is_my_attacking_phase:
		push_error("Defender tried to end turn! This should not be possible.")
		return
	
	has_priority = false
	apply_priority_state()
	update_status_ui()
	
	# Clean up cards that attacked this turn
	$"../CardManager".unselect_selected_tauhan()
	for card: Node in player_cards_that_attacked_this_turn:
		if card.ability_script != null and card.ability_script.has_method("end_turn_reset"):
			card.ability_script.end_turn_reset()
	player_cards_that_attacked_this_turn = []
	
	# End the round - switch attack token and start new round
	rpc("advance_round_and_switch_attacker")

# ============================================================================
# CARD PLAYING
# ============================================================================

func yield_priority_after_play() -> void:
	"""
	Called when a card is played (Tauhan or Hakbang)
	- Mark that a card has been played this round
	- Transfer priority to opponent
	"""
	any_cards_played_this_round = true
	has_priority = false
	apply_priority_state()
	rpc("receive_priority", false)  # false = opponent played a card

@rpc("any_peer")
func receive_priority(opponent_passed: bool) -> void:
	"""
	Receive priority from opponent
	- If opponent passed: just get priority normally
	- If opponent played a card: we get to act (and maybe end turn)
	"""
	has_priority = true
	apply_priority_state()
	update_status_ui()

@rpc("any_peer")
func opponent_auto_draw() -> void:
	"""
	Called when opponent needs to draw a card after mana reset.
	This ensures the opponent draws AFTER their mana has been increased.
	"""
	var opponent_field: Node = get_parent().get_parent().get_node_or_null("OpponentField")
	if opponent_field:
		var opponent_deck: Node = opponent_field.get_node_or_null("OpponentDeck")
		if opponent_deck and opponent_deck.has_method("reset_draw"):
			opponent_deck.reset_draw()
		if opponent_deck and opponent_deck.has_method("auto_draw"):
			opponent_deck.auto_draw()

@rpc("any_peer")
func sync_card_count(player_id: int, card_count: int) -> void:
	"""
	Synchronize card count display between host and client.
	Updates both local and opponent deck card count UI.
	"""
	var main_node: Node = get_parent().get_parent()
	
	if multiplayer.get_unique_id() == player_id:
		# This is my deck - update my card count
		var my_deck: Node = get_node_or_null("../Deck")
		if my_deck and my_deck.has_node("CardCount"):
			my_deck.get_node("CardCount").text = str(card_count)
	else:
		# This is opponent's deck - update opponent card count
		var opponent_deck: Node = main_node.get_node_or_null("OpponentField/OpponentDeck")
		if opponent_deck and opponent_deck.has_node("CardCount"):
			opponent_deck.get_node("CardCount").text = str(card_count)

# ============================================================================
# ROUND MANAGEMENT
# ============================================================================

@rpc("any_peer", "call_local")
func advance_round_and_switch_attacker() -> void:
	"""
	End current round and start new one:
	1. Advance round counter
	2. Increase max mana (up to 10)
	3. Switch attack token (attacker becomes defender, vice versa)
	4. Reset round state
	5. Draw 1 card each (ONLY AFTER mana is reset)
	6. Give priority to new attacker
	"""
	current_round += 1
	if current_round > 10:
		current_round = 10
	
	# Increase mana by round number (capped at 10)
	player_mana = min(player_mana + current_round, MAX_MANA)
	opponent_mana = min(opponent_mana + current_round, MAX_MANA)
	update_mana_ui()
	
	# Switch attack token - attacker becomes defender, defender becomes attacker
	is_my_attacking_phase = !is_my_attacking_phase
	has_priority = is_my_attacking_phase  # New attacker gets priority
	
	# Reset round flags for new round
	any_cards_played_this_round = false
	player_cards_that_attacked_this_turn = []
	defender_has_passed = true
	
	# Apply priority state BEFORE drawing cards so buttons are correctly set
	apply_priority_state()
	update_status_ui()
	
	# Wait briefly to ensure mana UI is fully updated before drawing cards
	await wait(0.3)
	
	# Draw 1 card for each player ONLY AFTER mana has been reset and displayed
	# Reset the draw flag so cards can be drawn this round
	$"../Deck".reset_draw()
	# Both players automatically draw 1 card after mana reset
	$"../Deck".auto_draw()
	# Opponent also draws (handled by their deck through RPC)
	rpc("opponent_auto_draw")

# ============================================================================
# MANA MANAGEMENT
# ============================================================================

func use_mana(amount: int) -> void:
	player_mana = max(0, player_mana - amount)
	update_mana_ui()
	rpc("deduct_opponent_mana", amount)

@rpc("any_peer")
func deduct_opponent_mana(amount: int) -> void:
	opponent_mana = max(0, opponent_mana - amount)
	update_mana_ui()

# ============================================================================
# ATTACK MECHANICS
# ============================================================================

func direct_attack(attacking_card: Node) -> void:
	$"../InputManager".inputs_disabled = true
	player_cards_that_attacked_this_turn.append(attacking_card)
	
	var player_id: int = multiplayer.get_unique_id()
	var card_name: String = str(attacking_card.name)
	
	rpc("direct_attack_here_and_replicate_client_opponent", player_id, card_name)
	await direct_attack_here_and_replicate_client_opponent(player_id, card_name)
	
	if attacking_card.ability_script:
		await attacking_card.ability_script.trigger_ability(self, attacking_card, $"../InputManager", "after_attack")
	
	$"../InputManager".inputs_disabled = false

@rpc("any_peer")
func direct_attack_here_and_replicate_client_opponent(player_id: int, attacking_card_name: String) -> void:
	var attacking_card: Node
	var attack_pos_y: float
	
	if multiplayer.get_unique_id() == player_id:
		attacking_card = $"../CardManager".get_node(attacking_card_name)
		attack_pos_y = 0
	else:
		attacking_card = get_parent().get_parent().get_node("OpponentField/CardManager/" + attacking_card_name)
		attack_pos_y = 1080
	
	var new_pos: Vector2 = Vector2(attacking_card.position.x, attack_pos_y)
	attacking_card.z_index = 5
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(attacking_card, "position", new_pos, MOVE_SPEED)
	await wait(0.15)
	
	# Play sound effect for direct damage to opponent's HP
	AudioManager.play_direct_damage()
	
	if multiplayer.get_unique_id() == player_id:
		opponent_health = max(0, opponent_health - attacking_card.attack)
		get_parent().get_parent().get_node("OpponentField/OpponentHealth").text = str(opponent_health)
	else:
		player_health = max(0, player_health - attacking_card.attack)
		$"../PlayerHealth".text = str(player_health)
	
	if attacking_card.card_slot_card_is_in:
		var tween2: Tween = get_tree().create_tween()
		tween2.tween_property(attacking_card, "position", attacking_card.card_slot_card_is_in.position, MOVE_SPEED)
	
	attacking_card.z_index = 1
	await wait(1.0)

func attack(attacking_card: Node, defending_card: Node) -> void:
	$"../InputManager".inputs_disabled = true
	$"../CardManager".selected_tauhan = null
	player_cards_that_attacked_this_turn.append(attacking_card)
	
	var player_id: int = multiplayer.get_unique_id()
	var attacking_name: String = str(attacking_card.name)
	var defending_name: String = str(defending_card.name)
	
	attack_here_and_replicate_client_opponent(player_id, attacking_name, defending_name)
	rpc("attack_here_and_replicate_client_opponent", player_id, attacking_name, defending_name)
	
	if attacking_card.ability_script:
		await attacking_card.ability_script.trigger_ability(self, attacking_card, $"../InputManager", "after_attack")
	
	$"../InputManager".inputs_disabled = false

@rpc("any_peer")
func attack_here_and_replicate_client_opponent(player_id: int, attacking_card_name: String, defending_card_name: String) -> void:
	var attacking_card: Node
	var defending_card: Node
	var y_offset: float
	
	if multiplayer.get_unique_id() == player_id:
		attacking_card = $"../CardManager".get_node(attacking_card_name)
		defending_card = get_parent().get_parent().get_node("OpponentField/CardManager/" + defending_card_name)
		y_offset = BATTLE_POS_OFFSET
	else:
		attacking_card = get_parent().get_parent().get_node("OpponentField/CardManager/" + attacking_card_name)
		defending_card = $"../CardManager".get_node(defending_card_name)
		y_offset = -BATTLE_POS_OFFSET
	
	attacking_card.z_index = 5
	defending_card.z_index = 5
	
	var new_pos: Vector2 = Vector2(defending_card.position.x, defending_card.position.y + y_offset)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(attacking_card, "position", new_pos, MOVE_SPEED)
	await wait(0.15)
	
	# Play sound effect for card-to-card combat
	AudioManager.play_card_strike()
	
	if attacking_card.card_slot_card_is_in:
		var tween2: Tween = get_tree().create_tween()
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
	
	var card_was_destroyed: bool = false
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
		await wait(1.0)

func destroy_card(card: Node, card_owner: String) -> void:
	var new_pos: Vector2
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
	
	card.z_index = 2
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_pos, MOVE_SPEED)

func enemy_card_selected(defending_card: Node) -> void:
	var attacking_card: Node = $"../CardManager".selected_tauhan
	if attacking_card:
		if defending_card in opponent_cards_on_battlefield:
			$"../CardManager".selected_tauhan = null
			attack(attacking_card, defending_card)

@rpc("any_peer")
func replicate_ability_trigger(player_id: int, card_name: String, ability_trigger_event: String) -> void:
	var card: Node = null
	
	if multiplayer.get_unique_id() == player_id:
		card = $"../CardManager".get_node(card_name)
		if card and card.ability_script:
			await card.ability_script.trigger_ability(self, card, $"../InputManager", ability_trigger_event)

@rpc("any_peer")
func apply_paninira_damage(player_id: int, paninira_card_name: String) -> void:
	var cards_to_damage: Array = []
	var target_owner_label: String = ""
	
	if multiplayer.get_unique_id() == player_id:
		cards_to_damage = opponent_cards_on_battlefield.duplicate()
		target_owner_label = "Opponent"
	else:
		cards_to_damage = player_cards_on_battlefield.duplicate()
		target_owner_label = "Player"
	
	const PANINIRA_DAMAGE: int = 1
	var cards_to_destroy: Array = []
	
	for card: Node in cards_to_damage:
		if card.health != null:
			card.health = max(0, card.health - PANINIRA_DAMAGE)
			card.get_node("Health").text = str(card.health)
			if card.health == 0:
				cards_to_destroy.append(card)
	
	await wait(1.0)
	
	for card: Node in cards_to_destroy:
		destroy_card(card, target_owner_label)
	
	var paninira_card: Node = null
	if multiplayer.get_unique_id() == player_id:
		paninira_card = $"../CardManager".get_node(paninira_card_name)
		destroy_card(paninira_card, "Player")
	else:
		var card_path: String = "OpponentField/CardManager/" + paninira_card_name
		paninira_card = get_parent().get_parent().get_node(card_path)
		destroy_card(paninira_card, "Opponent")
	
	await wait(1.0)

# ============================================================================
# UTILITY
# ============================================================================

func wait(wait_time: float) -> void:
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout
