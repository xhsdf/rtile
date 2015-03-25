#!/usr/bin/ruby


# requires: xprop, wmctrl, xrandr

NAME = "xh_tile"
VERSION = "1.65"

if ARGV.include? '--version'
	puts "#{NAME} v#{VERSION}"
	exit
end


def main()
	settings = Settings.new
	settings.set_medians({0 => 0.583, 3 => 0.583, 4 => 0.417})
	settings.set_reverse_x([4]) #ids of workspaces where windows should be places from right to left
	settings.set_reverse_y([]) #ids of workspaces where windows should be places from bottom to top
	settings.set_gaps({:top => 42, :bottom => 22, :left => 22, :right => 22, :windows_x => 22, :windows_y => 22})
	settings.set_floating(["mpv"])
	# priority lower than nil => window gets placed after windows not in the list and fake windows (see set_size())
	settings.set_window_priority(["firefox", "geany", nil, "transmission", "terminator", "terminal", "hexchat"])
	# pretends there are at least this many windows on the same desktop of the application
	settings.set_size({"terminator" => 3, "transmission" => 3, "hexchat" => 3, "geany" => 2, "nvidia-settings" => 2, "nemo" => 3})

	monitors = Monitor.get_monitors()
	windows = Window.get_windows()
	
	
	#~ windows.each do |w|
		#~ puts "#{w.title}"
		#~ puts "\tid: #{w.id}"
		#~ puts "\tclass: #{w.class_name}"
		#~ puts "\tpid: #{w.pid}"
		#~ puts "\thidden: #{w.hidden}"
		#~ puts "\tworkspace: #{w.workspace}"
		#~ puts "\tdimensions:#{w.x},#{w.y} #{w.width}x#{w.height}"
		#~ puts "\tdecorations: #{w.decorations[:top]} #{w.decorations[:bottom]} #{w.decorations[:left]} #{w.decorations[:right]} "
	#~ end
	#~ return
	
	current_workspace = Monitor.get_current_workspace()	
	median = settings.medians[current_workspace]

	if ARGV.include? "--all"
		tile_all(settings, windows, monitors, median, current_workspace)
	elsif not (split = ARGV.grep(/--split-(up|down|left|right)/)).empty?
		split_active(settings, windows, split.first.gsub(/^--split-/, ''))
	elsif not (grow = ARGV.grep(/--grow-(up|down|left|right)/)).empty?
		grow_active(settings, windows, grow.first.gsub(/^--grow-/, ''))
	else
		tile_active(settings, windows, monitors, median, ARGV.select do |arg| arg =~ /^(l|r|t|b)+$/ end)
	end
end


def tile_active(settings, windows, monitors, median, args)
	w = get_active_window(windows)
	cols, rows, x, y = 1, 1, 0, 0
	args.each do |arg|
		arg.each_char do |c|
			cols = 2 if c == 'l' or c == 'r'
			x = cols - 1 if c == 'r'
		
			rows = 2 if c == 't' or c == 'b'
			y = rows - 1 if c == 'b'			
		end
	end
	columns = []
	(0...cols).each do |c|
		columns << []
		(0...rows).each do |r|
			columns[c][r] = nil
		end
	end
	columns[x][y] = w
	
	tile(settings, columns, get_monitor(w, monitors), median)
end


def grow_active(settings, windows, direction)
	window = get_active_window(windows)
	other_windows = windows.select do |w| window.id != w.id and w.workspace == window.workspace and not w.hidden end
	grow(settings, window, direction, other_windows)
end


