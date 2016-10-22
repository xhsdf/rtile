#!/usr/bin/ruby


# requires: xprop, wmctrl, xwininfo, xrandr

require 'fileutils'
require 'rexml/document'
include REXML


NAME = "rtile"
VERSION = "1.92a"

GROW_PUSHBACK = 32

if ARGV.include? '--version'
	puts "#{NAME} v#{VERSION}"
	exit
end


def main()
	settings = Settings.new("#{ENV['HOME']}/.config/rtile/rtile.xml")

	if ARGV.include? "--all"
		tile_all(settings, Window.get_visible_windows(), Monitor.get_monitors(), Monitor.get_current_workspace())
	elsif ARGV.include? "--all-binary"
		tile_all_binary(settings, Window.get_visible_windows(), Monitor.get_monitors(), Monitor.get_current_workspace())
	elsif ARGV.include? "--all-auto"
		auto_tile_all(settings)
	elsif ARGV.include? "--all-auto-binary"
		auto_tile_all(settings, true)
	elsif ARGV.include? "--binary"
		binary(settings, Window.get_visible_windows(), Monitor.get_monitors(), Monitor.get_current_workspace())
	elsif ARGV.include? "--swap"
		swap(settings, Window.get_visible_windows(), Monitor.get_current_workspace())
	elsif ARGV.include? "--swap-biggest"
		swap_biggest(settings, Window.get_visible_windows(), Monitor.get_current_workspace())
	elsif ARGV.include? "--cycle"
		cycle(settings, Window.get_visible_windows(), Monitor.get_monitors(), Monitor.get_current_workspace())
	elsif ARGV.include? "--next-monitor"
		next_monitor_active(settings, Window.get_visible_windows(), Monitor.get_monitors())
	elsif ARGV.include? "--cycle-monitors"
		cycle_monitors(settings, Window.get_visible_windows(), Monitor.get_monitors())
	elsif not (split = ARGV.grep(/--split-(up|down|left|right)/)).empty?
		split_active(settings, Window.get_visible_windows(), split.first.gsub(/^--split-/, ''))
	elsif not (grow = ARGV.grep(/--grow-(up|down|left|right)/)).empty?
		grow_active(settings, Window.get_visible_windows(), grow.first.gsub(/^--grow-/, ''))
	else
		tile_active(settings, Monitor.get_monitors(), Monitor.get_current_workspace(), ARGV.select do |arg| arg =~ /^(l|r|t|b)+$/ end)
	end
end


def tile_active(settings, monitors, current_workspace, args)
	median = settings.medians[current_workspace]
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


def binary(settings, windows, monitors, current_workspace)
	windows = windows.reverse[0...2]
	monitor = get_monitor(windows.last, monitors)
	horizontal = (windows.last.width.to_f / windows.last.height.to_f) < (monitor.width.to_f / monitor.height.to_f)
	split(settings, windows.last, horizontal ? 'up' : 'left', [windows.first])
end


def cycle(settings, windows, monitors, current_workspace)
	monitor = get_monitor(get_active_window(windows), monitors)
	windows.select! do |w| monitor == get_monitor(w, monitors) end
	
	window_dimensions = windows.rotate.collect do |w| w.get_dimensions() end

	windows.size.times do |i|
		windows[i].resize(*window_dimensions[i])
	end
end


def swap(settings, windows, current_workspace)
	windows = windows.reverse[0...2]
	swap_windows(windows.first, windows.last)
end


def swap_biggest(settings, windows, current_workspace)
	active_window = windows.last
	biggest_window = (windows.sort_by do |w| w.height * w.width end).reverse.first
	swap_windows(active_window, biggest_window)
end


def swap_windows(window1, window2)
	window1_dimensions = window1.get_dimensions()
	window1.resize(*window2.get_dimensions())
	window2.resize(*window1_dimensions)
end


def grow_active(settings, windows, direction)
	window = get_active_window(windows)
	return if window.nil?
	other_windows = windows.select do |w| window.id != w.id end
	grow(settings, window, direction, other_windows)
end


