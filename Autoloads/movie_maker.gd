extends Node

enum State {
	_undef,
	RECORDING,
	PAUSED,
	STOPPED,
	CONVERTING,
}

var state:State = State._undef

var save_dir := "user://recording"
var viewport : Viewport
var output_name := "capture"
var framerate := 60
var make_gif := true


var frames:Array[Image]
var frame := 0
var recorded_time:float = 0
var threads:Array[Thread]
var frames_in_a_row = 0


func _ready():
	if not Flags.DEBUG: 
		queue_free()
		return
	
	viewport = get_viewport()
	DirAccess.make_dir_recursive_absolute(save_dir)
	#print("Recorder ready. Saving frames to:", save_dir)
	
	state = State.STOPPED


func start():
	if state != State.STOPPED:
		push_warning("Can't start recording before finishing the current one")
	initialize_recording()
	state = State.RECORDING
	print("🎥 Recording started...")
	
	
func pause():
	if state != State.RECORDING:
		push_warning("Can't pause if not recording")
	print("Pausing recording")
	state = State.PAUSED
	
	
func unpause():
	if state != State.PAUSED: 
		push_warning("Can't unpause if not paused")
	print("Continuing recording")
	state = State.RECORDING
	
	

func stop(discard:bool = false):
	if state not in [State.RECORDING, State.PAUSED]:
		push_warning("Can't stop if not recording")
	
	if discard:
		print("Recording CANCELED, clearing existing frames")
	else:
		print("Finalizing recording...")
		finalize_recording()
	clear_existing_frames()
	print("🛑 Recording stopped")
	
	state = State.STOPPED


func _physics_process(_delta):
	if not Flags.DEBUG: return
	
	match state:
		State.RECORDING:		
			recorded_time += _delta
						
			frames_in_a_row += 1
			
			if frames_in_a_row == GodotBase.settings.movie_maker_frame_skip_factor:
				frames_in_a_row = 0
								
				capture_frame(frame)	
				frame += 1
				
				
func capture_frame(frame_number:int)-> void:
	var img = viewport.get_texture().get_image()
	# Process and write to disk in a thread so we don't freeze the physics loop
	var write_th = Thread.new()
	threads.append(write_th)
	write_th.start(process_frame.bind(img, frame_number))
	
				
func process_frame(img:Image, frame_number:int)-> void:
	var frame_path = "%s/frame_%05d.png" % [save_dir, frame_number]
	
	var win_size := img.get_size()#viewport.get_visible_rect().size
	var target_w := GodotBase.settings.movie_maker_width
	var target_h := GodotBase.settings.movie_maker_height
	var zoom := GodotBase.settings.movie_maker_zoom  # Example: 0.5 captures more area (zoomed out), 2.0 captures less (zoomed in)

	# Calculate the size of the capture area before resizing
	var capture_w := target_w / zoom
	var capture_h := target_h / zoom

	# Center the capture area in the window
	var x := ((win_size.x - capture_w) / 2.0)
	var y := ((win_size.y - capture_h) / 2.0)

	# Crop the region, then resize it to the target output size
	img = img.get_region(Rect2(x, y, capture_w, capture_h))
	img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
	
	# Write to disk
	img.save_png(frame_path)
	

func clear_existing_frames():
	var dir := DirAccess.open(save_dir)
	if dir != null:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f.ends_with(".png") or f.ends_with(".webp") or f.ends_with(".gif") or f.ends_with(".mp4") or f == "palette.png":
				DirAccess.remove_absolute("%s/%s" % [save_dir, f])
			f = dir.get_next()
		dir.list_dir_end()
		print("🧹 Cleared old frame images from '%s'" % save_dir)


func initialize_recording()-> void:
	clear_existing_frames()
	frame = 0
	frames_in_a_row = 0
	recorded_time = 0
	frames= []
	threads = []
	

