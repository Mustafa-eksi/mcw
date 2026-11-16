module mcw.tests.roadmap_widgets;

import std.string : toStringz;
import bindbc.sdl;
import bindbc.loader : LoadMsg;
import mcw.widgets;

private struct Fixture {
    SDL_Surface *surface;
    SDL_Renderer *renderer;
    TTF_Font *font;

    @disable this(this);

    this(int width, int height) {
        assert(loadSDL() == LoadMsg.success);
        assert(SDL_Init(0));
        assert(loadSDLTTF() == LoadMsg.success);
        assert(TTF_Init());
        surface = SDL_CreateSurface(width, height, SDL_PIXELFORMAT_RGBA32);
        assert(surface !is null);
        renderer = SDL_CreateSoftwareRenderer(surface);
        assert(renderer !is null);
        font = TTF_OpenFont("liberation-sans.ttf", 14);
        assert(font !is null);
    }

    ~this() {
        TTF_CloseFont(font);
        SDL_DestroyRenderer(renderer);
        SDL_DestroySurface(surface);
        TTF_Quit();
        SDL_Quit();
    }

    void render(Widget widget) {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
        widget.draw();
        SDL_RenderPresent(renderer);
    }

    SDL_Color pixel(int x, int y) {
        SDL_Color color;
        assert(SDL_ReadSurfacePixel(surface, x, y, &color.r, &color.g, &color.b, &color.a));
        return color;
    }
}

private SDL_Event mouse(uint type, float x, float y) {
    SDL_Event event = SDL_Event();
    event.type = type;
    event.button.x = x;
    event.button.y = y;
    return event;
}

private SDL_Event key(SDL_KeyCode code) {
    SDL_Event event = SDL_Event();
    event.type = SDL_EVENT_KEY_DOWN;
    event.key.key = code;
    return event;
}

private class HitProbe : Widget {
    int clicks;
    this(SDL_FRect rect, SDL_Renderer *renderer) { super(rect, renderer); }
    override void handleEvent(SDL_Event *event) {
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP) clicks++;
    }
}

unittest {
    auto f = Fixture(160, 120);
    int activations;
    auto button = new Button(SDL_FRect(10, 10, 60, 24), f.renderer, f.font, "Go");
    scope(exit) destroy(button);
    button.onActivate = () { activations++; };
    button.style.background_color = SDL_Color(20, 30, 40, 255);
    button.style.pressed_color = SDL_Color(80, 90, 100, 255);
    auto down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, 15, 15);
    button.handleEvent(&down);
    assert(button.pressed);
    f.render(button);
    assert(f.pixel(12, 12).r == 80);
    auto up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 15, 15);
    button.handleEvent(&up);
    assert(activations == 1 && !button.pressed);
    button.focused = true;
    auto enter = key(SDLK_RETURN);
    button.handleEvent(&enter);
    assert(activations == 2);
    button.enabled = false;
    button.handleEvent(&enter);
    assert(activations == 2);
    button.enabled = true;
    button.style.border_color = SDL_Color(0, 255, 0, 255);
    button.style.focused_border_color = SDL_Color(255, 255, 0, 255);
    button.focusVisible = false;
    f.render(button);
    assert(f.pixel(10, 10).r == 0 && f.pixel(10, 10).g == 255);
    button.focusVisible = true;
    f.render(button);
    assert(f.pixel(10, 10).r == 255 && f.pixel(10, 10).g == 255);
}

unittest {
    auto f = Fixture(160, 120);
    auto check = new CheckBox(SDL_FRect(2, 2, 80, 24), f.renderer, f.font, "Active");
    scope(exit) destroy(check);
    bool changed;
    check.onToggle = (bool value) { changed = value; };
    check.activate();
    assert(check.checked && changed);
    f.render(check);
    assert(f.pixel(9, 12).r > 0);
    check.activate();
    assert(!check.checked && !changed);

    auto group = new RadioGroup();
    auto first = new RadioButton(SDL_FRect(2, 30, 80, 24), f.renderer, f.font, "One");
    auto second = new RadioButton(SDL_FRect(2, 60, 80, 24), f.renderer, f.font, "Two");
    scope(exit) { destroy(first); destroy(second); }
    group.add(first); group.add(second);
    first.activate();
    assert(group.selected == 0 && first.checked && !second.checked);
    second.activate();
    assert(group.selected == 1 && !first.checked && second.checked);
}