def cycle_monitors(settings, windows, monitors)
	windows.each do |w|
		move_to_next_monitor(w, monitors)
	end
end


def next_monitor_active(settings, windows, monitors)
	window = get_active_window(windows)
	return if window.nil?
	move_to_next_monitor(window, monitors)
end


def move_to_next_monitor(window, monitors)
	monitors = monitors.uniq do |m| [m.x, m.y] end
	monitor = get_monitor(window, monitors)	
	next_monitor = monitors[(monitors.index(monitor) + 1) % monitors.size]
	
	move_to_monitor(window, monitor, next_monitor)
end


def move_to_monitor(window, current_monitor, target_monitor)
	x = window.x - current_monitor.x + target_monitor.x
	y = window.y - current_monitor.y + target_monitor.y
	
	window.resize(x, y, window.width, window.height)
end


def grow(settings, window, direction, other_windows)
	monitors = Monitor.get_monitors()
	monitor = get_monitor(window, monitors)
	target_windows = other_windows.select do |w| lies_in_path(window, w, direction) and get_monitor(w, monitors) == monitor end
	up, down, left, right = 0, 0, 0, 0

	if target_windows.empty?
		case direction
			when 'up'
				up = window.y - monitor.y - settings.gaps[:top]
			when 'down'
				down = monitor.y_end - settings.gaps[:bottom] - window.y_end
			when 'left'
				left = window.x - monitor.x - settings.gaps[:left]
			when 'right'
				right = monitor.x_end - settings.gaps[:right] - window.x_end
		end
	else
		target = get_closest_window(target_windows, direction)
		target_windows.delete(target)
		target_windows << target
		case direction
			when 'up'
				up = window.y - target.y_end - settings.gaps[:windows_y]
			when 'down'
				down = target.y - settings.gaps[:windows_y] - window.y_end
			when 'left'
				left = window.x - target.x_end - settings.gaps[:windows_x]
			when 'right'
				right = target.x - settings.gaps[:windows_x] - window.x_end
		end

		if up + down + left + right == 0
			if direction == 'up'
				up += GROW_PUSHBACK
			elsif direction == 'down'
				down += GROW_PUSHBACK
			elsif direction == 'left'
				left += GROW_PUSHBACK
			elsif direction == 'right'
				right += GROW_PUSHBACK
			end
			target_windows.each do |w|
				if direction == 'up'
					w.grow(0, target.y_end - w.y_end - GROW_PUSHBACK, 0, 0) if w.y_end > target.y_end - GROW_PUSHBACK
				elsif direction == 'down'
					w.grow(w.y - target.y - GROW_PUSHBACK, 0, 0, 0) if w.y < target.y + GROW_PUSHBACK
				elsif direction == 'left'
					w.grow(0, 0, 0, target.x_end - w.x_end - GROW_PUSHBACK) if w.x_end > target.x_end - GROW_PUSHBACK
				elsif direction == 'right'
					w.grow(0, 0, w.x - target.x - GROW_PUSHBACK, 0) if w.x < target.x + GROW_PUSHBACK
				end
			end
		end
	end
	window.grow(up, down, left, right)
end


def get_closest_window(windows, direction)
	if direction == 'up'
		windows.sort_by! do |w| w.y_end end.reverse!
	elsif direction == 'down'
		windows.sort_by! do |w| w.y end
	elsif direction == 'left'
		windows.sort_by! do |w| w.x_end end.reverse!
	elsif direction == 'right'
		windows.sort_by! do |w| w.x end
	end
	return windows.first
end


def lies_in_path(window, target, direction)
	if direction == 'up' or direction == 'down'
		return ((direction == 'up' ? (target.y + target.height <= window.y) : (target.y >= window.y + window.height)) and lies_between(window.x, window.x_end, target.x, target.x_end))
	elsif direction == 'left' or direction == 'right'
		return ((direction == 'left' ? (target.x + target.width <= window.x) : (target.x >= window.x + window.width)) and lies_between(window.y, window.y_end, target.y, target.y_end))
	end
	return false
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
	same_pos_windows = windows.select do |w| have_same_pos(window, w) and not window.id == w.id end
	split(settings, window, direction, same_pos_windows)
