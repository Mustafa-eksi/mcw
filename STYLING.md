# Styling MCW widgets

`Style` remains available for direct assignments. To style a widget tree from a
CSS file, build the tree, give selected widgets an ID or classes, and apply a
sheet to its root:

```d
import mcw.widgets;

auto button = new Button(bounds, renderer, font, "Save");
button.styleId = "save";
button.styleClasses = ["primary"];
box.addChild(button);

auto sheet = loadCSS("theme.css");
sheet.apply(box);
```

`StyleSheet.parse(cssText)` loads a string instead of a file. Widgets retain
the applied sheet. Applying a new sheet replaces the old sheet
on the root and its current descendants. Apply again after adding children or
changing a class that controls layout. Colors and state styles are resolved on
each draw, so hover, pressed, checked, selected, focus, and disabled changes
appear without reapplying.

Supported selectors: `*`, widget class names such as `Button` (including
subclasses), `.class`, `#id`, and combinations such as
`Button.primary:hover, #save:focus-visible`. The supported states are `hover`,
`focus`, `focus-visible`, `pressed`, `disabled`, `checked`, and `selected`.
Normal CSS specificity and source order determine which declaration wins.
Ancestor/descendant selectors, media queries, variables, and animations are
outside this CSS subset. Unsupported selectors, properties, and values raise
`CSSException` when the sheet is parsed.

| Property | Effect |
| --- | --- |
| `background`, `background-color` | Widget fill |
| `border`, `border-color`, `border-width`, `border-radius`, `focused-border-color` | Widget outline and corners |
| `color` | Label text, input text/caret, checkbox and radio marks |
| `padding` | Label/input insets and Box/List content insets |
| `gap` | Box/List child spacing |
| `hover-color`, `pressed-color`, `disabled-color` | State fill fallback |
| `track-color`, `thumb-color` | Slider parts |
| `fill-color` | ProgressBar and Separator fill |
| `selection-color` | Selected ListItem fill and TextInput selection |

Colors accept `#RGB`, `#RRGGBB`, `#RRGGBBAA`, or `transparent`. Sizes are
nonnegative integers with optional `px`; `padding` accepts one to four sizes.
The `border` shorthand accepts `width solid color` or `none`.

```css
Button.primary {
    background: #304a7e;
    color: #fff;
    border: 2px solid #627fb9;
    border-radius: 6px;
    padding: 4px 8px;
}
Button.primary:hover { background: #4369ab; }
Button.primary:pressed { background: #203b67; }
Button.primary:focus-visible { focused-border-color: #f9bf5c; }
Box { gap: 8px; padding: 12px; }
```

The font remains the `TTF_Font*` supplied when a text widget is constructed.

## Hot reload

Use `StyleSheetWatcher` when a CSS file should update while the application
runs. Its constructor loads and applies the file. Call `poll()` from a timed
event-loop wakeup; it checks the file at most every 250 ms and only reparses
changed contents. Redraw only when `poll()` returns true or the displayed
error message changes.
`poll(true)` checks immediately, which is useful for a reload shortcut.

```d
auto liveTheme = new StyleSheetWatcher("theme.css", box);
// At a periodic event-loop wakeup:
if (liveTheme.poll()) window.draw();
```

The watcher exposes `sheet`, `revision`, and `lastError`. Failed reads or CSS
edits leave the last valid style active. `addRoot(otherWidget)` applies the
same live sheet to another widget tree. The showcase's four editable examples
are in `themes/`; run the showcase from the repository root so their relative
paths resolve.