unittest {
    auto f = Fixture(160, 120);
    auto combo = new ComboBox(SDL_FRect(2, 2, 80, 20), f.renderer, f.font,
            ["Red", "Green", "Blue"]);
    scope(exit) destroy(combo);
    assert(combo.selected == 0);
    auto click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 10, 10);
    combo.handleEvent(&click);
    assert(combo.expanded);
    combo.style.background_color = SDL_Color(30, 40, 50, 255);
    f.render(combo);
    assert(f.pixel(3, 25).r == 30);
    click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 10, 50);
    combo.handleEvent(&click);
    assert(combo.selected == 1 && combo.text == "Green" && !combo.expanded);
    combo.focused = true;
    auto down = key(SDLK_DOWN);
    combo.handleEvent(&down);
    assert(combo.selected == 2);
    auto parent = new Canvas(SDL_FRect(0, 0, 100, 100), f.renderer);
    parent.addAnchored(combo);
    click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 10, 10);
    parent.handleEvent(&click);
    assert(combo.expanded);
    click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 10, 30);
    parent.handleEvent(&click);
    assert(combo.selected == 0 && !combo.expanded);
}

unittest {
    auto f = Fixture(160, 120);
    auto slider = new Slider(SDL_FRect(10, 10, 100, 20), f.renderer, 0, 10, 5);
    int changes;
    slider.onChange = (double _) { changes++; };
    auto down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, 109, 20);
    slider.handleEvent(&down);
    assert(slider.value > 9 && changes == 1);
    auto move = SDL_Event();
    move.type = SDL_EVENT_MOUSE_MOTION;
    move.motion.x = 200;
    slider.handleEvent(&move);
    assert(slider.value == 10);
    move.motion.x = -20;
    slider.handleEvent(&move);
    assert(slider.value == 0);
    auto up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 10, 20);
    slider.handleEvent(&up);
    assert(!slider.dragging);
    slider.focused = true;
    auto right = key(SDLK_RIGHT);
    slider.handleEvent(&right);
    assert(slider.value > 0);
    f.render(slider);
    assert(f.pixel(20, 19).r > 0);

    auto progress = new ProgressBar(SDL_FRect(10, 40, 100, 10), f.renderer, 0.5);
    progress.setProgress(2);
    assert(progress.progress == 1);
    progress.setProgress(0.25);
    f.render(progress);
    assert(f.pixel(20, 45).g == 190 && f.pixel(50, 45).g == 0);
}

unittest {
    auto f = Fixture(160, 120);
    auto separator = new Separator(SDL_FRect(10, 10, 40, 10), f.renderer);
    f.render(separator);
    assert(f.pixel(20, 15).r == 160 && f.pixel(20, 10).r == 0);
    auto spacer = new Spacer(SDL_FRect(10, 10, 40, 10), f.renderer);
    f.render(spacer);
    assert(f.pixel(20, 15).r == 0);
    auto row = new Box(SDL_FRect(0, 0, 100, 20), f.renderer, 0,
            Box.Orientation.Horizontal);
    row.uniform = false;
    row.addChild(new Widget(SDL_FRect(0, 0, 20, 20), f.renderer));
    row.addChild(spacer);
    row.addChild(new Widget(SDL_FRect(0, 0, 20, 20), f.renderer));
    assert(spacer.rect.w == 60);

    auto target = new Widget(SDL_FRect(10, 10, 30, 20), f.renderer);
    auto tip = new Tooltip(SDL_FRect(50, 10, 80, 20), f.renderer, f.font, "Hint", target);
    scope(exit) destroy(tip);
    tip.style.background_color = SDL_Color(10, 20, 30, 255);
    f.render(tip);
    assert(f.pixel(55, 15).r == 0);
    target.hovered = true;
    f.render(tip);
    assert(f.pixel(55, 15).r == 10);
    target.hovered = false;
    target.focused = true;
    f.render(tip);
    assert(!tip.shown);
    assert(f.pixel(55, 15).r == 0);
    target.focusVisible = true;
    f.render(tip);
    assert(f.pixel(55, 15).r == 10);
    assert(!tip.contains(55, 15));

    target.focused = false;
    target.focusVisible = false;
    auto root = new Canvas(SDL_FRect(0, 0, 140, 50), f.renderer);
    root.addAnchored(target);
    root.addAnchored(tip);
    auto tab = key(SDLK_TAB);
    root.handleEvent(&tab);
    assert(target.focused && target.focusVisible && tip.shown);
    auto press = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, 15, 15);
    root.handleEvent(&press);
    assert(target.focused && !target.focusVisible && !tip.shown);
}