end


def have_same_pos(w1, w2)
	return (w1.height == w2.height and w1.width == w2.width and w1.x == w2.x and w1.y == w2.y)
end


def split(settings, window, direction, same_pos_windows = [nil])
	window_x = window.x
	window_y = window.y
	window_height = window.height
	window_width = window.width

	same_pos_windows = [nil] if same_pos_windows.empty?
	splits = [same_pos_windows.size + 1, 2].max
	split_height = (window_height / splits) - ((splits - 1) * (settings.gaps[:windows_x] / splits))
	split_width = (window_width / splits) - ((splits - 1) * (settings.gaps[:windows_y] / splits))
	
	if direction == 'left' or direction == 'up'
		same_pos_windows.unshift(window)
	else
		same_pos_windows << window
	end
	if direction == 'left' or direction == 'right'
		same_pos_windows.each_with_index do |w, i|
			x = window_x + (i * (split_width + settings.gaps[:windows_x]))
			if i == same_pos_windows.size - 1
				split_width = (window_x + window_width) - x
			end
			w.resize(x, window_y, split_width, window_height) unless w.nil?
		end
	elsif direction == 'up' or direction == 'down'
		same_pos_windows.each_with_index do |w, i|
			y = window_y + (i * (split_height + settings.gaps[:windows_y]))
			if i == same_pos_windows.size - 1
				split_width = (window_y + window_height) - y
			end
			w.resize(window_x, y, window_width, split_height) unless w.nil?
		end
	end
end


def tile_all_binary(settings, windows, monitors, current_workspace)
	monitor_hash = get_monitor_window_hash(monitors, windows)

	monitors.each do |monitor|
		monitor_windows = get_sorted_monitor_windows(settings, monitor_hash[monitor.name], monitor, current_workspace)
		monitor_windows.reject! do |w| w.nil? end
		break if monitor_windows.empty?
		tile(settings, [[monitor_windows[0]]], monitor, 0.5)
		for i in 0...monitor_windows.size
			if i > 0
				split(settings, monitor_windows[i - 1], i % 2 == 0 ? 'up' : 'left', [monitor_windows[i]])
			end
		end
	end
end


def get_monitor_window_hash(monitors, windows)
	monitor_hash = {}
	monitors.each do |m|
		monitor_hash[m.name] = []
	end
	windows.each do |w|
		monitor = get_monitor(w, monitors)
		monitor_hash[monitor.name] << w
	end
	return monitor_hash
end


def get_sorted_monitor_windows(settings, windows, monitor, current_workspace)
	monitor_windows = windows.select do |w| (settings.floating.select do |i| w.class_name.downcase.include? i.downcase end).empty? end
	return [] if monitor_windows.empty?
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

	return monitor_windows
end


def auto_tile_all(settings, binary = false)
	require 'pty'
	begin
		PTY.spawn( "xprop -spy -root _NET_CLIENT_LIST_STACKING" ) do |stdout, stdin, pid|
			current_windows = []
			stdout.each do |line|
				begin
					windows = Window.get_visible_windows()
					if current_windows.size != windows.size or current_windows.last.id != windows.last.id
						if binary
							tile_all_binary(settings, windows, Monitor.get_monitors(), windows.last.workspace)
						else
							tile_all(settings, windows, Monitor.get_monitors(), windows.last.workspace)
						end
					end
				rescue Interrupt, SystemExit
					break
				rescue
					windows = []
				end
				current_windows = windows
			end
		end
	rescue Interrupt, SystemExit
	end
end


def tile_all(settings, windows, monitors, current_workspace)
	monitor_hash = get_monitor_window_hash(monitors, windows)
	median = settings.medians[current_workspace]

	monitors.each do |monitor|
		monitor_windows = get_sorted_monitor_windows(settings, monitor_hash[monitor.name], monitor, current_workspace)
		break if monitor_windows.empty?
		
		column_sizes = nil
		unless settings.column_configs.empty?
			column_config = settings.column_configs.select do |cs| (cs.workspace.nil? or cs.workspace == current_workspace) and cs.windows == monitor_windows.size end.last
			column_sizes = column_config.column_sizes unless column_config.nil?
		end
		
		columns = []
		if column_sizes.nil?
			columns = calc_columns(monitor_windows, settings.col_max_size_main, settings.col_max_size, settings.col_max_count)
		else
			columns = set_columns(monitor_windows, column_sizes)
		end

		columns.last.reverse! if settings.reverse_y.include? current_workspace
		columns.reverse! if settings.reverse_x.include? current_workspace
		
		tile(settings, columns, monitor, median)
	end
