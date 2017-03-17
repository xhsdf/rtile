#!/usr/bin/ruby


# requires: xprop, pxdo.py


NAME = "rtile"
VERSION = "2.01"
GROW_PUSHBACK = 32


if ARGV.include? '--version'
	puts "#{NAME} v#{VERSION}"
	exit
end


require 'fileutils'
require 'rexml/document'
include REXML


$actions = []
$windows = []
$active_window = nil
$monitors = []
$settings = nil


def main()
	$settings = Settings.new()
	additions = []
	(ARGV.select do |arg| arg.start_with? "--add-to-config=" end).each do |addition|
		additions << addition.sub(/^--add-to-config=/, "")
	end
	$settings.read((ARGV.include? "--no-config-file") ? nil : "#{ENV['HOME']}/.config/rtile/rtile.xml", additions)

	get_infos()

	if ARGV.include? "--all"
		tile_all()
	elsif ARGV.include? "--all-binary"
		tile_all_binary()
	elsif ARGV.include? "--all-auto"
		auto_tile_all()
	elsif ARGV.include? "--all-auto-binary"
		auto_tile_all(true)
	elsif ARGV.include? "--binary"
		binary()
	elsif ARGV.include? "--swap"
		swap()
	elsif ARGV.include? "--swap-biggest"
		swap_biggest()
	elsif ARGV.include? "--cycle"
		cycle()
	elsif ARGV.include? "--next-monitor"
		next_monitor_active()
	elsif ARGV.include? "--cycle-monitors"
		cycle_monitors()
	elsif not (split = ARGV.grep(/--split-(up|down|left|right)/)).empty?
		split_active(split.first.gsub(/^--split-/, ''))
	elsif not (grow = ARGV.grep(/--grow-(up|down|left|right)/)).empty?
		grow_active(grow.first.gsub(/^--grow-/, ''))
	elsif not (grid = ARGV.grep(/--grid-\d+x\d+-\d+,\d+/)).empty?
		grid_active(grid.first.gsub(/^--grid-/, ''))
	else
		tile_active(ARGV.select do |arg| arg =~ /^(l|r|t|b)+$/ end)
	end

	update()
end


def update()
	unless $actions.empty?
		command = "pxdo.py " + $actions.join(" ")
		#~ puts command
		`#{command}`
		$actions = []
	end
end


def get_infos()
	$windows = []
	$monitors = []
	`pxdo.py --print-window-info --print-monitor-info`.to_s.each_line do |line|
		if line.start_with?("WINDOW: ")
			line = line[8..-1]
			id, geometry, extents, workspaces, states, wmclass, title = line.split("\t")
			workspace, current_workspace = workspaces.split(":").collect do |ws| ws.strip end
			states = states.split(",")
			w = Window.new(id, geometry, extents, workspace, states, wmclass, title)
			$active_window = w if w.active
			if w.workspace == current_workspace and not(w.hidden or w.fullscreen)
				$windows << w
			end
		elsif line.start_with?("MONITOR: ")
			line = line[9..-1]
			name, id, geometry = line.split("\t")
			$monitors << Monitor.new(name, id, geometry)
		end
	end
end


def tile_active(args)
	window = $active_window
	return if window.nil?
	current_workspace = window.workspace
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
	grid($settings, window, $monitors, current_workspace, cols, rows, x, y)
end


def grid(settings, window, monitors, current_workspace, cols, rows, x, y)
	columns = []
	(0...cols).each do |c|
		columns << []
		(0...rows).each do |r|
			columns[c][r] = nil
		end
	end
	columns[x][y] = window

	tile(settings, columns, get_monitor(window, monitors), settings.medians[current_workspace])
end


def binary()
	return if $windows.size < 2
	current_workspace = $windows.first.workspace
	windows = $windows.reverse[0...2]
	monitor = get_monitor(windows.last, $monitors)
	horizontal = (windows.last.width.to_f / windows.last.height.to_f) < (monitor.width.to_f / monitor.height.to_f)
	split($settings, windows.last, horizontal ? 'up' : 'left', [windows.first])
end


def cycle()
	return if $active_window.nil?
	monitor = get_monitor($active_window, $monitors)
	windows = $windows.select do |w| monitor == get_monitor(w, $monitors) end

	window_dimensions = windows.rotate.collect do |w| w.get_dimensions() end

	windows.size.times do |i|
		windows[i].resize(*window_dimensions[i])
	end
end


def swap()
	return if $windows.size < 2
	current_workspace = $windows.first.workspace
	windows = $windows.reverse[0...2]
	swap_windows(windows.first, windows.last)
end


