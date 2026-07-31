class_name Main
extends Node
## Переключает только верхние экраны. Игровой мир не остаётся жить под меню.

const MENU_SCENE: PackedScene = preload("res://scenes/MainMenu.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/Game.tscn")

var active_menu: MainMenu
var active_game: Game

func _ready() -> void:
	show_menu()

func show_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if active_game != null and is_instance_valid(active_game):
		active_game.queue_free()
	active_game = null
	if active_menu != null and is_instance_valid(active_menu):
		active_menu.queue_free()
	active_menu = MENU_SCENE.instantiate() as MainMenu
	add_child(active_menu)
	active_menu.manual_requested.connect(_start_manual)
	active_menu.evolution_requested.connect(_start_evolution)
	active_menu.exit_requested.connect(_exit_game)

func _start_manual() -> void:
	_start_game(Game.Mode.MANUAL)

func _start_evolution() -> void:
	_start_game(Game.Mode.EVOLUTION)

func _start_game(selected_mode: int) -> void:
	if active_menu != null and is_instance_valid(active_menu):
		active_menu.queue_free()
	active_menu = null
	active_game = GAME_SCENE.instantiate() as Game
	active_game.mode = selected_mode
	add_child(active_game)
	active_game.restart_requested.connect(_restart_game)
	active_game.menu_requested.connect(show_menu)

func _restart_game(selected_mode: int) -> void:
	if active_game != null and is_instance_valid(active_game):
		active_game.queue_free()
	active_game = null
	_start_game(selected_mode)

func _exit_game() -> void:
	get_tree().quit()
