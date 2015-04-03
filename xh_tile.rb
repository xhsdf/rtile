#!/usr/bin/ruby


# requires: xprop, wmctrl, xwininfo, xrandr

NAME = "xh_tile"
VERSION = "1.68a"

if ARGV.include? '--version'
	puts "#{NAME} v#{VERSION}"
	exit
end


def main()
	settings = Settings.new
	settings.set_medians({0 => 0.583, 3 => 0.583, 4 => 0.417})
	settings.set_reverse_x(4) #ids of workspaces where windows should be places from right to left
	settings.set_reverse_y() #ids of workspaces where windows should be places from bottom to top
	settings.set_gaps({:top => 42, :bottom => 22, :left => 22, :right => 22, :windows_x => 22, :windows_y => 22})
	settings.set_floating("mpv")
	# high priority windows get placed first
	settings.set_high_priority_windows("firefox", "geany")
	# low priority windows get placed last. even after fake windows
	settings.set_low_priority_windows("transmission-gtk", "terminator", "terminal", "hexchat")
	# pretends there are at least this many windows on the same monitor as the application
	settings.set_fake_windows({"terminator" => 3, "transmission-gtk" => 3, "hexchat" => 3, "geany" => 2, "nvidia-settings" => 2, "nemo" => 3})

	monitors = Monitor.get_monitors()	
	current_workspace = Monitor.get_current_workspace()	
	median = settings.medians[current_workspace]

	if ARGV.include? "--all"
		tile_all(settings, Window.get_windows(), monitors, median, current_workspace)
	elsif not (split = ARGV.grep(/--split-(up|down|left|right)/)).empty?
		split_active(settings, Window.get_windows(), split.first.gsub(/^--split-/, ''))
	elsif not (grow = ARGV.grep(/--grow-(up|down|left|right)/)).empty?
		grow_active(settings, Window.get_windows(), grow.first.gsub(/^--grow-/, ''))
	else
		tile_active(settings, monitors, median, ARGV.select do |arg| arg =~ /^(l|r|t|b)+$/ end)
	end
end


def tile_active(settings, monitors, median, args)
	window = get_active_window()
	return if window.nil?
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
	columns[x][y] = window
	
	tile(settings, columns, get_monitor(window, monitors), median)
end


def grow_active(settings, windows, direction)
	window = get_active_window(windows)
	return if window.nil?
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
	return if window.nil?
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
		fake_windows = [1]
		monitor_windows.each do |w|
			settings.fake_windows.keys.each do |p|
				fake_windows << settings.fake_windows[p] if w.class_name.downcase.include? p
			end
		end		
		[fake_windows.max - monitor_windows.length, 0].max.times do
			monitor_windows << nil
		end
		reverse_x = settings.reverse_x.include? current_workspace
		reverse_y = settings.reverse_y.include? current_workspace
		
		monitor_windows.sort_by! do |w| get_window_priority(settings.high_priority_windows, settings.low_priority_windows, w, reverse_x, reverse_y) end

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


def get_window_priority(high_priority_windows, low_priority_windows, w, reverse_x, reverse_y)
	criteria = Array.new
	
	prio = high_priority_windows.size
	if w == nil
		criteria = [prio, 1]
	else
		class_name = w.class_name.downcase
		if high_priority_windows.include?(class_name)
			prio = high_priority_windows.index(class_name)
		elsif low_priority_windows.include?(class_name)
			prio = high_priority_windows.size + 1 + low_priority_windows.index(class_name)
		end
		criteria << prio
		criteria << 0
		criteria << (reverse_x ? -((w.x + w.width) / 100) : (w.x / 100))
		criteria << (reverse_y ? -((w.y + w.height) / 100) : (w.y / 100))
		criteria << (-((w.width / 10) * (w.height / 10)))
	end

	return criteria
end


def get_active_window(windows = nil)
	active_id = Window.get_active_window_id()
	if active_id == '0x0'
		return nil
	else
		if windows.nil?
			return Window.new(active_id)
		else
			return windows.select do |w| w.id.hex == active_id.hex end.first
		end
	end
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
	attr_reader :medians, :reverse_x, :reverse_y, :gaps, :floating, :high_priority_windows, :low_priority_windows, :fake_windows

	def initialize()
		@medians = {}
		@reverse_x = []
		@reverse_y = []
		@gaps = {:top => 0, :bottom => 0, :left => 0, :right => 0, :windows_x => 0, :windows_y => 0}
		@floating = []
		@high_priority_windows = []
		@low_priority_windows = []
		@fake_windows = []
	end

	
	def set_medians(medians)
		@medians = medians
	end


	def set_reverse_x(*reverse_x)
		@reverse_x = reverse_x
	end


	def set_reverse_y(*reverse_y)
		@reverse_y = reverse_y
	end


	def set_gaps(gaps)
		@gaps = gaps
	end


	def set_floating(*floating)
		@floating = floating
	end


	def set_high_priority_windows(*high_priority_windows)
		@high_priority_windows = high_priority_windows
	end


	def set_low_priority_windows(*low_priority_windows)
		@low_priority_windows = low_priority_windows
	end


	def set_fake_windows(fake_windows)
		@fake_windows = fake_windows
	end
end


class Window # requires: wmcrtl, xprop, xwininfo
	attr_reader :id, :title, :class_name, :workspace, :x, :y, :width, :height, :pid, :hidden, :decorations, :ignore

	def initialize(id)
		@id = id
		@decorations = Hash.new
		@ignore = false
		xprop = `xprop -id #{@id} WM_CLASS WM_NAME _NET_WM_STATE _NET_WM_DESKTOP _NET_WM_WINDOW_TYPE _NET_WM_PID _NET_FRAME_EXTENTS`.to_s
		
		xprop.each_line do |line|
			if line.include? 'WM_CLASS'
				@class_name = line.split('=').last.strip.split(', ').last.strip.tr('"', '')
			elsif line.include? 'WM_NAME'
				@title = line.split('=').last.strip.tr('"', '')
			elsif line.include? '_NET_WM_WINDOW_TYPE'
				type = line.split('=').last.strip
				#["_NET_WM_WINDOW_TYPE_DOCK", "_NET_WM_WINDOW_TYPE_TOOLBAR", "_NET_WM_WINDOW_TYPE_MENU", "_NET_WM_WINDOW_TYPE_UTILITY", "_NET_WM_WINDOW_TYPE_DIALOG"]
				@ignore = !(type == '_NET_WM_WINDOW_TYPE_NORMAL' or type.include?('not found'))
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
		unless @ignore
			get_dimensions()
		end
	end
	
	
	def self.get_windows()
		windows = []
		get_window_ids().each do |id|
			windows << Window.new(id)
		end
		windows.reject! do |w| w.ignore end
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


	def get_dimensions()
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