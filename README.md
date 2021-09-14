# Ruby Script for Manual Tiling and Window Placement

![Demo](http://i.imgur.com/4VgLJBn.gif)

> Demo using Openbox

# Modes

## `--all`

Tile all windows on screen.

## `--all-active`

Tile all windows on the same monitor as the active window.

## `--all-binary`

Tile all windows on screen and have every window take half the space of the previous window.

## `(t|b|l|r|tl|tr|bl|br)`

Move active window to edges (left, top-left, top, top-right, etc.).

Example 1: `rtile.rb l` will place the window on the left half of the screen.\
Example 2: `rtile.rb tr` will place the window on the top right of the screen.

## `--split-(up|down|left|right)`

Split active window (either in half or using all windows occupying the same space).

## `--grow-(up|down|left|right)`

Grow active window to the nearest edge (window or screen) of a direction.
If the window is already at the edge of another window it will be pushed back.

## `--grid-(c)x(r)-(x),(y)`

Place active window at `x,y` in a grid of `c` columns and `r` rows.

Example 1: `--grid-3x3-2,2` will place the window in the middle of a 3x3 grid.\
Example 2: `--grid-2x2-2,1` is the same as `rtile.rb tr`.

## `--binary`

Split the last two active windows at the position of the older window.

## `--swap`

Swap the position of the last two active windows.

## `--swap-biggest`

Swap the position of the active window with the biggest window on the same screen.

## `--cycle`

Cycle the positions of all windows on screen.

## `--next-monitor`

Move active window to the next monitor.

## `--cycle-monitors`

Move all windows on screen to their next monitor.

## `--no-config-file`

Do not load config file.

## `--add-to-config`

Adds elements to the config (does not write them to file).

Example 1: `--add-to-config=<gaps bottom="42"/>` sets the bottom gap.\
Example 2: `--add-to-config=<column_config windows="3" monitor="1"  column_sizes="2, 1"/>` adds a column config.\
Example 3: `--add-to-config=<column_config windows="3" monitor="1"  column_sizes="2, 1"/><gaps bottom="42"/>` adds a column config and sets the bottom gap.

## `--version`

Show version.

# Features

- Gaps between windows in all operating modes.
- Settings per workspace (median, window placement direction).
- Fake windows that keep certain windows from covering more space than wanted.
- Setting for which windows to ignore when auto-tiling.

# Dependencies

- [pxdo](https://github.com/xhsdf/pxdo)

# Settings

When rtile is run it will look for a config file in `$HOME/.config/rtile/rtile.xml`.
If it does not exist it will be generated.

## Gap Settings

### `top`, `bottom`, `left`, `right`

Space between windows and screen edges.

#### Per monitor gap settings

Gap settings defined for a monitor take priority over the general settings.

Example:
```
	<gaps monitor="DP-1" top="22"/>
	<gaps top="42" bottom="22" left="22" right="22" windows_x="22" windows_y="22"/>
```

### `windows_x`

Horizontal space between windows.

### `windows_y`

Vertical space between windows.

## Column Settings

### `max_size_main`

Maximum number of windows in the main(first) column.

### `max_size`

Maximum number of windows in other columns.

### `max_count`

Maximum number of columns.

## Workspace Settings

Workspace settings are only relevant for automatic tiling.
Except for median.

### `id`

Id of the workspace.

### `median`

Determines how much width the main window takes up (default = 0.5).

### `reverse_x`

`true`: The main window is placed on the right.

### `reverse_y`

`true`: Windows are placed from the bottom up.

## Window Settings

Window settings are only relevant for automatic tiling.

### `class`

Window class (e.g. "firefox" or "mpv").

### `priority`

`high`: High priority windows get placed first.\
`low`: Low priority windows get placed last. Even after fake windows.

### `fake_windows`

Pretends that there are at least this many windows on the same monitor as the application.\
Example 1: `fake_windows="2"` will make the window never take up the whole desktop even if it is the only window on screen.\
Example 2: `priority="low" fake_windows="3"` will place a window on the bottom right of the desktop even if it is the only window on screen.

### `floating`

`true`: Window will be ignored.

## Custom Column Configs

Manually set the count of columns and windows per column for a specific number of windows on a workspace.

### `windows`

Number of windows the config applies to.

### `workspace`

Workspace the config applies to. Empty or 'all' applies to all workspaces.

### `monitor`

Monitor the config applies to. Can be the id (0, 1, 2, ...) or the name (e.g. HDMI-0). Empty or 'all' applies to all monitors.

### `column_sizes`

Array of column sizes.\
Example: `column_sizes="1, 3"` will make 2 columns. The first will have 1 window and the second will have 3 windows.

## Example Config

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
	<column_config windows="4" workspace="all" monitor="all" column_sizes="1, 3"/>
	<column_config windows="4" workspace="all" monitor="1" column_sizes="2, 2"/>
	<column_config windows="5" workspace="all" column_sizes="2, 3"/>
	<column_config windows="6" workspace="all" column_sizes="2, 4"/>
	<column_config windows="7" workspace="all" column_sizes="1, 2, 4"/>
</settings>
```

# Example Keybindings for Openbox using the Keypad

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
