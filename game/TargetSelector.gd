extends Node

var selectable_characters: Array[Node3D] = []
var selected_index := 0
var selecting := false

@export var cursor_scene: PackedScene

var cursor: Node3D

func register_character(character: Node3D):
	if character.can_be_selected:
		selectable_characters.append(character)