unittest {
    auto f = Fixture(160, 120);
    auto input = new TextInput(SDL_FRect(2, 2, 120, 20), f.renderer, f.font);
    scope(exit) destroy(input);
    string last;
    input.onChange = (string value) { last = value; };
    SDL_Event text = SDL_Event();
    text.type = SDL_EVENT_TEXT_INPUT;
    text.text.text = "éa".toStringz;
    input.handleEvent(&text);
    assert(input.text == "éa" && last == "éa" && input.cursor == 3);
    auto left = key(SDLK_LEFT);
    input.handleEvent(&left);
    assert(input.cursor == 2);
    input.handleEvent(&left);
    assert(input.cursor == 0);
    text.text.text = "X".toStringz;
    input.handleEvent(&text);
    assert(input.text == "Xéa");
    auto selectAll = key(SDLK_A);
    selectAll.key.mod = SDL_KMOD_CTRL;
    input.handleEvent(&selectAll);
    text.text.text = "B".toStringz;
    input.handleEvent(&text);
    assert(input.text == "B" && input.cursor == 1);
    input.setValue("ABCDE");
    input.focused = true;
    selectAll = key(SDLK_A);
    selectAll.key.mod = SDL_KMOD_CTRL;
    input.handleEvent(&selectAll);
    f.render(input);
    assert(f.pixel(4, 10).b > 0);
    auto click = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, 2, 8);
    input.handleEvent(&click);
    assert(input.cursor == 0 && input.draggingSelection);
    click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 2, 8);
    input.handleEvent(&click);
    assert(!input.draggingSelection);
}

unittest {
    auto f = Fixture(180, 60);
    auto input = new TextInput(SDL_FRect(10, 10, 80, 26), f.renderer, f.font);
    scope(exit) destroy(input);
    input.focused = true;
    SDL_Event text = SDL_Event();
    text.type = SDL_EVENT_TEXT_INPUT;
    text.text.text = "aaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbb".toStringz;
    input.handleEvent(&text);
    assert(input.text_width > input.rect.w);
    assert(input.scrollX == input.text_width - 78);
    assert(input.text_x < input.rect.x);
    f.render(input);
    assert(f.pixel(88, 20).r == 255);
    assert(f.pixel(95, 20).r == 0);

    auto click = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, 12, 20);
    input.handleEvent(&click);
    assert(input.cursor > 0 && input.cursor < input.text.length);
    auto home = key(SDLK_HOME);
    input.handleEvent(&home);
    assert(input.cursor == 0 && input.scrollX == 0);
    auto end = key(SDLK_END);
    input.handleEvent(&end);
    assert(input.cursor == input.text.length && input.scrollX > 0);

    input.rect = SDL_FRect(10, 10, 170, 26);
    assert(input.scrollX == input.text_width - 168);
    input.setValue("short");
    assert(input.scrollX == 0 && input.cursor == input.text.length);
}

unittest {
    auto f = Fixture(160, 120);
    auto free = new Canvas(SDL_FRect(0, 0, 100, 80), f.renderer);
    auto anchored = new Widget(SDL_FRect(70, 50, 20, 20), f.renderer);
    free.addAnchored(anchored, true, true);
    free.rect = SDL_FRect(0, 0, 150, 100);
    assert(anchored.rect.x == 120 && anchored.rect.y == 70);
    free.removeChild(0);
    assert(free.children.length == 0);

    auto content = new HitProbe(SDL_FRect(0, 0, 100, 100), f.renderer);
    content.style.background_color = SDL_Color(200, 0, 0, 255);
    auto view = new ScrollView(SDL_FRect(10, 10, 40, 30), f.renderer);
    view.setContent(content, 100, 100);
    view.setScroll(0, 500);
    assert(view.scrollY == 70 && content.rect.y == -60);
    f.render(view);
    assert(f.pixel(20, 20).r == 200 && f.pixel(20, 45).r == 0);
    SDL_Event wheel = SDL_Event();
    wheel.type = SDL_EVENT_MOUSE_WHEEL;
    wheel.wheel.mouseX = 20; wheel.wheel.mouseY = 20; wheel.wheel.y = 1;
    view.handleEvent(&wheel);
    assert(view.scrollY == 46);
    auto click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 20, 20);
    view.handleEvent(&click);
    assert(content.clicks == 1);
    click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 20, 45);
    view.handleEvent(&click);
    assert(content.clicks == 1);
}