func finalize_recording() -> void:
	state = State.CONVERTING
	
	print("Waiting for frames to be saved...")
	while threads.any(func(th:Thread): return th.is_alive()): 
		await get_tree().process_frame
	for th in threads: th.wait_to_finish()
	print("Frames saved.")
	
	var spf = recorded_time/frame
	var fps:float = ceil(1.0/spf)
	print("Trying to generate a GIF of %ds at '%s' FPS" % [recorded_time, fps])
	
	
	var ffmpeg_path = "ffmpeg"

	# Convert all Godot paths to absolute filesystem paths
	var recording_dir = ProjectSettings.globalize_path("user://recording")
	var frames_pattern = recording_dir.path_join("frame_%05d.png")
	var mp4_path = recording_dir.path_join("capture.mp4")
	var palette_path = recording_dir.path_join("palette.png")
	var output_dir_path = recording_dir.path_join("output")
	DirAccess.make_dir_absolute(output_dir_path)

	## Step 1: make MP4
	var mp4_args := [
		"-y",
		"-framerate", str(fps),
		"-i", frames_pattern,
		"-c:v", "libx264",
		"-pix_fmt", "yuv420p",
		"-r", str(fps),
		mp4_path
	]
	print("🎞 Generating MP4...")
	var mp4_result := OS.execute("ffmpeg", mp4_args, [], true)
	#print(mp4_result.output)
	if mp4_result != 0:
		push_error("❌ MP4 generation failed.")
		return
	else:
		print("MP4 generated")
		
		
	var mb
	var dt_str = Time.get_datetime_string_from_system()
	dt_str = dt_str.replace(":", "_")
	
	# WebP CEATION
	if GodotBase.settings.movie_maker_make_webp:
		#ffmpeg -y -framerate 60 -i frame_%05d.png -vf "scale=616:-1:flags=lanczos,fps=60" -lossless 1 -loop 0 output.webp
		# ffmpeg -i input.mp4 -loop 0 -an -vsync 0 output.webp
		print("Generating WebP...")
		var temp_webp_path = recording_dir.path_join("capture.webp")
		var webp_cmd = [
			ffmpeg_path,
			"-i", mp4_path,
			"-y",
			"-loop", "0",
			"-an",
			"-vsync", "0",
			"-pix_fmt", "yuv444p",
			"-quality", "90",
			#"-lossless", "1",
			temp_webp_path
		]
		var webp_output = []
		var webp_exit = OS.execute(ffmpeg_path, webp_cmd.slice(1, webp_cmd.size()), webp_output, true)
		if webp_exit != 0:
			push_error("WebP creation failed. Output:\n" + "\n".join(webp_output))
			return
			
		mb = FileAccess.get_size(temp_webp_path)/1_000_000.0
		print("WebP generated. Resulting size: %s MB" % [mb])
					
		var webp_filename = "%s_recording.webp" % [dt_str]
		var webp_path = output_dir_path.path_join(webp_filename)
		print("Saving to '%s'" % webp_path)
		
		DirAccess.copy_absolute(temp_webp_path, webp_path)
		
	# --- GIF CREATION ---		
	# generate a palette from the mP4 to improve the results
	var palette_cmd = [
		ffmpeg_path,
		"-i", mp4_path,
		"-vf", "fps=%d,scale=%d:-1:flags=lanczos,palettegen" % [
			framerate,
			GodotBase.settings.movie_maker_width
			],
		"-update", "1",
		"-frames:v", "1",
		palette_path
	]
	var palette_output = []
	var palette_exit = OS.execute(ffmpeg_path, palette_cmd.slice(1, palette_cmd.size()), palette_output, true)
	if palette_exit != 0:
		push_error("Palette generation failed. Output:\n" + "\n".join(palette_output))
		return
	else:
		print("MP4 palette generated (colormap fpr the GIF)")
		
	# generate the GIF
	
	if GodotBase.settings.movie_maker_make_gif:
		var temp_gif_path = recording_dir.path_join("capture.gif")
		
		var gif_cmd = [
			ffmpeg_path,
			"-i", mp4_path,
			"-i", palette_path,
			"-filter_complex", "fps=%d,scale=%d:-1:flags=lanczos[x];[x][1:v]paletteuse" % [
				fps,
				GodotBase.settings.movie_maker_width, #HEIGHT,
				],
			"-y", temp_gif_path
		]
		var gif_output = []
		var gif_exit = OS.execute(ffmpeg_path, gif_cmd.slice(1, gif_cmd.size()), gif_output, true)
		if gif_exit != 0:
			push_error("GIF creation failed. Output:\n" + "\n".join(gif_output))
			return
			
		mb = FileAccess.get_size(temp_gif_path)/1_000_000.0
		print("GIF generated. Resulting size: %s MB" % [mb])
					
		if GodotBase.settings.movie_maker_optimize_gif:
			print("Optimizing GIF...")
			#magick input.gif -coalesce -fuzz 3% -layers OptimizeFrame -layers Optimize output_optimized_fuzz_3p.gif   
			
			var gif_opt_cmd = [
				temp_gif_path,
				"-coalesce",
				"-fuzz", "%d%%" % GodotBase.settings.movie_maker_gif_fuzz,
				"-layers", "Optimize",
				#"-layers", "OptimizeFrame",
				temp_gif_path
			]
			var gif_opt_output = []
			var gif_opt_exit = OS.execute("magick", gif_opt_cmd, gif_opt_output, true)
			if gif_opt_exit != 0:
				push_error("GIF optimization failed. Output:\n" + "\n".join(gif_opt_output))
				return
						
			mb = FileAccess.get_size(temp_gif_path)/1_000_000.0
			print("GIF optimized. Resulting size: %s MB" % [mb])
			
		# Store the output				
		var gif_filename = "%s_recording.gif" % [dt_str]
		var gif_path = output_dir_path.path_join(gif_filename)
		print("Saving to '%s'" % gif_path)
		
		DirAccess.copy_absolute(temp_gif_path, gif_path)
		


func _input(event: InputEvent) -> void:
	if not Flags.DEBUG: return
	
	if event.is_action_pressed("cancel_recording"):
		match state:
			State.RECORDING:
				stop(true)
			State.PAUSED:
				stop(true)
		return
	if event.is_action_pressed("toggle_recording"):
		match state:
			State.RECORDING:
				stop()
			State.STOPPED:
				start()
		return
	if event.is_action_pressed("toggle_recording_pause"):
		match state:
			State.RECORDING:
				pause()
			State.PAUSED:
				unpause()
		return
