# Custom BBCode [pulse]...[/pulse]: fades the wrapped text's opacity in and out,
# so prompts can flow inline at the end of a caption.
class_name PulseTextEffect
extends RichTextEffect

var bbcode := "pulse"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var t := Time.get_ticks_msec() / 1000.0
	char_fx.color.a *= 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 4.0))
	return true
