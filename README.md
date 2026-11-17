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
brightness, toggle the `power-saver` profile, keep KDE from sleeping, open
Bluetooth settings, and access a power and session submenu. The power off, log
off, and restart buttons open KDE's confirmation
prompt. The sleep button suspends the machine.

It uses `busctl`, `qdbus6`, `pactl`, `powerprofilesctl`, `kde-inhibit`,
`kcmshell6`, and `systemctl`; remote album artwork also uses `curl`. Missing
services appear unavailable. On KDE Wayland, the bar uses XWayland when available
so it can start at the top of the screen. The SDL window stays above ordinary
windows but does not reserve screen space as a native Plasma panel would.

# Styling

MCW supports direct `Style` assignments and loading CSS files for widget trees.
See [STYLING.md](STYLING.md) for selectors, supported properties, and examples.
