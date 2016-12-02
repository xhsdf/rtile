Ruby script for manual tiling and window placement.

#Demo using Openbox

![Demo](http://i.imgur.com/4VgLJBn.gif)

#Modes

##--all

tile all windows on screen

##--all-binary

tile all windows on screen and have every window take half the space of the previous window

##--all-auto

automatically tile all windows on screen when a new window is opened, closed or focused

##(t|b|l|r|tl|tr|bl|br)

move active window to edges (left, top-left, top, top-right, etc.)

Example 1: `rtile.rb l` will place the window on the left half of the screen  
Example 2: `rtile.rb tr` will place the window on the top right of the screen

##--split-(up|down|left|right)

split active window (either in half or using all windows occupying the same space)

##--grow-(up|down|left|right)

grow active window to the nearest edge (window or screen) of a direction

if the window is already at the edge of another window it will be pushed back

##--grid-(c)x(r)-(x),(y)

place active window at x,y in a grid of c columns and r rows

Example 1: `--grid-3x3-2,2` will place the window in the middle of a 3x3 grid  
Example 2: `--grid-2x2-2,1` is the same as `rtile.rb tr`

##--binary

split the last two active windows at the position of the older window

##--swap

swap the position of the last two active windows

##--swap-biggest

swap the position of the active window with the biggest window on the same screen

##--cycle

cycle the positions of all windows on screen

##--next-monitor

move active window to the next monitor

##--cycle-monitors

move all windows on screen to their next monitor

##--version

show version

#Features

-gaps between windows in all operating modes

-settings per workspace (median, window placement direction)

-fake windows that keep certain windows from covering more space than wanted

-setting for which windows to ignore when auto-tiling


#Dependencies

-xprop

-wmctrl

-xwininfo

-xrandr


#Settings

When rtile is run it will look for a config file in $HOME/.config/rtile/rtile.xml. If it does not exist it will be generated.

##Gap settings

###top, bottom, left, right
space between windows and screen edges

###windows_x
horizontal space between windows

###windows_y
vertical space between windows

##Column settings

###max_size_main
Maximum number of windows in the main(first) column

###max_size
Maximum number of windows in other columns

###max_count
Maximum number of columns

##Workspace settings
Workspace settings are only relevant for automatic tiling. Except for median

###id
Id of the workspace

###median
Determines how much width the main window takes up  
default = 0.5

###reverse_x
`true`: the main window is placed on the right

###reverse_y
`true`: windows are placed from the bottom up

##Window settings
Window settings are only relevant for automatic tiling

###class
Window class (e.g. "firefox" or "mpv")

###priority
`high`: High priority windows get placed first  
`low`: Low priority windows get placed last. Even after fake windows

###fake_windows
Pretends that there are at least this many windows on the same monitor as the application  
Example 1: `fake_windows="2"` will make the window never take up the whole desktop even if it is the only window on screen  
Example 2: `priority="low" fake_windows="3"` will place a window on the bottom right of the desktop even if it is the only window on screen

###floating
`true`: window will be ignored

##Custom column configs
Manually set the count of columns and windows per column for a specific number of windows on a workspace

###windows
Number of windows the config applies to

###workspace
Workspace the config applies to. Empty or 'all' applies to all workspaces

###column_sizes
Array of column sizes
Example: `column_sizes="1, 3"` will make 2 columns. The first will have 1 window and the second will have 3 windows.

##Example config

```
<?xml version="1.0" encoding="UTF-8"?>
<settings>
	<gaps top="42" bottom="22" left="22" right="22" windows_x="22" windows_y="22"/>
	<columns max_size_main="2" max_size="4" max_count="3"/>

	<workspace id="0" median="0.6"/>
	<workspace id="1"/>
	<workspace id="2"/>
	<workspace id="3" median="0.6"/>
	<workspace id="4" reverse_x="true" median="0.4"/>

	<window class="mpv" floating="true"/>
	<window class="firefox" priority="high"/>
	<window class="geany" priority="high" fake_windows="2"/>
	<window class="nemo" fake_windows="3"/>
	<window class="transmission-gtk" priority="low" fake_windows="3"/>
	<window class="terminator" priority="low" fake_windows="3"/>
	
	<column_config windows="1" workspace="all" column_sizes="1"/>
	<column_config windows="2" workspace="all" column_sizes="1, 1"/>
	<column_config windows="3" workspace="all" column_sizes="1, 2"/>
	<column_config windows="4" workspace="all" column_sizes="1, 3"/>
	<column_config windows="5" workspace="all" column_sizes="2, 3"/>
	<column_config windows="6" workspace="all" column_sizes="2, 4"/>
	<column_config windows="7" workspace="all" column_sizes="1, 2, 4"/>
</settings>
```


#Example keybindings for Openbox using the keypad

```
<keybind key="C-W-KP_8">
	<action name="Execute">
		<command>rtile.rb --split-up</command>
	</action>
</keybind>
<keybind key="C-W-KP_2">
	<action name="Execute">
		<command>rtile.rb --split-down</command>
	</action>
</keybind>
<keybind key="C-W-KP_4">
	<action name="Execute">
		<command>rtile.rb --split-left</command>
	</action>
</keybind>
<keybind key="C-W-KP_6">
	<action name="Execute">
		<command>rtile.rb --split-right</command>
	</action>
</keybind>
<keybind key="C-W-KP_0">
	<action name="Execute">
		<command>rtile.rb --swap</command>
	</action>
</keybind>
<keybind key="C-W-KP_5">
	<action name="Execute">
		<command>rtile.rb --next-monitor</command>
	</action>
</keybind>

<keybind key="S-W-KP_8">
	<action name="Execute">
		<command>rtile.rb --grow-up</command>
	</action>
</keybind>
<keybind key="S-W-KP_2">
	<action name="Execute">
		<command>rtile.rb --grow-down</command>
	</action>
</keybind>
<keybind key="S-W-KP_4">
	<action name="Execute">
		<command>rtile.rb --grow-left</command>
	</action>
</keybind>
<keybind key="S-W-KP_6">
	<action name="Execute">
		<command>rtile.rb --grow-right</command>
	</action>
</keybind>
<keybind key="S-W-KP_0">
	<action name="Execute">
		<command>rtile.rb --cycle</command>
	</action>
</keybind>
<keybind key="S-W-KP_5">
	<action name="Execute">
		<command>rtile.rb --cycle-monitors</command>
	</action>
</keybind>

<keybind key="W-KP_8">
	<action name="Execute">
		<command>rtile.rb t</command>
	</action>
</keybind>
<keybind key="W-KP_5">
	<action name="Execute">
		<command>rtile.rb</command>
	</action>
</keybind>
<keybind key="W-KP_2">
	<action name="Execute">
		<command>rtile.rb b</command>
	</action>
</keybind>
<keybind key="W-KP_7">
	<action name="Execute">
		<command>rtile.rb tl</command>
	</action>
</keybind>
<keybind key="W-KP_4">
	<action name="Execute">
		<command>rtile.rb l</command>
	</action>
</keybind>
<keybind key="W-KP_1">
	<action name="Execute">
		<command>rtile.rb bl</command>
	</action>
</keybind>
<keybind key="W-KP_9">
	<action name="Execute">
		<command>rtile.rb tr</command>
	</action>
</keybind>
<keybind key="W-KP_6">
	<action name="Execute">
		<command>rtile.rb r</command>
	</action>
</keybind>
<keybind key="W-KP_3">
	<action name="Execute">
		<command>rtile.rb br</command>
	</action>
</keybind>
<keybind key="W-KP_0">
	<action name="Execute">
		<command>rtile.rb --binary</command>
	</action>
</keybind>
```