def swap_biggest()
	return if $windows.size < 2
	current_workspace = $windows.first.workspace
	active_window = $windows.last
	biggest_window = ($windows.sort_by do |w| w.height * w.width end).reverse.first
	swap_windows(active_window, biggest_window)
end


def swap_windows(window1, window2)
	window1_dimensions = window1.get_dimensions()
	window1.resize(*window2.get_dimensions())
	window2.resize(*window1_dimensions)
end


def grow_active(direction)
	window = $active_window
	return if window.nil?
	other_windows = $windows.select do |w| window.id != w.id end
	grow($settings, window, direction, other_windows)
end


def grid_active(params)
	window = $active_window
	return if window.nil?
	current_workspace = window.workspace
	cols, rows, x, y = params.match(/(\d+)x(\d+)-(\d+),(\d+)/i).captures	
	grid($settings, window, $monitors, current_workspace, cols.to_i, rows.to_i, x.to_i - 1 , y.to_i - 1)
end


def cycle_monitors()
	$windows.each do |w|
		move_to_next_monitor(w, $monitors)
	end
end


def next_monitor_active()
	window = $active_window
	return if window.nil?
	move_to_next_monitor(window, $monitors)
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
	monitor = get_monitor(window, $monitors)
	target_windows = other_windows.select do |w| lies_in_path(window, w, direction) and get_monitor(w, $monitors) == monitor end
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


def split_active(direction)
	window = $active_window
	return if window.nil?
	same_pos_windows = $windows.select do |w| have_same_pos(window, w) and not window.id == w.id end
	split($settings, window, direction, same_pos_windows)
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


def tile_all_binary()
	current_workspace = $windows.first.workspace
	monitor_hash = get_monitor_window_hash($monitors, $windows)
	reverse_x = $settings.reverse_x.include? current_workspace
	reverse_y = $settings.reverse_y.include? current_workspace

	$monitors.each do |monitor|
		monitor_windows = get_sorted_monitor_windows($settings, monitor_hash[monitor.name], monitor, current_workspace)
		monitor_windows.reject! do |w| w.nil? end
		next if monitor_windows.empty?
		tile($settings, [[monitor_windows[0]]], monitor, 0.5)
		for i in 0...monitor_windows.size
			if i > 0
				split($settings, monitor_windows[i - 1], i % 2 == 0 ? (reverse_y ? 'down' : 'up') : (reverse_x ? 'right' : 'left'), [monitor_windows[i]])
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


def auto_tile_all(binary = false)
	require 'pty'
	begin
		PTY.spawn("xprop -spy -root _NET_CLIENT_LIST_STACKING") do |stdout, stdin, pid|
			current_windows = []
			stdout.each do |line|
				begin
					get_infos()
					if current_windows.size != $windows.size or current_windows.last.id != windows.last.id
						if binary
							tile_all_binary()
						else
							tile_all()
						end
						update()
					end
				rescue Interrupt, SystemExit
					break
				rescue
				end
				current_windows = $windows
			end
		end
	rescue Interrupt, SystemExit
	end
end


