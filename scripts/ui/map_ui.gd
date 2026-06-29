extends Control

var main: Node
var map: Node

@onready var turn_counter: Label = $VBoxContainer/TopTab/TurnCounter
@onready var current_phase: Label = $VBoxContainer/TopTab/CurrentPhase
@onready var ravage_value: Label = $VBoxContainer/TopTab/InvaderTrack/InvaderTrackSlots/RavageSlot/RavageValue
@onready var build_value: Label = $VBoxContainer/TopTab/InvaderTrack/InvaderTrackSlots/BuildSlot/BuildValue
@onready var explore_value: Label = $VBoxContainer/TopTab/InvaderTrack/InvaderTrackSlots/ExploreSlot/ExploreValue

signal next_phase

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_status_change(reason):
	print("mapUi %s received status change. reason: %s" % [name, reason])
	turn_counter.text = "Turn: " + str(map.turn_counter)
	current_phase.text = "Current Phase: " + str(map.current_phase)
	ravage_value.text = map.upcoming_ravage
	build_value.text = map.upcoming_build
	explore_value.text = map.upcoming_explore

func _on_phase_change_trigger(new_phase):
	pass

func _on_next_phase_pressed() -> void:
	next_phase.emit()
