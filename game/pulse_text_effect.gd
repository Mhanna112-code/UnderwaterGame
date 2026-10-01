# A RichTextLabel custom BBCode effect - [pulse]Press Enter to continue[/pulse]
# fades the wrapped run's opacity in and out continuously. Exists so "Press
# Enter to continue" can sit right at the end of whatever caption text
# precedes it (wrapping onto the caption's own last line, or its own new
# line only if it doesn't fit - same as any other run of text) instead of
# living in a separate Label below the caption, which always claimed its
# own full row regardless of how much room was actually left.
class_name PulseTextEffect
extends RichTextEffect

var bbcode := "pulse"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var t := Time.get_ticks_msec() / 1000.0
	char_fx.color.a *= 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 4.0))
	return true