end

def set_columns(windows, column_sizes)
	columns = []
	column_sizes.each do |i|
		columns << windows.shift(i)
	end

	return columns
end


def calc_columns(windows, main_col_max, col_max, count_max)
	return [windows] if count_max <= 1

	columns = []

	col_count = [get_col_count(windows.size, main_col_max, col_max), count_max].min
	main_size = main_col_max

	while get_col_count(windows.size, main_size - 1, col_max) == col_count and main_size > 1
		main_size -= 1
	end

	main_size = [main_size, 1].max
	rest_size = [windows.size - main_size - ((col_count - 2) * col_max), col_max].min

	columns << windows.shift(main_size)
	columns << windows.shift(rest_size) unless windows.empty?
	(col_count - 2).times do
		columns << windows.shift(col_max)
	end
	columns.last.concat(windows) unless windows.empty?

	return columns
end

def get_col_count(window_count, main_col_max, col_max)
	col_count = ((window_count - main_col_max - 1) / col_max) + 2
	col_count = 1 if window_count <= 1
	col_count = 2 if window_count > 1 and col_count <= 1
	return col_count
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
	monitors_x = monitors.select do |m| window.x >= m.x and window.x < m.x + m.width end
	monitors_y = monitors.select do |m| window.y >= m.y and window.y < m.y + m.height end
	
	return (monitors_x & monitors_y).first unless (monitors_x & monitors_y).empty?
	return monitors_x.first unless monitors_x.empty?
	return monitors_y.first unless monitors_y.empty?
	return monitors.first
end


class Settings
	attr_reader :medians, :reverse_x, :reverse_y, :gaps, :floating, :high_priority_windows, :low_priority_windows, :column_configs, :fake_windows, :col_max_size_main, :col_max_size, :col_max_count

	def initialize(config_file = nil)
		@medians = {}
		@reverse_x = []
		@reverse_y = []
		@gaps = {:top => 0, :bottom => 0, :left => 0, :right => 0, :windows_x => 0, :windows_y => 0}
		@floating = []
		@high_priority_windows = []
		@low_priority_windows = []
		@column_configs = []
		@fake_windows = {}
		@col_max_size_main = 2
		@col_max_size = 4
		@col_max_count = 2

		return if config_file.nil?

		unless File.exists?(config_file)
			FileUtils.mkdir_p(File.dirname(config_file))
			xml_file = File.new(config_file, 'w')
			xml_file.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<settings>\n	<gaps top=\"42\" bottom=\"22\" left=\"22\" right=\"22\" windows_x=\"22\" windows_y=\"22\"/>\n	<columns max_size_main=\"2\" max_size=\"4\" max_count=\"2\"/>\n\n	<!--<workspace id=\"<id>\" median=\"0.5\" reverse_x=\"true|false\" reverse_y=\"true|false\"/>-->\n\n	<!--<window class=\"<class>\" priority=\"high|low\" floating=\"true|false\" fake_windows=\"1|2|3|...\"/>-->\n\t<column_config windows=\"1\" workspace=\"all\" column_sizes=\"1\"/>\n\t<column_config windows=\"2\" workspace=\"all\" column_sizes=\"1, 1\"/>\n\t<column_config windows=\"3\" workspace=\"all\" column_sizes=\"1, 2\"/>\n\t<column_config windows=\"4\" workspace=\"all\" column_sizes=\"1, 3\"/>\n\t<column_config windows=\"5\" workspace=\"all\" column_sizes=\"2, 3\"/>\n\t<column_config windows=\"6\" workspace=\"all\" column_sizes=\"2, 4\"/>\n\t<column_config windows=\"7\" workspace=\"all\" column_sizes=\"1, 2, 4\"/>\n</settings>")
			xml_file.close
		end

		xml_file = File.new(config_file)
		xml_doc = Document.new(xml_file)		
		xml_doc.elements["settings"].elements.each do |el|
			if el.name == 'gaps'
				@gaps[:top] = el.attributes["top"].to_i
				@gaps[:bottom] = el.attributes["bottom"].to_i
				@gaps[:left] = el.attributes["left"].to_i
				@gaps[:right] = el.attributes["right"].to_i
				@gaps[:windows_x] = el.attributes["windows_x"].to_i
				@gaps[:windows_y] = el.attributes["windows_y"].to_i
			elsif el.name == 'columns'
				@col_max_size_main = el.attributes["max_size_main"].to_i
				@col_max_size = el.attributes["max_size"].to_i
				@col_max_count = el.attributes["max_count"].to_i
			elsif el.name == 'workspace'
				workspace_id = el.attributes["id"]
				unless el.attributes["median"].nil?
					@medians[workspace_id] = el.attributes["median"].to_f
				end
				if el.attributes["reverse_x"] == 'true'
					@reverse_x << workspace_id
				end
				if el.attributes["reverse_y"] == 'true'
					@reverse_y << workspace_id
				end
			elsif el.name == 'window'
				window_class = el.attributes["class"]
				if el.attributes["floating"] == 'true'
					@floating << window_class
				end
				if el.attributes["priority"] == 'high'
					@high_priority_windows << window_class
				elsif el.attributes["priority"] == 'low'
					@low_priority_windows << window_class
				end
				unless el.attributes["fake_windows"].nil?
					@fake_windows[window_class] = el.attributes["fake_windows"].to_i
				end
			elsif el.name == 'column_config'
				column_configs << ColumnConfig.new(el.attributes["windows"], el.attributes["workspace"], el.attributes["column_sizes"])
			end
		end
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