def tile_all()
	current_workspace = $windows.first.workspace
	monitor_hash = get_monitor_window_hash($monitors, $windows)
	median = $settings.medians[current_workspace]

	$monitors.each do |monitor|
		monitor_windows = get_sorted_monitor_windows($settings, monitor_hash[monitor.name], monitor, current_workspace)
		next if monitor_windows.empty?

		column_sizes = nil
		unless $settings.column_configs.empty?
			column_config = $settings.column_configs.select do |cs| (cs.workspace.nil? or cs.workspace == current_workspace) and (cs.monitor.nil? or cs.monitor == monitor.name or cs.monitor == monitor.id.to_s) and cs.windows == monitor_windows.size end.last
			column_sizes = column_config.column_sizes unless column_config.nil?
		end

		columns = []
		if column_sizes.nil?
			columns = calc_columns(monitor_windows, $settings.col_max_size_main, $settings.col_max_size, settings.col_max_count)
		else
			columns = set_columns(monitor_windows, column_sizes)
		end

		columns.last.reverse! if $settings.reverse_y.include? current_workspace
		columns.reverse! if $settings.reverse_x.include? current_workspace

		tile($settings, columns, monitor, median)
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


	def initialize()
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
	end


	def read(config_file, additions = [])
		unless config_file.nil? or File.exists?(config_file)
			FileUtils.mkdir_p(File.dirname(config_file))
			xml_file = File.new(config_file, 'w')
			xml_file.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<settings>\n	<gaps top=\"42\" bottom=\"22\" left=\"22\" right=\"22\" windows_x=\"22\" windows_y=\"22\"/>\n	<columns max_size_main=\"2\" max_size=\"4\" max_count=\"2\"/>\n\n	<!--<workspace id=\"<id>\" median=\"0.5\" reverse_x=\"true|false\" reverse_y=\"true|false\"/>-->\n\n	<!--<window class=\"<class>\" priority=\"high|low\" floating=\"true|false\" fake_windows=\"1|2|3|...\"/>-->\n\t<column_config windows=\"1\" workspace=\"all\" column_sizes=\"1\"/>\n\t<column_config windows=\"2\" workspace=\"all\" column_sizes=\"1, 1\"/>\n\t<column_config windows=\"3\" workspace=\"all\" column_sizes=\"1, 2\"/>\n\t<column_config windows=\"4\" workspace=\"all\" column_sizes=\"1, 3\"/>\n\t<column_config windows=\"5\" workspace=\"all\" column_sizes=\"2, 3\"/>\n\t<column_config windows=\"6\" workspace=\"all\" column_sizes=\"2, 4\"/>\n\t<column_config windows=\"7\" workspace=\"all\" column_sizes=\"1, 2, 4\"/>\n</settings>")
			xml_file.close
		end

		xml_string = config_file.nil? ? "<settings></settings>" : File.new(config_file).read
		additions.each do |addition|
			xml_string.gsub!(/<\/settings>/, "#{addition}\\0")
		end
		xml_doc = Document.new(xml_string)
		xml_doc.elements["settings"].elements.each do |el|
			if el.name == 'gaps'
				@gaps[:top] = el.attributes["top"].to_i unless el.attributes["top"].nil?
				@gaps[:bottom] = el.attributes["bottom"].to_i unless el.attributes["bottom"].nil?
				@gaps[:left] = el.attributes["left"].to_i unless el.attributes["left"].nil?
				@gaps[:right] = el.attributes["right"].to_i unless el.attributes["right"].nil?
				@gaps[:windows_x] = el.attributes["windows_x"].to_i unless el.attributes["windows_x"].nil?
				@gaps[:windows_y] = el.attributes["windows_y"].to_i unless el.attributes["windows_y"].nil?
			elsif el.name == 'columns'
				@col_max_size_main = el.attributes["max_size_main"].to_i unless el.attributes["max_size_main"].nil?
				@col_max_size = el.attributes["max_size"].to_i unless el.attributes["max_size"].nil?
				@col_max_count = el.attributes["max_count"].to_i unless el.attributes["max_count"].nil?
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
				column_configs << ColumnConfig.new(el.attributes["windows"], el.attributes["workspace"], el.attributes["column_sizes"], el.attributes["monitor"])
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
	attr_reader :windows, :workspace, :column_sizes, :monitor


	def initialize(windows, workspace, column_sizes, monitor)
		@windows = windows.to_i
		@workspace = workspace == 'all' ? nil : workspace
		@monitor = monitor == 'all' ? nil : monitor
		@column_sizes = column_sizes.split(/ *, */).collect do |cs| cs.to_i end
	end
end


class Window
	attr_reader :id, :title, :class_name, :workspace, :x, :y, :width, :height, :active, :hidden, :fullscreen, :decorations


	def initialize(id, geometry, extents, workspace, tags, wmclass, title)
		@id, @workspace, @class_name = id, workspace, wmclass
		@width, @height, @x, @y = geometry.gsub("x", "+").split("+").collect do |g| g.to_i end
		@active = tags.include? "active"
		@hidden = tags.include? "hidden"
		@fullscreen = tags.include? "fullscreen"

		@decorations = Hash.new
		@decorations[:left], decorations[:right], decorations[:top], decorations[:bottom] = extents.split(",").collect do |d| d.to_i end
	end


	def x_end()
		return @x + @width
	end


	def y_end()
		return @y + @height
	end


	def get_dimensions()
		return @x, @y, @width, @height
	end


	def resize(x, y, width, height)
		x = x || @x
		y = y || @y
		width = width || @width
		height = height || @height

		@x, @y, @width, @height = x, y, width, height

		$actions << "--move-#{@id}-#{width}x#{height}+#{x}+#{y}"
	end


	def grow(up, down, left, right)
		x = @x - left
		width = @width + left + right

		y = @y - up
		height = @height + up + down

		self.resize(x, y, width, height)
	end
end


class Monitor
	attr_reader :width, :height, :x, :y, :id, :windows, :name


	def initialize(name, id, geometry)
		@width, @height, @x, @y = geometry.gsub("x", "+").split("+").collect do |g| g.to_i end
		@name, @id = name, id
	end


	def x_end()
		return @x + @width
	end


	def y_end()
		return @y + @height
	end


	def get_dimensions()
		return @x, @y, @width, @height
	end
end


main()
