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

# Styling

MCW supports direct `Style` assignments and loading CSS files for widget trees.
See [STYLING.md](STYLING.md) for selectors, supported properties, and examples.