class ColumnConfig
	attr_reader :windows, :workspace, :column_sizes

	def initialize(windows, workspace, column_sizes)
		@windows = windows.to_i
		@workspace = workspace == 'all' ? nil : workspace
		@column_sizes = column_sizes.split(/ *, */).collect do |cs| cs.to_i end
	end
end


class Window # requires: wmcrtl, xprop, xwininfo
	attr_reader :id, :title, :class_name, :workspace, :x, :y, :width, :height, :pid, :hidden, :fullscreen, :decorations, :ignore

	def initialize(id)
		@id = id
		@decorations = Hash.new
		@ignore = false
		@hidden = false
		@fullscreen = false
		@decorations[:left], decorations[:right], decorations[:top], decorations[:bottom] = 0, 0, 0, 0
		
		xprop = `xprop -id #{@id} WM_CLASS WM_NAME _NET_WM_ALLOWED_ACTIONS _NET_WM_STATE _NET_WM_DESKTOP _NET_WM_WINDOW_TYPE _NET_WM_PID _NET_FRAME_EXTENTS`.to_s
		
		xprop.each_line do |line|
			if line.include? 'WM_CLASS'
				@class_name = line.split('=').last.strip.split(', ').last.strip.tr('"', '')
			elsif line.include? 'WM_NAME'
				@title = line.split('=').last.strip.tr('"', '')
			elsif line.include? '_NET_WM_WINDOW_TYPE'
				type = line.split('=').last.strip
				#["_NET_WM_WINDOW_TYPE_DOCK", "_NET_WM_WINDOW_TYPE_TOOLBAR", "_NET_WM_WINDOW_TYPE_MENU", "_NET_WM_WINDOW_TYPE_UTILITY", "_NET_WM_WINDOW_TYPE_DIALOG"]
				@ignore = true unless type == '_NET_WM_WINDOW_TYPE_NORMAL' or type.include?('not found')
			elsif line.include? '_NET_WM_STATE'
				@hidden = line.split('=').last.include?('_NET_WM_STATE_HIDDEN')
				@fullscreen = line.split('=').last.include?('_NET_WM_STATE_FULLSCREEN')
			elsif line.include? '_NET_WM_ALLOWED_ACTIONS' and not line.include? 'not found'
				@ignore = true unless line.include? '_NET_WM_ACTION_RESIZE'
			elsif line.include? '_NET_WM_DESKTOP'
				@workspace = line.split('=').last.strip
			elsif line.include? '_NET_WM_PID'
				@pid = line.split('=').last.strip.to_i
			elsif line.include? '_NET_FRAME_EXTENTS' and not line.include? 'not found'
				@decorations[:left], decorations[:right], decorations[:top], decorations[:bottom] = line.split('=').last.strip.split(",").collect do |i| i.strip.to_i || 0 end
			end
		end
		unless @ignore
			update_dimensions()
		end
	end
	
	def update_dimensions()
		@x, @y, @width, @height = calc_dimensions()
	end
	
	
	def get_dimensions()
		return @x, @y, @width, @height
	end
	
	
	def self.get_visible_windows()
		current_workspace = Monitor.get_current_workspace()
		windows = get_windows()
		return (windows.select do |w| w.workspace == current_workspace and not w.hidden and not w.fullscreen end)
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
		`xprop -root _NET_CLIENT_LIST_STACKING`.to_s.each_line do |line|
			id_string = line.gsub(/_NET_CLIENT_LIST_STACKING\(WINDOW\): *window id # +/, "")
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
		return `xprop -root _NET_ACTIVE_WINDOW`.strip.split(' ').last
	end
	
	def resize(x, y, width, height, correction = true)
		x = x || @x
		y = y || @y
		width = width || @width
		height = height || @height
		
		@x, @y, @width, @height = x, y, width, height

		width -= (@decorations[:left] + @decorations[:right])
		height -= (@decorations[:top] + @decorations[:bottom])


		window_string = "-i -r #{@id}"
		command = "wmctrl #{window_string} -e 0,#{x},#{y},#{width},#{height}"

		`wmctrl #{window_string} -b remove,maximized_vert,maximized_horz`
		#~ `wmctrl #{window_string} -b remove,fullscreen`
		#~ puts command
		`#{command}`
		
		if correction
			current_x, current_y, current_width, current_height = calc_dimensions()
			offset_x = x - current_x
			offset_y = y - current_y
			offset_width = width - current_width
			offset_height = height - current_height
			if(offset_x != 0 or offset_y != 0 or offset_width != 0 or offset_height != 0)
				resize(x + offset_x, y + offset_y, width - offset_width, height - offset_height, false)
			end
		end
	end


	def calc_dimensions()
		x, y, width, height = 0, 0, 0, 0
		win_info = `xwininfo -id #{@id}`
			
		win_info.each_line do |line|
			if line.include? 'Width:'
				width = line.match(/Width: *(.+)/i).captures.first.strip.to_i
			elsif line.include? 'Height:'
				height = line.match(/Height: *(.+)/i).captures.first.strip.to_i
			elsif line.include? 'Absolute upper-left X:'
				x = line.match(/Absolute upper-left X: *(.+)/i).captures.first.strip.to_i
			elsif line.include? 'Absolute upper-left Y:'
				y = line.match(/Absolute upper-left Y: *(.+)/i).captures.first.strip.to_i
			end
		end
		
		x -= @decorations[:left]
		y -= @decorations[:top]
		width += @decorations[:right] + @decorations[:left]
		height += @decorations[:bottom] + @decorations[:top]
		
		return x, y, width, height
	end
	
	
	def grow(up, down, left, right)
		x = @x - left
		width = @width + left + right
		
		y = @y - up
		height = @height + up + down
		
		self.resize(x, y, width, height)
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
		return `xprop -root _NET_CURRENT_DESKTOP`.to_s.split('=').last.strip
	end
	
	
	def get_dimensions()
		return @x, @y, @width, @height
	end


	def self.get_monitors()
		xrandr_output = `xrandr --query`

		monitors = []
		id = 0
		xrandr_output.each_line do |line|
			if line =~ /.+ connected.*(\d+)x(\d+)\+(\d+)\+(\d+)/
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