def grow(settings, window, direction, other_windows)
	if direction == 'up' or direction == 'down'
		target_windows = other_windows.select do |w| (direction == 'up' ? (w.y + w.height < window.y) : (w.y > window.y + window.height)) and lies_between(window.x, window.x_end, w.x, w.x_end) end
		if direction == 'up'
			target_windows.sort_by! do |w| w.y + w.height end.reverse!
		else
			target_windows.sort_by! do |w| w.y end
		end
		if target_windows.empty?
			m = get_monitor(window, Monitor.get_monitors())
		else
			target = target_windows.first
		end
		
		if direction == 'up'
			y = target.nil? ? (m.y + settings.gaps[:top]) : (target.y_end + settings.gaps[:windows_y])
			height = window.height + (window.y - y)
			window.resize(window.x, y, window.width, height)
		else
			height = target.nil? ? (m.y_end - window.y - settings.gaps[:bottom]) : (target.y - window.y - settings.gaps[:windows_y])
			window.resize(window.x, window.y, window.width, height)
		end
	elsif direction == 'left' or direction == 'right'
		target_windows = other_windows.select do |w| (direction == 'left' ? (w.x + w.width < window.x) : (w.x > window.x + window.width)) and lies_between(window.y, window.y_end, w.y, w.y_end) end
		if direction == 'left'
			target_windows.sort_by! do |w| w.x + w.width end.reverse!
		else
			target_windows.sort_by! do |w| w.x end
		end
		if target_windows.empty?
			m = get_monitor(window, Monitor.get_monitors())
		else
			target = target_windows.first
		end
		
		if direction == 'left'
			x = target.nil? ? (m.x + settings.gaps[:left]) : (target.x_end + settings.gaps[:windows_x])
			width = window.width + (window.x - x)
			window.resize(x, window.y, width, window.height)
		else
			width = target.nil? ? (m.x_end - window.x - settings.gaps[:right]) : (target.x - window.x - settings.gaps[:windows_x])
			window.resize(window.x, window.y, width, window.height)
		end
	end
end


def lies_between(w_start, w_end, target_start, target_end)
	if w_start >= target_start and w_start <= target_end
		return true
	end
	
	if w_end >= target_start and w_end <= target_end
		return true
	end	
	
	if w_start <= target_start and w_end >= target_end
		return true
	end
	
	return false
end


def split_active(settings, windows, direction)
	window = get_active_window(windows)
	same_pos_windows = windows.select do |w| have_same_pos(window, w) and not window.id == w.id and w.workspace == window.workspace and not w.hidden end
	split(settings, window, direction, same_pos_windows)
end


def have_same_pos(w1, w2)
	return (w1.height == w2.height and w1.width == w2.width and w1.x == w2.x and w1.y == w2.y)
end


def split(settings, window, direction, same_pos_windows = [nil])
	same_pos_windows = [nil] if same_pos_windows.empty?
	splits = [same_pos_windows.size + 1, 2].max
	split_height = (window.height / splits) - ((splits - 1) * (settings.gaps[:windows_x] / splits))
	split_width = (window.width / splits) - ((splits - 1) * (settings.gaps[:windows_y] / splits))
	
	if direction == 'left' or direction == 'up'
		same_pos_windows.unshift(window)
	else
		same_pos_windows << window
	end
	if direction == 'left' or direction == 'right'
		same_pos_windows.each_with_index do |w, i|
			x = window.x + (i * (split_width + settings.gaps[:windows_x]))
			if i == same_pos_windows.size - 1
				split_width = (window.x + window.width) - x
			end
			w.resize(x, window.y, split_width, window.height) unless w.nil?
		end
	elsif direction == 'up' or direction == 'down'
		same_pos_windows.each_with_index do |w, i|
			y = window.y + (i * (split_height + settings.gaps[:windows_y]))
			if i == same_pos_windows.size - 1
				split_width = (window.y + window.height) - y
			end
			w.resize(window.x, y, window.width, split_height) unless w.nil?
		end
	end
end


def tile_all(settings, windows, monitors, median, current_workspace)
	monitor_hash = {}
	monitors.each do |m|
		monitor_hash[m.name] = []
	end
	windows.each do |w|
		monitor = get_monitor(w, monitors)
		monitor_hash[monitor.name] << w
	end

	monitors.each do |monitor|
		monitor_windows = monitor_hash[monitor.name].select do |w| w.workspace == current_workspace and not w.hidden and (settings.floating.select do |i| w.class_name.downcase.include? i.downcase end).empty? end
		sizes = [1]
		monitor_windows.each do |w|
			settings.size.keys.each do |p|
				sizes << settings.size[p] if w.class_name.downcase.include? p
			end
		end		
		[sizes.max - monitor_windows.length, 0].max.times do
			monitor_windows << nil
		end
		reverse_x = settings.reverse_x.include? current_workspace
		reverse_y = settings.reverse_y.include? current_workspace
		
		monitor_windows.sort_by! do |w| get_window_priority(settings, w, reverse_x, reverse_y) end
		
		
		max_vert_windows = 3
		remaining_windows = monitor_windows.clone
		columns = [[]]
		
		main_col_rows_size = monitor_windows.size > max_vert_windows + 1 ? 2 : 1
		main_col_rows_size.times do
			columns[0] << remaining_windows.shift
		end
		columns << remaining_windows[0...[max_vert_windows, remaining_windows.size].min] unless remaining_windows.empty?
		columns.last.reverse! if reverse_y
		columns.reverse! if reverse_x
		
		tile(settings, columns, monitor, median)
	end
