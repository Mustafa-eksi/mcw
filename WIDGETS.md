# Widget catalog

MCW currently provides `Widget`, `Container`, `Box`, `List`, `Label`, `Icon`,
`TextInput`, and the launcher-specific `IconList`. The controls below are now
implemented and exported by `mcw.widgets`.

## Current app controls

1. **Button** — A clickable and keyboard-activated control with a label or icon,
   hover/pressed/disabled states, and an activation callback. The dialog currently
   uses plain `Label` widgets for OK and Cancel.
2. **SelectableList / ListItem** — Reusable selection state, mouse selection,
   arrow-key navigation, and activation. This would move selection behavior out
   of the launcher and make `IconList` a presentation of generic list items.
3. **ScrollView** — A clipped viewport with wheel and keyboard scrolling for
   content larger than its rectangle. The launcher currently shows only a fixed
   number of matches.
4. **TextInput improvements** — Keep the existing widget, but add SDL text-input
   events, a real caret and selection, cursor movement, paste, and a change
   callback. This is needed for reliable entry of non-ASCII text and editing.
5. **Canvas** — Free placement with optional edge anchors, as described in
   `LAYOUT.md`. This covers overlays and controls that should keep a fixed gap
   from a window edge.

## General controls

6. **CheckBox** — A labeled on/off value, with mouse and keyboard toggling.
7. **RadioButton / RadioGroup** — One choice from a small set.
8. **ComboBox** — One choice from a larger set without displaying every option.
9. **Slider** — A bounded numeric value that can be dragged or changed by keys.
10. **ProgressBar** — Read-only progress for longer operations.
11. **Separator / Spacer** — Simple visual division and flexible empty space in
    `Box` layouts.

## Additional controls

12. **Tabs** — Switch between several content panels in one window.
13. **Menu / MenuItem** — Application commands, including nested menus and
    keyboard shortcuts.
14. **Tooltip** — Short contextual text shown on hover or focus.
15. **Image** — Display a texture with fit, fill, and alignment options beyond
    the existing icon use case.

`Widget` and `Container` provide focus traversal, hover, disabled state, and
pointer routing. `ScrollView` clips its content and limits pointer events to
its viewport. `TextInput` accepts SDL text events and supports UTF-8 cursor
movement, selection, clipboard actions, and change callbacks. `MenuItem`
supports key and modifier shortcuts and optional submenus.

Run `dub test --compiler=ldc2 --temp-build` for rendering and interaction tests
covering every widget in this catalog. Run `dub build --compiler=ldc2
--temp-build` to check the application build. Run `dub run --compiler=ldc2 --
showcase` to try the widgets in one window.
