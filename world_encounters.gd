extends Node

var distance_in_pixels: float = 0.0:
	set(value):
		distance_in_pixels = value
		%Distance.text = "%d" % distance_in_pixels

var previous_position: Vector3

@export var player: CharacterBody3D


func _ready():
	previous_position = player.global_position


func _process(_delta):
	var current_position = player.global_position
	var distance_moved = previous_position.distance_to(current_position)

	distance_in_pixels += distance_moved
	previous_position = current_position
