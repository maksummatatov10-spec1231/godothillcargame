class_name PauseMenu
extends Control
## Отдельный экран паузы всегда обрабатывает ввод, даже когда дерево остановлено.

signal resume_requested
signal restart_requested
signal menu_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = Color("071019bb")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var card: PanelContainer = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-175.0, -145.0)
	card.size = Vector2(350.0, 290.0)
	card.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PANEL_DARK, 20))
	add_child(card)
	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var title: Label = UIStyle.make_label("Пауза", 30, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var resume: Button = UIStyle.make_button("Продолжить")
	resume.pressed.connect(_on_resume)
	content.add_child(resume)
	var restart: Button = UIStyle.make_button("Начать заново", Color("c9ddf0"))
	restart.pressed.connect(_on_restart)
	content.add_child(restart)
	var menu: Button = UIStyle.make_button("Главное меню", UIStyle.DANGER)
	menu.pressed.connect(_on_menu)
	content.add_child(menu)

func open() -> void:
	visible = true

func close() -> void:
	visible = false

func _on_resume() -> void:
	resume_requested.emit()

func _on_restart() -> void:
	restart_requested.emit()

func _on_menu() -> void:
	menu_requested.emit()
