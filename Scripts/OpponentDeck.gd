extends Node2D

const CARD_SCENE_PATH = "res://Scenes/OpponentCard.tscn"
const CARD_DRAW_SPEED = 0.2 
const STARTING_HAND_SIZE = 5

var card_database_reference
var deck_size

func _ready() -> void:
	#$RichTextLabel.text = str(opponent_deck.size())
	card_database_reference = preload("res://Scripts/CardDatabase.gd")
	#for i in range(STARTING_HAND_SIZE):
		#draw_card()



func draw_card(card_drawn_name):
	deck_size -= 1
	if deck_size == 0:
		visible = false
	else:
		$CardCount.text = str(deck_size)
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	var card_image_path = str("res://Assets/" + card_drawn_name + "Card.png")
	new_card.get_node("CardImage").texture = load(card_image_path)
	new_card.mana = card_database_reference.CARDS[card_drawn_name][2]
	# OpponentCards might not have a Mana text or Ability visible, but we can set it if it exists.
	if new_card.has_node("Mana"):
		new_card.get_node("Mana").text = str(new_card.mana)
	new_card.card_type = card_database_reference.CARDS[card_drawn_name][3]
	if new_card.card_type == "Tauhan":
		new_card.attack = card_database_reference.CARDS[card_drawn_name][0]
		new_card.get_node("Attack").text = str(new_card.attack)
		new_card.health = card_database_reference.CARDS[card_drawn_name][1]
		new_card.get_node("Health").text = str(new_card.health)
	else:
		new_card.get_node("Attack").visible = false
		new_card.get_node("Health").visible = false
	$"../CardManager".add_child(new_card)
	new_card.name = "Card"
	$"../OpponentHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
