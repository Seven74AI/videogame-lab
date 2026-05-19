# ═══════════════════════════════════════════════════════════════
# TutorialOverlay — CanvasLayer scene
# Displays tutorial step text with a styled panel.
# Subscribes to TutorialManager.tutorial_step_changed signal.
# Hides when tutorial is complete.
# ═══════════════════════════════════════════════════════════════
extends CanvasLayer

@onready var _panel: Panel = $Panel
@onready var _title_label: Label = $Panel/VBox/TitleLabel
@onready var _body_label: Label = $Panel/VBox/BodyLabel
@onready var _hint_label: Label = $Panel/VBox/HintLabel

var _visible_steps: int = 0  # Track total steps shown (for counter)


func _ready() -> void:
	var tm := get_node_or_null("/root/TutorialManager")
	if tm:
		tm.tutorial_started.connect(_on_tutorial_started)
		tm.tutorial_step_changed.connect(_on_tutorial_step_changed)
		tm.tutorial_completed.connect(_on_tutorial_completed)
		# If tutorial already active when this scene loads
		if tm.is_tutorial_active():
			_on_tutorial_started()
			var sd: Dictionary = tm.get_current_step_data()
			if not sd.is_empty():
				_on_tutorial_step_changed(tm.get_current_step(), sd)

	hide()


func _on_tutorial_started() -> void:
	_visible_steps = 0
	show()


func _on_tutorial_step_changed(step_idx: int, step_data: Dictionary) -> void:
	_visible_steps += 1
	var tm := get_node_or_null("/root/TutorialManager")
	var total: int = 0
	if tm:
		total = tm.STEPS.size()

	var step_id: String = step_data.get("id", "?")
	var step_title: String = _step_title(step_id)
	var step_text: String = step_data.get("text", "")
	var block_input: bool = step_data.get("block_input", false)

	_title_label.text = "%s  (step %d/%d)" % [step_title, _visible_steps, total]
	_body_label.text = step_text

	if block_input:
		_hint_label.text = "Press any key or click to continue..."
	else:
		_hint_label.text = "Follow the instructions above to advance."

	show()


func _on_tutorial_completed() -> void:
	# Brief final message, then hide
	_title_label.text = "Tutorial Complete!"
	_body_label.text = "You're ready to grow. Good luck!"
	_hint_label.text = ""

	# Auto-hide after 2 seconds
	var t := create_tween()
	t.tween_callback(hide).set_delay(2.5)
	# Then ensure we stay hidden
	t.tween_callback(_final_hide).set_delay(0.0)


func _final_hide() -> void:
	hide()


func _step_title(step_id: String) -> String:
	match step_id:
		"welcome": return "Welcome!"
		"grow": return "Growing"
		"resources": return "Resources"
		"trade": return "Trading"
		"rivals": return "Rivals"
		"advanced": return "Advanced"
		_: return step_id.capitalize()
