# `intro crawl: readable line window survives browser-height changes — guards
# against a fixed cinematic speed that ends the story before it can be read`.
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	_run()

func _run() -> void:
	for viewport_height in [360.0, 540.0, 720.0]:
		var duration: float = IntroCrawl.readable_scroll_duration(viewport_height, 480.0)
		var speed: float = (viewport_height + 480.0 + IntroCrawl.SCROLL_EXIT_PADDING) / duration
		var visible_seconds: float = viewport_height / speed
		if visible_seconds < IntroCrawl.MIN_LINE_VISIBLE_SECONDS:
			_failures.append("%dpx viewport leaves a line visible for %.2fs" % [viewport_height, visible_seconds])
	if IntroCrawl.readable_scroll_duration(720.0, 480.0) < IntroCrawl.MIN_SCROLL_DURATION:
		_failures.append("ordinary browser crawl is shorter than the minimum readable duration")
	for failure in _failures:
		print("INTRO-CRAWL FAILURE: " + failure)
	print("intro crawl readability: clean" if _failures.is_empty() else "intro crawl readability: %d failure(s)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
