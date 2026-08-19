extends Node

## Singleton for logging structured game events.
## Supports top-level events and subevents (e.g. individual combat steps under a combat event).

signal event_logged(event: GameEvent)
signal subevent_logged(event: GameEvent, parent: GameEvent)

var events: Array[GameEvent] = []


## Store a top-level event and emit event_logged.
func log_event(event: GameEvent) -> GameEvent:
	events.append(event)
	event_logged.emit(event)
	return event


## Convenience wrapper: create a GameEvent and log it.
func log(title: String, text: String = "", parameters: Dictionary = {}) -> GameEvent:
	var event := GameEvent.new()
	event.title = title
	event.text = text
	event.parameters = parameters
	return log_event(event)


## Attach an event as a subevent of the last top-level event.
## Falls back to top-level logging if no events exist yet.
func log_subevent(event: GameEvent) -> GameEvent:
	if events.is_empty():
		push_warning("EventLog: log_subevent called with no parent events — logging as top-level.")
		return log_event(event)
	var parent: GameEvent = events.back()
	parent.subevents.append(event)
	subevent_logged.emit(event, parent)
	return event


## Convenience wrapper: create a GameEvent and attach it as a subevent of the last event.
func log_sub(title: String, text: String = "", parameters: Dictionary = {}) -> GameEvent:
	var event := GameEvent.new()
	event.title = title
	event.text = text
	event.parameters = parameters
	return log_subevent(event)
