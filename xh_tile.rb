#!/usr/bin/ruby


# xprop, wmctrl, xrandr

NAME = "xh_tile"
VERSION = "1.50"

if ARGV.include? '--version'
	puts "#{NAME} v#{VERSION}"
	exit
end

$medians = {0 => 0.583, 3=> 0.583, 4 => 0.417}
$vertical_medians = {0 => -0.325}
$reverse_x = [4] #ids of workspaces where windows should be places from right to left
$reverse_y = [] #ids of workspaces where windows should be places from bottom to top
$gaps = {:top => 42, :bottom => 22, :left => 22, :right => 22, :windows_x => 22, :windows_y => 22}
$floating = ["mpv"]

# priority lower than nil => window gets placed after windows not in the list
$window_priority = ["firefox", "geany", nil, "transmission", "terminator", "terminal", "hexchat"]

# pretends there are at least this many windows on the same desktop of the application
$size = {"terminator" => 3, "transmission" => 3, "hexchat" => 3, "geany" => 2, "nvidia-settings" => 2, "nemo" => 3}

def main()
	monitors = Monitor.get_monitors()
	windows = Window.get_windows()
	
	current_workspace = get_current_workspace()	
	median = $medians[current_workspace]
	vertical_median = $vertical_medians[current_workspace]

	if ARGV.include? "--all"
		tile_all(windows, monitors, median, vertical_median, current_workspace)
	elsif not (split = ARGV.grep(/--split-(up|down|left|right)/)).empty?
		split_active(windows, split.first.gsub(/^--split-/, ''))
	else
		tile_active(windows, monitors, median, vertical_median, ARGV.select do |arg| arg =~ /^(l|r|t|b)+$/ end)
	end
end


def tile_active(windows, monitors, median, vertical_median, args)
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
	
	tile(columns, get_monitor(w, monitors), median, vertical_median)
end


def split_active(windows, direction)
	window = get_active_window(windows)
	same_pos_windows = windows.select do |w| have_same_pos(window, w) and not window.id == w.id and w.workspace == window.workspace and not w.is_hidden? end
	split(window, direction, same_pos_windows)
end


def have_same_pos(w1, w2)
	return (w1.height == w2.height and w1.width == w2.width and w1.x == w2.x and w1.y == w2.y)
end


def split(window, direction, same_pos_windows = [nil])
	same_pos_windows = [nil] if same_pos_windows.empty?
	splits = [same_pos_windows.size + 1, 2].max
	decorations = window.get_decorations()	
	window = Window.new(window.id, window.workspace, window.pid, window.x - decorations[:left] - decorations[:right], window.y - decorations[:top] - decorations[:bottom], window.width + decorations[:left] + decorations[:right], window.height  + decorations[:top] + decorations[:bottom], window.class, window.host, window.title)
	split_height = (window.height / splits) - ((splits - 1) * ($gaps[:windows_x] / splits))
	split_width = (window.width / splits) - ((splits - 1) * ($gaps[:windows_y] / splits))
	
	if direction == 'left' or direction == 'up'
		same_pos_windows.unshift(window)
	else
		same_pos_windows << window
	end
	if direction == 'left' or direction == 'right'
		same_pos_windows.each_with_index do |w, i|
			x = window.x + (i * (split_width + $gaps[:windows_x]))
			if i == same_pos_windows.size - 1
				split_width = (window.x + window.width) - x
			end
			w.resize(x, window.y, split_width, window.height) unless w.nil?
		end
	elsif direction == 'up' or direction == 'down'
		same_pos_windows.each_with_index do |w, i|
			y = window.y + (i * (split_height + $gaps[:windows_y]))
			if i == same_pos_windows.size - 1
				split_width = (window.y + window.height) - y
			end
			w.resize(window.x, y, window.width, split_height) unless w.nil?
		end
	end
end


