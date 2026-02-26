@tool
extends Control
class_name BaseAmountIndicator

enum IconPosition {Right, Left, Top, Bottom, Hidden}
enum ArrowsPosition {Hidden, Right, Top}
enum NumberFormat {Plain, RKM, Suffix}

signal amount_changed(new_value:float)
signal amount_change_requested(delta:float)

@export var icon:Texture2D : set = set_icon
@export var amount:float = 0.0 : set = set_amount
@export var max_amount:float = 1e18 : set = set_max_amount
@export var min_amount:float = 0.0 : set = set_min_amount

@export_group("Layout")
@export var icon_position:IconPosition = IconPosition.Right : set = set_icon_position
@export var arrows_position:ArrowsPosition = ArrowsPosition.Hidden : set = set_arrows_position

@export_group("Display")
@export var number_format:NumberFormat = NumberFormat.Plain : set = set_number_format
@export var right_hand_figures:int = 1 : set = set_right_hand_figures
@export var show_max:bool = false : set = set_show_max
@export var show_if_zero:bool = true : set = set_show_if_zero

@export_group("Arrows")
@export var step_change:float = 1.0
@export var auto_adjust_step:bool = false
@export var allow_internal_changes:bool = true : set = set_allow_internal_changes


func _ready()-> void:
	%MoreButton.pressed.connect(_on_more_pressed)
	%LessButton.pressed.connect(_on_less_pressed)
	make()
	

func set_icon(new_value:Texture2D)-> void:
	icon = new_value
	if not is_node_ready(): return


func set_amount(new_value:float)-> void:
	var clamped:float = clamp(new_value, min_amount, max_amount)
	if clamped == amount: return
	amount = clamped
	amount_changed.emit(amount)
	update_info()


func set_max_amount(new_value:float)-> void:
	max_amount = new_value
	var clamped:float = clamp(amount, min_amount, max_amount)
	if clamped != amount:
		amount = clamped
		amount_changed.emit(amount)
	update_info()


func set_min_amount(new_value:float)-> void:
	min_amount = new_value
	var clamped:float = clamp(amount, min_amount, max_amount)
	if clamped != amount:
		amount = clamped
		amount_changed.emit(amount)


func set_icon_position(new_value:IconPosition)-> void:
	icon_position = new_value
	update_layout()


func set_arrows_position(new_value:ArrowsPosition)-> void:
	arrows_position = new_value
	update_layout()


func set_number_format(new_value:NumberFormat)-> void:
	number_format = new_value
	update_info()


func set_right_hand_figures(new_value:int)-> void:
	right_hand_figures = new_value
	update_info()


func set_show_max(new_value:bool)-> void:
	show_max = new_value
	update_info()


func set_show_if_zero(new_value:bool)-> void:
	show_if_zero = new_value
	update_info()


func set_allow_internal_changes(new_value:bool)-> void:
	allow_internal_changes = new_value




func update_layout()-> void:
	if not is_node_ready(): return

	match icon_position:
		IconPosition.Hidden:
			%IconWrapper.visible = false
			%InnerGrid.columns = 1
		IconPosition.Right:
			%IconWrapper.visible = true
			%InnerGrid.columns = 2
			%InnerGrid.move_child(%AmountArea, 0)
			%InnerGrid.move_child(%IconWrapper, 1)
		IconPosition.Left:
			%IconWrapper.visible = true
			%InnerGrid.columns = 2
			%InnerGrid.move_child(%IconWrapper, 0)
			%InnerGrid.move_child(%AmountArea, 1)
		IconPosition.Top:
			%IconWrapper.visible = true
			%InnerGrid.columns = 1
			%InnerGrid.move_child(%IconWrapper, 0)
			%InnerGrid.move_child(%AmountArea, 1)
		IconPosition.Bottom:
			%IconWrapper.visible = true
			%InnerGrid.columns = 1
			%InnerGrid.move_child(%AmountArea, 0)
			%InnerGrid.move_child(%IconWrapper, 1)

	match arrows_position:
		ArrowsPosition.Hidden:
			%ArrowsContainer.visible = false
		ArrowsPosition.Right:
			%ArrowsContainer.visible = true
			%OuterGrid.columns = 2
			%OuterGrid.move_child(%InnerGrid, 0)
			%OuterGrid.move_child(%ArrowsContainer, 1)
		ArrowsPosition.Top:
			%ArrowsContainer.visible = true
			%OuterGrid.columns = 1
			%OuterGrid.move_child(%ArrowsContainer, 0)
			%OuterGrid.move_child(%InnerGrid, 1)


func make()-> void:
	if not is_node_ready(): return
	%Icon.texture = icon
	update_layout()
	update_info()
	
	
func update_info()-> void:
	if not is_node_ready(): return
	
	%AmountLabel.text = _format_amount(amount)
	%SlashLabel.visible = show_max
	%MaxLabel.visible = show_max
	if show_max:
		%MaxLabel.text = _format_amount(max_amount)
	visible = show_if_zero or amount != 0


func _format_amount(value:float)-> String:
	match number_format:
		NumberFormat.RKM:
			return Utils.format_as_rkm(value, right_hand_figures)
		NumberFormat.Suffix:
			return Utils.format_with_suffix(value, right_hand_figures)
		_:
			if right_hand_figures <= 0:
				return str(int(value))
			return ("%." + str(right_hand_figures) + "f") % value
	return str(value)


func _on_more_pressed()-> void:
	var step:float = _get_step()
	if allow_internal_changes:
		set_amount(amount + step)
	else:
		amount_change_requested.emit(step)


func _on_less_pressed()-> void:
	var step:float = _get_step()
	if allow_internal_changes:
		set_amount(amount - step)
	else:
		amount_change_requested.emit(-step)


func _get_step()-> float:
	if auto_adjust_step:
		var order:int = Utils.get_magnitude_order(amount)
		return pow(10, max(order - 1, 0))
	return step_change
