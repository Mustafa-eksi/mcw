# Mustafa's Creative Widgets
An UI library that tries to make it easier and extendible to create your own
widgets from D.

See [WIDGETS.md](WIDGETS.md) for the widget catalog and [LAYOUT.md](LAYOUT.md)
for layout behavior. Run `dub test --compiler=ldc2 --temp-build` to verify the
widgets and `dub build --compiler=ldc2 --temp-build` to build the demo app.

Run the interactive widget showcase from the repository root:

```sh
dub run --compiler=ldc2 -- showcase
```

The showcase has six tabs: Basics, Controls, Lists, Layout, Menus, and Themes. Click
or focus controls to exercise them. The Lists tab scrolls with the mouse wheel;
the Layout tab demonstrates resizing and overlapping hit targets; the Menus tab
has a nested menu and a Ctrl+1 shortcut. Press Escape to close an open menu or
exit the window.

The Themes tab offers Midnight, Daylight, Forest, and Sunset. Press F1–F4 to
switch palettes from any tab. Edit the active file under `themes/` while the
showcase runs; it reloads automatically. Press F5 to check the file immediately.

Run the application launcher from the repository root:

```sh
dub run --compiler=ldc2 -- launcher
```

Type to search installed applications; the launcher shrinks as results narrow.
Use Up/Down and Enter to open a result. Escape closes it, and F1–F4 switch its
theme. Icons come from XDG user and system locations; missing icons use a letter
badge.

The selected theme is saved in `~/.config/mcw/launcher.conf` and restored the
next time the launcher opens. If `XDG_CONFIG_HOME` is set, the file lives under
`$XDG_CONFIG_HOME/mcw/launcher.conf` instead. The file contains, for example,
`theme=forest`.

The search field also accepts modes: `>` lists launcher commands (theme changes
and exit), `!` runs a Bash command, `=` calculates an expression, and `?` opens
a web search in the default browser. Press Enter to run a command or search.
Math mode supports arithmetic, powers, parentheses, `pi`, `e`, and functions
such as `sqrt`, `sin`, `cos`, `tan`, `abs`, `ln`, and `log`.

# Desktop bar

Run the KDE bar from the repository root:

```sh
dub run --compiler=ldc2 --temp-build -- bar
```

The top bar has a KWin virtual desktop switcher, a centered clock, compact MPRIS
media controls beside the status notifier tray, and an icon button for quick
controls. The tray uses only the space needed by visible items. Click the album
thumbnail to open the larger media panel with artwork, a seek bar, and previous,
pause or resume, and next buttons. Escape closes an open popup without closing
the bar.

The popup uses installed Breeze theme icons to adjust volume and screen
brightness, toggle the `power-saver` profile, and keep KDE from sleeping.
Its Wi-Fi submenu can switch Wi-Fi on or off, refresh nearby networks, and
connect to one. Its Bluetooth submenu can switch the adapter on or off, scan
for devices, pair, connect, disconnect, and open KDE Bluetooth settings. The
power and session submenu provides power off, log off, restart, and sleep.
Power off, log off, and restart open KDE's confirmation prompt; sleep suspends
the machine.

It uses `busctl`, `qdbus6`, `pactl`, `powerprofilesctl`, `kde-inhibit`,
`nmcli`, `bluetoothctl`, `kcmshell6`, and `systemctl`; remote album artwork
also uses `curl`. Missing
services appear unavailable. On KDE Wayland, the bar uses XWayland when available
so it can start at the top of the screen. The SDL window stays above ordinary
windows but does not reserve screen space as a native Plasma panel would.

# Daemon and window control

Run the long-lived daemon from the repository root:

```sh
dub run --compiler=ldc2 --temp-build -- daemon
```

It starts with the bar visible. In another terminal, use the built `mcw`
executable (or `dub run --compiler=ldc2 --temp-build -- <command>`):

```sh
mcw show launcher
mcw hide bar
mcw toggle bar
mcw show dialog
mcw status
mcw stop
```

`show`, `hide`, and `toggle` accept `bar`, `launcher`, `dialog`, `showcase`,
`test`, and `test_list`. Closing a managed window hides it; `stop` ends the
daemon. Showing the launcher clears its previous search. The existing
`mcw bar` and `mcw launcher` commands still run standalone.

The CLI uses a local Unix socket under `$XDG_RUNTIME_DIR`, scoped by the
graphical session's `WAYLAND_DISPLAY`, `DISPLAY`, or `XDG_SESSION_ID`. The
daemon and CLI must use the same session environment. The socket is created
with owner-only permissions and removed on shutdown. `mcw daemon` stays in the
foreground so a session startup script or systemd user service can manage it;
such a service must set its working directory to the repository root so the
font and theme files can be found.

An example user service is in `contrib/mcw.service`. Build without
`--temp-build` to place the current executable in the repository root, then
copy the unit to `~/.config/systemd/user/mcw.service` and adjust its paths if
your checkout is elsewhere. Reload the user manager and start the unit with
`systemctl --user daemon-reload` and `systemctl --user enable --now mcw.service`.

# Styling

MCW supports direct `Style` assignments and loading CSS files for widget trees.
See [STYLING.md](STYLING.md) for selectors, supported properties, and examples.