def tile_all(windows, monitors, median, vertical_median, current_workspace)
	monitor_hash = {}
	monitors.each do |m|
		monitor_hash[m.name] = []
	end
	windows.each do |w|
		monitor = get_monitor(w, monitors)
		monitor_hash[monitor.name] << w
	end	
	puts "monitors:"
	monitors.each do |m|
		puts "#{m.name} - #{m.width}x#{m.height} +#{m.x}+#{m.y}"
		monitor_hash[m.name].each do |w|
			puts "\t#{w.title}"
		end
	end

	monitors.each do |monitor|
		monitor_windows = monitor_hash[monitor.name].select do |w| w.workspace == current_workspace and not w.is_hidden? and ($floating.select do |i| w.class.downcase.include? i.downcase end.empty?) end
		sizes = [1]
		monitor_windows.each do |w|
			$size.keys.each do |p|
				sizes << $size[p] if w.class.downcase.include? p
			end
		end		
		[sizes.max - monitor_windows.length, 0].max.times do
			monitor_windows << nil
		end
		reverse_x = $reverse_x.include? current_workspace
		reverse_y = $reverse_y.include? current_workspace
		
		monitor_windows.sort_by! do |w| get_window_priority(w, reverse_x, reverse_y) end
		
		
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
		
		tile(columns, monitor, median, vertical_median)
	end
end


def tile(columns, monitor, median, vertical_median)
	x_window_geometries = get_window_geometries(monitor.x, monitor.width, columns.size, median, $gaps[:left], $gaps[:right], $gaps[:windows_x])
	columns.each_with_index do |column, x|
		y_window_geometries = get_window_geometries(monitor.y, monitor.height, column.size, vertical_median, $gaps[:top], $gaps[:bottom], $gaps[:windows_y])
		column.each_with_index do |w, y|
			w.resize(x_window_geometries[x][0], y_window_geometries[y][0], x_window_geometries[x][1], y_window_geometries[y][1]) if w != nil
		end
	end	
end


def get_window_priority(w, reverse_x, reverse_y)
	criteria = Array.new
	
	prio = $window_priority.index(nil)
	if w == nil
		criteria = [prio, 1]
	else
		$window_priority.reverse.each do |p|	
			prio = $window_priority.index(p) if (p != nil and w.class.downcase.include? p.downcase)
		end
		criteria << prio
		criteria << 0
		criteria << (reverse_x ? -((w.x + w.width) / 100) : (w.x / 100))
		criteria << (reverse_y ? -((w.y + w.height) / 100) : (w.y / 100))
		criteria << (-((w.width / 10) * (w.height / 10)))
	end

	return criteria
end


def get_current_workspace()
	return `xprop -root | grep _NET_CURRENT_DESKTOP\\(CARDINAL\\)`.to_s[/(?<== )\d+/].to_i
end


def get_active_window_id()
	return `xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2`.strip
end


def get_active_window(windows)
	active_id = get_active_window_id()
	windows.select do |w| w.id.hex == active_id.hex end.first
end


def get_window_geometries(margin, screen_length, window_count, median, first_gap, last_gap, window_gap)
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


class Window
	attr_reader :id, :title, :class, :workspace, :x, :y, :width, :height, :pid, :host
	
	def initialize(id, workspace, pid, x, y, width, height, wm_class, host, title)
		@id, @workspace, @pid, @x, @y, @width, @height, @class, @host, @title = id, workspace.to_i, pid, x.to_i, y.to_i, width.to_i, height.to_i, wm_class, host, title
	end
	
	def self.get_windows()
		windows = []
		`wmctrl -lpGx`.to_s.each_line do |line|
			id, workspace, pid, x, y, width, height, wm_class, host, *title = line.split(' ')
			windows << Window.new(id, workspace, pid, x, y, width, height, wm_class, host, title.join(' '))
		end
		return windows
	end
	
	def is_hidden?()
		return `xprop -id #{@id} _NET_WM_STATE`.to_s.include?('_NET_WM_STATE_HIDDEN')
	end
	
	def resize(x, y, width, height)
		decorations = get_decorations()
		width -= (decorations[:left] + decorations[:right])
		height -= (decorations[:top] + decorations[:bottom])
	
	
		window_string = "-i -r #{@id}"
		command = "wmctrl #{window_string} -e 0,#{x},#{y},#{width},#{height}"

		`wmctrl #{window_string} -b remove,maximized_vert,maximized_horz`
		#~ `wmctrl #{window_string} -b remove,fullscreen`
		
		puts command if $output	
		`#{command}`
	end
	
	def get_decorations()
		decorations = Hash.new
		decorations[:left], decorations[:right], decorations[:top], decorations[:bottom] = `xprop -id #{@id} _NET_FRAME_EXTENTS`.split("=")[1].split(",").collect do |i| i.strip.to_i end
		return decorations
	end
end


class Monitor
	attr_reader :width, :height, :x, :y, :id, :windows, :name
	
	def initialize(name, width, height, x, y, id)
		@name, @width, @height, @x, @y, @id = name, width, height, x, y, id
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