end


def tile(settings, columns, monitor, median)
	x_window_geometries = get_window_geometries(monitor.x, monitor.width, columns.size, median, settings.gaps[:left], settings.gaps[:right], settings.gaps[:windows_x])
	columns.each_with_index do |column, x|
		y_window_geometries = get_window_geometries(monitor.y, monitor.height, column.size, nil, settings.gaps[:top], settings.gaps[:bottom], settings.gaps[:windows_y])
		column.each_with_index do |w, y|
			w.resize(x_window_geometries[x][0], y_window_geometries[y][0], x_window_geometries[x][1], y_window_geometries[y][1]) if w != nil
		end
	end	
end


def get_window_priority(settings, w, reverse_x, reverse_y)
	criteria = Array.new
	
	prio = settings.window_priority.index(nil)
	if w == nil
		criteria = [prio, 1]
	else
		settings.window_priority.reverse.each do |p|	
			prio = settings.window_priority.index(p) if (p != nil and w.class_name.downcase.include? p.downcase)
		end
		criteria << prio
		criteria << 0
		criteria << (reverse_x ? -((w.x + w.width) / 100) : (w.x / 100))
		criteria << (reverse_y ? -((w.y + w.height) / 100) : (w.y / 100))
		criteria << (-((w.width / 10) * (w.height / 10)))
	end

	return criteria
end


def get_active_window(windows)
	active_id = Window.get_active_window_id()
	windows.select do |w| w.id.hex == active_id.hex end.first
end


def get_window_geometries(margin, screen_length, window_count, median = nil, first_gap, last_gap, window_gap)
	current_length = remaining_length = screen_length - ((window_count - 1) * window_gap) - first_gap - last_gap

	lengths = Array.new
	for i in 0...window_count
		if i == 0 and median != nil and window_count > 1
			current_length = (remaining_length * median.abs).to_i
		else
			current_length = (remaining_length / (window_count - i)).to_i
		end
		lengths[i] = current_length
		remaining_length -= current_length
	end
	
	lengths.reverse! if median != nil and median < 0	
	
	coords = Array.new
	coords[0] = margin + first_gap
	for i in 1...lengths.length
		coords[i] = coords[i-1] + window_gap + lengths[i-1]
	end
	
	window_geometries = []
	for i in 0..coords.length do
		window_geometries << [coords[i], lengths[i]]	
	end
	
	return window_geometries
end


def get_monitor(window, monitors)
	monitors_x = monitors.select do |m| window.x >= m.x and window.x <= m.x + m.width end
	monitors_y = monitors.select do |m| window.y >= m.y and window.y <= m.y + m.height end
	
	return (monitors_x & monitors_y).first unless (monitors_x & monitors_y).empty?
	return monitors_x.first unless monitors_x.empty?
	return monitors_y.first unless monitors_y.empty?
	return monitors.first
end


class Settings
	attr_reader :medians, :reverse_x, :reverse_y, :gaps, :floating, :window_priority, :size

	def initialize()
		@medians = {}
		@reverse_x = []
		@reverse_y = []
		@gaps = {:top => 0, :bottom => 0, :left => 0, :right => 0, :windows_x => 0, :windows_y => 0}
		@floating = []
		@window_priority = []
		@size = []
	end

	
	def set_medians(medians)
		@medians = medians
	end


	def set_reverse_x(reverse_x)
		@reverse_x = reverse_x
	end


	def set_reverse_y(reverse_y)
		@reverse_y = reverse_y
	end


	def set_gaps(gaps)
		@gaps = gaps
	end


	def set_floating(floating)
		@floating = floating
	end


	def set_window_priority(window_priority)
		@window_priority = window_priority
	end


	def set_size(size)
		@size = size
	end	
end


