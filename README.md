Ruby script for tiling and window placement.

##Demo using Openbox

![Demo](http://i.imgur.com/4VgLJBn.gif)

##Modes

###xh_tile.rb --all

tile all windows on screen

###xh_tile.rb --all-auto

automatically tile all windows on screen when a new window is opened or closed

###xh_tile.rb (t|b|l|r|tl|tr|bl|br)

move active window to edges (left, top-left, top, top-right, etc.)

###xh_tile.rb --split-(up|down|left|right)

split active window (either in half or using all windows occupying the same space)

###xh_tile.rb --grow-(up|down|left|right)

grow active window to the nearest edge (window or screen) of a direction

###xh_tile.rb --version

show version

##Features

-gaps between windows in all operating modes

-settings per workspace (median, window placement direction)

-fake windows that keep certain windows from covering more space than wanted

-setting for which windows to ignore when auto-tiling


##Dependencies

-xprop

-wmctrl

-xwininfo

-xrandr


##Example config file

```
<?xml version="1.0" encoding="UTF-8"?>
<settings>
	<gaps top="42" bottom="22" left="22" right="22" windows_x="22" windows_y="22"/>
	<!--<workspace id="<id>" median="0.6" reverse_x="true|false" reverse_y="true|false"/>-->
	<workspace id="0" median="0.6"/>
	<workspace id="1"/>
	<workspace id="2"/>
	<workspace id="3" median="0.6"/>
	<workspace id="4" reverse_x="true" median="0.4"/>

	<!--
		fake_windows: pretends there are at least this many windows on the same monitor as the application
		priority="high": high priority windows get placed first
		priority="low": low priority windows get placed last. even after fake windows
	-->
	<!--<window class="<class>" priority="high|low" floating="true|false" fake_windows="1|2|3|..."/>-->
	<window class="mpv" floating="true"/>

	<window class="firefox" priority="high"/>
	<window class="geany" priority="high" fake_windows="2"/>

	<window class="nemo" fake_windows="3"/>

	<window class="transmission-gtk" priority="low" fake_windows="3"/>
	<window class="terminator" priority="low" fake_windows="3"/>
</settings>
```


##Example keybindings for Openbox using the keypad

```
<keybind key="C-W-KP_8">
	<action name="Execute">
		<command>xh_tile.rb --split-up</command>
	</action>
</keybind>
<keybind key="C-W-KP_2">
	<action name="Execute">
		<command>xh_tile.rb --split-down</command>
	</action>
</keybind>
<keybind key="C-W-KP_4">
	<action name="Execute">
		<command>xh_tile.rb --split-left</command>
	</action>
</keybind>
<keybind key="C-W-KP_6">
	<action name="Execute">
		<command>xh_tile.rb --split-right</command>
	</action>
</keybind>

<keybind key="S-W-KP_8">
	<action name="Execute">
		<command>xh_tile.rb --grow-up</command>
	</action>
</keybind>
<keybind key="S-W-KP_2">
	<action name="Execute">
		<command>xh_tile.rb --grow-down</command>
	</action>
</keybind>
<keybind key="S-W-KP_4">
	<action name="Execute">
		<command>xh_tile.rb --grow-left</command>
	</action>
</keybind>
<keybind key="S-W-KP_6">
	<action name="Execute">
		<command>xh_tile.rb --grow-right</command>
	</action>
</keybind>

<keybind key="W-KP_8">
	<action name="Execute">
		<command>xh_tile.rb t</command>
	</action>
</keybind>
<keybind key="W-KP_5">
	<action name="Execute">
		<command>xh_tile.rb</command>
	</action>
</keybind>
<keybind key="W-KP_2">
	<action name="Execute">
		<command>xh_tile.rb b</command>
	</action>
</keybind>
<keybind key="W-KP_7">
	<action name="Execute">
		<command>xh_tile.rb tl</command>
	</action>
</keybind>
<keybind key="W-KP_4">
	<action name="Execute">
		<command>xh_tile.rb l</command>
	</action>
</keybind>
<keybind key="W-KP_1">
	<action name="Execute">
		<command>xh_tile.rb bl</command>
	</action>
</keybind>
<keybind key="W-KP_9">
	<action name="Execute">
		<command>xh_tile.rb tr</command>
	</action>
</keybind>
<keybind key="W-KP_6"><action name="Execute">
		<command>xh_tile.rb r</command>
	</action>
</keybind>
<keybind key="W-KP_3">
	<action name="Execute">
		<command>xh_tile.rb br</command>
	</action>
</keybind>
```
