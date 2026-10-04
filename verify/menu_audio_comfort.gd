# OPEN-047 first: actual title hover, not a standalone substitute sound.
extends SceneTree
var findings: Array[String] = []
var audio: UnderwaterAudioManager
var title: TitleScreen
var capture: AudioEffectCapture
var sfx_bus: int
var old_settings: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	audio = root.get_node("GameAudio") as UnderwaterAudioManager
	old_settings = audio.get_audio_settings()
	audio.set_sfx_volume(1.0)
	audio.set_sfx_muted(false)
	# Capture downstream at Master: an effect on SFX itself is pre-fader and
	# cannot prove the user's SFX volume/mute reaches the actual output.
	sfx_bus = AudioServer.get_bus_index("Master")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(sfx_bus, capture)
	title = TitleScreen.new()
	root.add_child(title)
	await process_frame
	title.open()
	await process_frame
	var button := _button(title, "New Game")
	button.mouse_entered.emit()
	var samples := await _samples(0.45)
	var peak := _peak(samples)
	var span := _audible_span(samples)
	if DisplayServer.get_name() != "headless":
		_expect(span > 0.04 and span <= 0.25, "OPEN-047 actual hover is absent or longer than a brief <=250ms cue")
		_expect(peak > 0.0003 and peak <= db_to_linear(-24.0),
			"OPEN-047 actual full-volume hover peak is absent or harsh: %.2f dBFS" % linear_to_db(maxf(peak, 0.000001)))
		_save_wave(samples, "/tmp/menu-hover-full.wav")
	print("MENU HOVER MEASURE|audible_span=%.3f|peak_db=%.2f|samples=%d" % [span, linear_to_db(maxf(peak, 0.000001)), samples.size()])
	if OS.get_cmdline_user_args().has("--interaction"):
		# Paused title is the real production setting; wall-clock cooldown
		# must still expire. Bounded burst guards against every re-entry restart.
		paused = true
		audio.clear_sfx_event_trace()
		button.mouse_entered.emit()
		for _i in range(31):
			button.mouse_entered.emit()
		_expect(audio.get_sfx_event_trace() == ["ui_hover"], "OPEN-048 rapid pointer burst repeatedly restarts hover")
		await create_timer(0.32, true).timeout
		button.mouse_entered.emit()
		_expect(audio.get_sfx_event_trace() == ["ui_hover", "ui_hover"], "OPEN-048 later hover is permanently suppressed while paused")
		await create_timer(0.32, true).timeout
		audio.clear_sfx_event_trace()
		audio.play_ui_click()
		button.mouse_entered.emit()
		_expect(audio.get_sfx_event_trace() == ["ui_click"], "OPEN-048 hover immediately cuts off click acknowledgement")
		await create_timer(0.32, true).timeout
		audio.clear_sfx_event_trace()
		audio.play_ui_start_game()
		button.mouse_entered.emit()
		_expect(audio.get_sfx_event_trace() == ["ui_start_game"], "OPEN-048 hover cuts off run-start acknowledgement")
		paused = false
	if OS.get_cmdline_user_args().has("--preferences"):
		# Exercise actual bus output, not just the stored slider numbers.
		for case in [[0.5, false], [1.0, true], [0.0, false]]:
			audio.release_streams_for_shutdown()
			audio.set_sfx_volume(case[0])
			audio.set_sfx_muted(case[1])
			await create_timer(0.32, true).timeout
			button.mouse_entered.emit()
			var measured := _peak(await _samples(0.4))
			if DisplayServer.get_name() != "headless":
				if case[0] == 0.5:
					_expect(absf(measured / peak - 0.5) < 0.06, "OPEN-049 half SFX volume does not halve actual output")
				else:
					_expect(measured < 0.00001, "OPEN-049 muted/zero SFX leaks audible hover")
			print("MENU HOVER PREFERENCE|volume=%s|muted=%s|peak=%.6f" % [case[0], case[1], measured])
		_expect(audio.get_audio_settings().music_volume == old_settings.music_volume,
			"OPEN-049 menu trim changes persistent Music volume")
	await _finish()

func _samples(seconds: float) -> PackedVector2Array:
	capture.clear_buffer()
	await create_timer(seconds, true).timeout
	return capture.get_buffer(capture.get_frames_available())

func _peak(samples: PackedVector2Array) -> float:
	var result := 0.0
	for frame in samples:
		result = maxf(result, maxf(absf(frame.x), absf(frame.y)))
	return result

func _audible_span(samples: PackedVector2Array) -> float:
	var first := -1
	var last := -1
	for i in range(samples.size()):
		if maxf(absf(samples[i].x), absf(samples[i].y)) > 0.0001:
			if first < 0:
				first = i
			last = i
	return float(last - first) / AudioServer.get_mix_rate() if first >= 0 else 0.0

func _save_wave(samples: PackedVector2Array, path: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 4)
	for i in range(samples.size()):
		bytes.encode_s16(i * 4, int(clampf(samples[i].x, -1.0, 1.0) * 32767))
		bytes.encode_s16(i * 4 + 2, int(clampf(samples[i].y, -1.0, 1.0) * 32767))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.stereo = true
	wave.mix_rate = int(AudioServer.get_mix_rate())
	wave.data = bytes
	wave.save_to_wav(path)

func _button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text:
			return child as Button
		var nested := _button(child, text)
		if nested != null:
			return nested
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	audio.release_streams_for_shutdown()
	AudioServer.remove_bus_effect(sfx_bus, AudioServer.get_bus_effect_count(sfx_bus) - 1)
	audio.set_sfx_volume(old_settings.sfx_volume)
	audio.set_sfx_muted(old_settings.sfx_muted)
	title.queue_free()
	await process_frame
	for finding in findings:
		print("FINDING  " + finding)
	print("MENU AUDIO COMFORT: clean" if findings.is_empty() else "MENU AUDIO COMFORT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
