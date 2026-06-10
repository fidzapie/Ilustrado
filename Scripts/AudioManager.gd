extends Node

var bg_music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

var bg_music = load("res://Assets/Audio/BackgroundMusic.mp3")
var card_strike = load("res://Assets/Audio/CardStrike.wav")
var card_draw_start = load("res://Assets/Audio/CardDrawStartingGame.wav")
var card_draw = load("res://Assets/Audio/CardDraw.wav")
var itak = load("res://Assets/Audio/Itak.mp3")
var direct_damage = load("res://Assets/Audio/CardDealDamagtoOpponentsHP.wav")
var play_card_sfx = load("res://Assets/Audio/PlayCards.wav")
var paninira_sfx = load("res://Assets/Audio/PaniniraAudio.mp3")

func _ready() -> void:
	bg_music_player = AudioStreamPlayer.new()
	add_child(bg_music_player)
	
	for i in range(10):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

func play_bg_music() -> void:
	if bg_music_player.stream != bg_music:
		bg_music_player.stream = bg_music
		bg_music_player.play()

func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	sfx_players[0].stream = stream
	sfx_players[0].play()

func play_card_strike() -> void: play_sfx(card_strike)
func play_card_draw_start() -> void: play_sfx(card_draw_start)
func play_card_draw() -> void: play_sfx(card_draw)
func play_itak() -> void: play_sfx(itak)
func play_direct_damage() -> void: play_sfx(direct_damage)
func play_play_card() -> void: play_sfx(play_card_sfx)
func play_paninira() -> void: play_sfx(paninira_sfx)
