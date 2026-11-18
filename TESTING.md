# Testing layouts

Run the automated tests from the repository root:

```sh
dub test --compiler=ldc2 --temp-build
```

The tests in `source/mcw/tests/` draw widgets into an SDL surface using
`SDL_CreateSoftwareRenderer`. They do not open a window or wait for input.
Each test clears the surface, draws one layout, and calls `SDL_RenderPresent`
before reading its pixels. The tests write binary PPM (`P6`) images to
`test-output/`; this directory is ignored by Git. Open these files when an
assertion fails to inspect the rendered result.

`layout_pixels.d` checks Box and List in both orientations. `layout_behavior.d`
checks relayout, style propagation, container draw order, focus, and removal.
`widget_rendering.d` checks the base Widget's fill and borders, Icon texture
pixels at two sizes, Label text rendering, placement, and clipping, TextInput
editing and rendering, and IconList population, updates, and drawing.
`roadmap_widgets.d` checks the added controls, scrolling and clipping,
anchoring, selection, menus, tabs, text editing and horizontal scrolling, and
image fit modes.
`styling_css.d` checks file loading, selector precedence, state changes,
layout padding, rendered borders and control colors, and hot reload recovery
after invalid or missing CSS.
`showcase_window.d` creates the complete showcase with SDL's dummy video driver,
renders every tab and color scheme into `test-output/showcase-*.bmp`, and checks button, menu,
scroll, resize, tooltip hover, and long text clipping through the window event
path.
`launcher_window.d` builds a small set of desktop entries and icons, checks
exact icon lookup, keyboard and mouse selection, all four input modes, theme
changes, theme persistence across launcher instances, search URL dispatch, and
compact window heights. `launcher_actions.d`
checks arithmetic parsing and URL encoding. Launcher states render to
`test-output/launcher-*.bmp`.

## What a layout test should check

- Use a small, fixed surface and integer sizes so the expected pixel positions
  are unambiguous.
- Give children distinct, solid colors. Assert the expected color at every pixel,
  including the empty space around children and between them.
- Count pixels of each relevant color as an additional check on size. Count the
  colors read from the surface, rather than just the positions expected to have
  those colors.
- Calculate expected positions from the intended layout behavior. Do not derive
  them from the widget's `rect`, since that would let a layout error validate
  itself.
- Keep each case focused on one behavior.

## Adding a test

Add a D `unittest` block to the relevant file in `source/mcw/tests/`. Follow
the existing setup and cleanup: load SDL, call `SDL_Init(0)`, create an
`SDL_PIXELFORMAT_RGBA32` surface and its software renderer, and destroy the
renderer before the surface. `widget_rendering.d` provides a `Canvas` helper
for this setup. Give each pixel check a unique name; it saves
`test-output/<name>.ppm` and fails if any pixel differs from the expected
color. Add explicit color counts where they make the expected area easier to
verify.

Prefer testing layout and solid-color drawing first. The Icon test creates its
own four-color texture and matches every output pixel. The text tests use the
repository's `liberation-sans.ttf` and check pixel color, bounds, and movement
without matching font glyph shapes, which may differ across renderer versions.
Keep the interactive windows in `source/mcw/apps/test.d` and
`source/mcw/apps/test_list.d` for manual exploration; automated assertions belong
in `source/mcw/tests/`.