unittest {
    auto f = Fixture(160, 120);
    auto list = new SelectableList(SDL_FRect(0, 0, 100, 60), f.renderer, 0);
    auto first = new ListItem(SDL_FRect(0, 0, 100, 20), f.renderer, f.font, "First");
    auto second = new ListItem(SDL_FRect(0, 0, 100, 20), f.renderer, f.font, "Second");
    assert(first.text_placement == Label.TextPlacement.Center);
    scope(exit) { destroy(first); destroy(second); }
    list.addChild(first); list.addChild(second);
    int picked = -1;
    list.onActivate = (int i) { picked = i; };
    auto down = key(SDLK_DOWN);
    list.handleEvent(&down);
    assert(list.selectedIndex == 0 && first.selected);
    list.handleEvent(&down);
    assert(list.selectedIndex == 1 && second.selected && !first.selected);
    auto enter = key(SDLK_RETURN);
    list.handleEvent(&enter);
    assert(picked == 1);
    list.clearSelection();
    auto up = key(SDLK_UP);
    list.handleEvent(&up);
    assert(list.selectedIndex == 1);
    f.render(list);
    assert(f.pixel(50, 25).b == 140);
}

unittest {
    auto f = Fixture(160, 120);
    auto tabs = new Tabs(SDL_FRect(0, 0, 100, 80), f.renderer, f.font);
    auto red = new Widget(SDL_FRect(0, 0, 1, 1), f.renderer);
    auto blue = new Widget(SDL_FRect(0, 0, 1, 1), f.renderer);
    red.style.background_color = SDL_Color(255, 0, 0, 255);
    blue.style.background_color = SDL_Color(0, 0, 255, 255);
    tabs.addTab("A", red); tabs.addTab("B", blue);
    f.render(tabs);
    assert(f.pixel(50, 50).r == 255);
    auto click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 75, 10);
    tabs.handleEvent(&click);
    f.render(tabs);
    assert(tabs.selected == 1 && f.pixel(50, 50).b == 255);

    auto menu = new Menu(SDL_FRect(0, 0, 100, 50), f.renderer);
    auto item = new MenuItem(SDL_FRect(0, 0, 100, 20), f.renderer, f.font, "Open");
    scope(exit) destroy(item);
    int activations;
    item.onActivate = () { activations++; };
    menu.addItem(item);
    menu.open = true;
    click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 5, 5);
    menu.handleEvent(&click);
    assert(activations == 1 && !menu.open);
    item.setShortcut(SDLK_O, SDL_KMOD_CTRL);
    auto shortcut = key(SDLK_O);
    shortcut.key.mod = SDL_KMOD_CTRL;
    menu.handleEvent(&shortcut);
    assert(activations == 2);

    auto nested = new Menu(SDL_FRect(100, 0, 50, 40), f.renderer);
    auto child = new MenuItem(SDL_FRect(100, 0, 50, 20), f.renderer, f.font, "Child");
    scope(exit) destroy(child);
    nested.addItem(child);
    item.setSubmenu(nested);
    menu.open = true;
    click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 5, 5);
    menu.handleEvent(&click);
    assert(nested.open);
    click = mouse(SDL_EVENT_MOUSE_BUTTON_UP, 105, 5);
    menu.handleEvent(&click);
    assert(!nested.open && !menu.open);
    item.setSubmenu(null);
    menu.open = true;
    auto downKey = key(SDLK_DOWN);
    menu.handleEvent(&downKey);
    assert(menu.activeIndex == 0);
    auto enterKey = key(SDLK_RETURN);
    menu.handleEvent(&enterKey);
    assert(activations == 3 && !menu.open);
}

unittest {
    auto f = Fixture(80, 80);
    auto source = SDL_CreateSurface(2, 1, SDL_PIXELFORMAT_RGBA32);
    assert(source !is null);
    scope(exit) SDL_DestroySurface(source);
    assert(SDL_WriteSurfacePixel(source, 0, 0, 255, 0, 0, 255));
    assert(SDL_WriteSurfacePixel(source, 1, 0, 0, 0, 255, 255));
    auto texture = SDL_CreateTextureFromSurface(f.renderer, source);
    assert(texture !is null);
    scope(exit) SDL_DestroyTexture(texture);
    assert(SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST));
    auto image = new Image(SDL_FRect(10, 10, 20, 20), f.renderer, texture, Image.Fit.Contain);
    f.render(image);
    assert(f.pixel(15, 12).r == 0 && f.pixel(15, 20).r == 255 &&
            f.pixel(25, 20).b == 255);
    image.fit = Image.Fit.Cover;
    f.render(image);
    assert(f.pixel(11, 11).r > 0 || f.pixel(11, 11).b > 0);
}
