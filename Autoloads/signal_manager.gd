extends Node

## Signals queued to be emitted after X frames
var frame_delays:Dictionary[Signal, int] = {}
## Signals queued to be emitted after X seconds
#var time_delays:Dictionary[Signal, float] = {}
## Deadtime before this signals are allowed to be emitted again from here
#var deadtimes::Dictionary[Signal, float] = {}


# Will make sure it is emited this frame, but only once
func emit_this_frame(sig:Signal)-> void:
	frame_delays[sig] = 0
	
	
func _process(_delta: float) -> void:	
	for sig in frame_delays.duplicate():
		frame_delays[sig] -= 1
		if frame_delays[sig] <= 0:
			sig.emit()
			frame_delays.erase(sig)
