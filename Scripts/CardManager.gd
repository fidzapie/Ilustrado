extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2
const DEFAULT_CARD_MOVE_SPEED = 0.1
const DEFAULT_CARD_SCALE = 0.4
const CARD_BIGGER_SCALE = 0.45
const CARD_SMALLER_SCALE = 0.32

var screen_size
var card_being_dragged
var is_hovering_on_card
var player_hand_reference
var selected_tauhan

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = $"../PlayerHand"
	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x), 
			clamp(mouse_pos.y, 0, screen_size.y))
	
	
func card_clicked(card):
	# Card in slot on battlefield
	if card.card_slot_card_is_in:
		# Only Tauhan cards can attack
		if card.card_type != "Tauhan":
			return
		
		# ONLY ALLOW ATTACKS IF PLAYER HAS PRIORITY AND IS ATTACKING PHASE
		if not $"../BattleManager".has_priority or not $"../BattleManager".is_my_attacking_phase:
			return
		
		# Cannot attack with same card twice in one round
		if card in $"../BattleManager".player_cards_that_attacked_this_turn:
			return
		
		# If opponent has no cards, can attack directly to health
		if $"../BattleManager".opponent_cards_on_battlefield.size() == 0:
			$"../BattleManager".direct_attack(card)
		else:
			# Select card to attack opponent's card
			select_card_for_battle(card)
	else:
		# Card in hand - only play cards if player has priority
		if not $"../BattleManager".has_priority:
			return
		# Card in hand - start dragging to play
		start_drag(card)
			
			
func select_card_for_battle(card):
	# Check if Tauhan already selected
	if selected_tauhan:
		#If this card selected
		if selected_tauhan == card:
			card.position.y += 20
			selected_tauhan = null
		# If different card selected
		else:
			selected_tauhan.position.y += 20
			selected_tauhan =card
			card.position.y -= 20
	else:
		selected_tauhan = card
		card.position.y -= 20
	
	
	
	
	
	

func start_drag(card):
	card_being_dragged = card
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	
func finish_drag():
	card_being_dragged.scale = Vector2(CARD_BIGGER_SCALE, CARD_BIGGER_SCALE)
	var card_slot_found = raycast_check_for_card_slot()
	if card_slot_found and not card_slot_found.card_in_slot:
		#if the card can be placed in this slot
		if card_being_dragged.card_type == card_slot_found.card_slot_type:
			if $"../BattleManager".player_mana < card_being_dragged.mana:
				player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
				card_being_dragged = null
				return
				
			var player_id = multiplayer.get_unique_id()
			play_card_here_and_for_clients_opponent(player_id, str(card_being_dragged.name), str(card_slot_found.name))
			rpc("play_card_here_and_for_clients_opponent", player_id, str(card_being_dragged.name), str(card_slot_found.name))
			
			$"../BattleManager".use_mana(card_being_dragged.mana)
			
			
			
			
			
			
			
			
			
			
			if card_being_dragged.card_type == "Tauhan":
				$"../BattleManager". player_cards_on_battlefield.append(card_being_dragged)
			if card_being_dragged.ability_script:
				var card_name: String = str(card_being_dragged.name)
				$"../BattleManager".replicate_ability_trigger(player_id, card_name, "card_placed")
				$"../BattleManager".rpc("replicate_ability_trigger", player_id, card_name, "card_placed")
			
			# Only yield priority if a Tauhan card was played
			# Hakbang (effect) cards like Paninira do NOT yield priority
			if card_being_dragged.card_type == "Tauhan":
				$"../BattleManager".yield_priority_after_play()
				
			card_being_dragged = null
			return 
	player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
	card_being_dragged = null

@rpc("any_peer")
func play_card_here_and_for_clients_opponent(player_id, card_name, card_slot_name):
	AudioManager.play_play_card()
	var card
	var card_slot
	
	
	if multiplayer.get_unique_id() == player_id:
		card = get_node(card_name)
		card_slot = $"../CardSlots".get_node(card_slot_name)
		print(card)
		is_hovering_on_card = false
		player_hand_reference.remove_card_from_hand(card_being_dragged)
		card.position = card_slot.position
		card.get_node("AnimationPlayer").play("card_flip")  # Play flip animation for player card
		card_slot.get_node("Area2D/CollisionShape2D").disabled = true
	else:
		var opponent_field_ref = get_parent().get_parent().get_node("OpponentField")
		card = opponent_field_ref.get_node("CardManager/" + card_name)
		card_slot = opponent_field_ref.get_node("CardSlots/"+ card_slot_name)
		opponent_field_ref.get_node("OpponentHand").remove_card_from_hand(card)
		var tween = get_tree().create_tween()
		tween.tween_property(card,"position", card_slot.position, DEFAULT_CARD_MOVE_SPEED)
		card.get_node("AnimationPlayer").play("card_flip")
		$"../BattleManager".opponent_cards_on_battlefield.append(card)
	
	
	card.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
	card.z_index = 1  # Ensure card appears above the slot sprite
	card.card_slot_card_is_in = card_slot
	card_slot.card_in_slot = true 
	
	
	
func unselect_selected_tauhan():
	if selected_tauhan:
		selected_tauhan.position.y += 20
		selected_tauhan =null


func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)

func on_left_click_released():
	if card_being_dragged:
		finish_drag()


func on_hovered_over_card(card):
	if card.card_slot_card_is_in:
		return
	if !is_hovering_on_card:
		is_hovering_on_card = true
		highlight_card(card, true)
	
	
func on_hovered_off_card(card):
	if !card.defeated:
		# Checekd if card is NOT in a card slot and NOT being dragged
		if !card.card_slot_card_is_in && !card_being_dragged:
			#if not dragging
			highlight_card(card,false)
			var new_card_hovered = raycast_check_for_card()
			if new_card_hovered:
				highlight_card(new_card_hovered, true)
			else:
				is_hovering_on_card = false



func highlight_card(card, hovered):
	if card.card_slot_card_is_in:
		return
		
	if hovered:
		card.scale = Vector2(CARD_BIGGER_SCALE, CARD_BIGGER_SCALE)
		card.z_index = 2 
	else:
		card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
		card.z_index = 1 


func raycast_check_for_card_slot():
	var space_state = get_world_2d(). direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()	
	return null


func raycast_check_for_card():
	var space_state = get_world_2d(). direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		#return result[0].collider.get_parent()
		return get_card_with_highest_z_index(result)
	return null
	
func get_card_with_highest_z_index(cards):
		
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index
	
	
	
	for i in range (1, cards.size()):
		var current_card = cards[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card
