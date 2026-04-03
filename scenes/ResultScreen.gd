extends Control

@onready var result_label = $Panel/CenterContainer/VBoxContainer/ResultLabel
@onready var play_again_button: Button = $Panel/CenterContainer/VBoxContainer/PlayAgain
@onready var quit_button: Button = $Panel/CenterContainer/VBoxContainer/Quit

var is_victory: bool = true

func _ready() -> void:
	if is_victory:
		result_label.text = "You Win!"
	else:
		result_label.text = "You Lose!"

	quit_button.text = "Main Menu"
	play_again_button.pressed.connect(_on_play_again)
	quit_button.pressed.connect(_on_quit)

func _on_play_again() -> void:
	SaveManager.clear_save()
	PlayerData.reset_run()
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")

func _on_quit() -> void:
	SaveManager.clear_save()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_play_again_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	pass
