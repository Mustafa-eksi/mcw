# Layout

Every widget has an `SDL_FRect` in window coordinates: `x` and `y` are the top-left
position, and `w` and `h` are its size. The window gives its root widget the
window rectangle when the widget is assigned and when the window is resized.

## Containers

`Container` owns an ordered `children` array. A container draws its background
and border, then draws visible children in array order. The last child is drawn
on top. A mouse-button-up event inside overlapping children selects the last
visible child whose rectangle contains the pointer. The selected child receives
the event and becomes focused.

`Box` places all children in a row or column with `spacing` around and between
them. On the main axis, `uniform = true` gives every child an equal share of the
available space. With `uniform = false`, each child's existing width or height
is kept on that axis. On the other axis, children fill the container between
its spacing margins.

`List` places visible children in a row or column. It takes `element_size` from
the first child's height or width when that child is added. Every visible child
uses that size on the main axis and fills the other axis between the spacing
margins. Invisible children do not take a slot in a `List`. `idealHeight()` is
available for vertical lists when sizing a parent to fit their items.

## When layout runs

Adding or removing a child runs its container's `adjustLayout()`. Assigning a
complete rectangle through `widget.rect = SDL_FRect(...)` calls `hasMoved()`;
for a container this runs `adjustLayout()`, which assigns each child's complete
rectangle once. Nested containers then update their own children. Layout does
not run during drawing.

`widget.rect` can be read, but its fields cannot be changed directly. To resize
or move a widget, copy its rectangle into an `SDL_FRect`, change the copy, and
assign it back. Changing `visible`, `spacing`, `orientation`, `uniform`, or
`element_size` does not automatically rerun layout; call `adjustLayout()` after
changing those properties when the children's positions need updating.

## Free placement and anchors

There is no free-placement container or anchor API yet. A future canvas could
store each child's rectangle relative to the canvas and convert it to window
coordinates when the canvas moves or resizes. A right anchor would keep a fixed
gap from the canvas's right edge. For a 120-pixel-wide child with a 12-pixel
right gap, `child.x = canvas.x + canvas.w - 12 - 120`. With `canvas.x = 0`,
resizing the canvas from 400 to 600 pixels wide moves the child from `x = 268`
to `x = 468`. The child's width and gap stay the same.