class Window # requires: wmcrtl, xprop
	attr_reader :id, :title, :class_name, :workspace, :x, :y, :width, :height, :pid, :hidden, :decorations, :ignore

	def initialize(id)
		#~ @id, @workspace, @pid, @x, @y, @width, @height, @class, @host, @title = id, workspace.to_i, pid, x.to_i, y.to_i, width.to_i, height.to_i, wm_class, host, title
		#~ @decorations = nil
		@id = id
		@decorations = Hash.new
		@ignore = false
		xprop = `xprop -id #{@id}`.to_s
		
		xprop.each_line do |line|
			if line.include? 'WM_CLASS'
				@class_name = line.split('=').last.strip.split(', ').last.gsub(/^"/, '').gsub(/"$/, '')
			elsif line.include? 'WM_NAME'
				@title = line.split('=').last.strip.gsub(/^"/, '').gsub(/"$/, '')
			elsif line.include? '_NET_WM_STATE'
				@hidden = line.split('=').last.include?('_NET_WM_STATE_HIDDEN')
			elsif line.include? 'WM_DESKTOP'
				@workspace = line.split('=').last.strip.to_i
			elsif line.include? 'NET_WM_PID'
				@pid = line.split('=').last.strip.to_i
			elsif line.include? '_NET_FRAME_EXTENTS'
				@decorations[:left], decorations[:right], decorations[:top], decorations[:bottom] = line.split('=').last.strip.split(",").collect do |i| i.strip.to_i end
			end
		end
		if @decorations.empty?
			@ignore = true
		else
			get_accurate_dimensions()
		end
	end
	
	
	def self.get_windows()
		windows = []
		get_window_ids().each do |id|
			windows << Window.new(id)
		end
		windows.reject do |w| w.ignore end
		return windows
	end
	
	
	def self.get_window_ids()
		window_ids = []
		`xprop -root _NET_CLIENT_LIST`.to_s.each_line do |line|
			id_string = line.gsub(/_NET_CLIENT_LIST\(WINDOW\): *window id # +/, "")
			id_string.split(', ').each do |id|
				window_ids << id.strip
			end
		end
		return window_ids.uniq
	end
	
	
	def x_end()
		return @x + @width
	end
	
	
	def y_end()
		return @y + @height
	end


	def self.get_active_window_id()
		return `xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2`.strip
	end
	
	def resize(x, y, width, height)
		width -= (@decorations[:left] + @decorations[:right])
		height -= (@decorations[:top] + @decorations[:bottom])
	
	
		window_string = "-i -r #{@id}"
		command = "wmctrl #{window_string} -e 0,#{x},#{y},#{width},#{height}"

		`wmctrl #{window_string} -b remove,maximized_vert,maximized_horz`
		#~ `wmctrl #{window_string} -b remove,fullscreen`
		#~ puts command
		`#{command}`
	end


	def get_accurate_dimensions()
		win_info = `xwininfo -id #{@id}`
			
		win_info.each_line do |line|
			if line.include? 'Width:'
				@width = line.match(/Width: *(.+)/i).captures.first.strip.to_i
			elsif line.include? 'Height:'
				@height = line.match(/Height: *(.+)/i).captures.first.strip.to_i
			elsif line.include? 'Absolute upper-left X:'
				@x = line.match(/Absolute upper-left X: *(.+)/i).captures.first.strip.to_i
			elsif line.include? 'Absolute upper-left Y:'
				@y = line.match(/Absolute upper-left Y: *(.+)/i).captures.first.strip.to_i
			end
		end
		
		@x -= @decorations[:left]
		@y -= @decorations[:top]
		@width += @decorations[:right] + @decorations[:left]
		@height += @decorations[:bottom] + @decorations[:top]
	end
end


class Monitor # requires: xrandr
	attr_reader :width, :height, :x, :y, :id, :windows, :name


	def initialize(name, width, height, x, y, id)
		@name, @width, @height, @x, @y, @id = name, width, height, x, y, id
	end
	
	
	def x_end()
		return @x + @width
	end
	
	
	def y_end()
		return @y + @height
	end


	def self.get_current_workspace()
		return `xprop -root | grep _NET_CURRENT_DESKTOP\\(CARDINAL\\)`.to_s[/(?<== )\d+/].to_i
	end


	def self.get_monitors()
		xrandr_output = `xrandr --query`

		monitors = []
		id = 0
		xrandr_output.each_line do |line|
			if line =~ /connected.*(\d+)x(\d+)\+(\d+)\+(\d+)/
				width, height, x, y = line.match(/(\d+)x(\d+)\+(\d+)\+(\d+)/i).captures.collect do |c| c.to_i end
				name = line.match(/(.+) connected/i).captures.first
				monitors << Monitor.new(name, width, height, x, y, id)
				id += 1
			end
		end
		return monitors
	end
end


main()