extends Node2D

const PORT = 1234

const SERVER_ADDRESS = "localhost"

var  peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

var player_scene: Node2D
var opponent_scene: Node2D

@export var player_field_scene : PackedScene
@export var opponent_field_scene : PackedScene

func _on_host_button_pressed() -> void:
	disable_buttons()
	
	peer.create_server(PORT)

	multiplayer.peer_connected.connect(_on_peer_connected)

	multiplayer.multiplayer_peer = peer
	
	
	player_scene = player_field_scene.instantiate()
	add_child(player_scene)
	
	
	opponent_scene = opponent_field_scene.instantiate()
	add_child(opponent_scene)


func _on_join_button_pressed() -> void:
	disable_buttons()
	
	
	peer.create_client(SERVER_ADDRESS,PORT)

	multiplayer.multiplayer_peer = peer

	player_scene = player_field_scene.instantiate()
	add_child(player_scene)
	
	opponent_scene = opponent_field_scene.instantiate()
	add_child(opponent_scene)
	
	player_scene.client_set_up()
		
	
	
func _on_peer_connected(_peer_id: int) -> void:
	player_scene.host_set_up()
	

func disable_buttons():
	$HostButton.disabled = true
	$HostButton.visible = false
	$JoinButton.disabled = true
	$JoinButton.visible = false
