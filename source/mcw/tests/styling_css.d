module mcw.tests.styling_css;

import std.file : write, remove, exists;
import bindbc.sdl;
import bindbc.loader : LoadMsg;
import mcw.widgets;

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(SDL_Init(0));
    scope(exit) SDL_Quit();
    auto surface = SDL_CreateSurface(100, 70, SDL_PIXELFORMAT_RGBA32);
    assert(surface !is null);
    scope(exit) SDL_DestroySurface(surface);
    auto renderer = SDL_CreateSoftwareRenderer(surface);
    assert(renderer !is null);
    scope(exit) SDL_DestroyRenderer(renderer);

    auto root = new Box(SDL_FRect(0, 0, 100, 70), renderer, 0,
        Container.Orientation.Vertical);
    auto child = new Widget(SDL_FRect(0, 0, 20, 20), renderer);
    child.styleId = "action";
    child.styleClasses = ["primary", "wide"];
    root.addChild(child);

    auto sheet = StyleSheet.parse(`
        /* Base styles and source order */
        Widget { background-color: #123; border-color: #00ff00; border-width: 2px; }
        .primary { background-color: #ff0000; }
        #action { background-color: #0000ff; }
        #action.primary.wide:hover { background-color: #aabbcc; }
        Box { padding: 4px 6px; gap: 2px; }
        #action:disabled { background-color: #888; }
    `);
    sheet.apply(root);
    assert(root.spacing == 2);
    assert(child.rect.x == 8 && child.rect.y == 6);
    assert(child.rect.w == 84 && child.rect.h == 58);
    assert(child.computedStyle().background_color.b == 255);
    child.hovered = true;
    assert(child.computedStyle().background_color.r == 0xaa);
    assert(child.computedStyle().background_color.g == 0xbb);
    child.hovered = false;
    child.enabled = false;
    assert(child.computedStyle().background_color.r == 0x88);
    child.enabled = true;

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    root.draw();
    SDL_RenderPresent(renderer);
    SDL_Color pixel;
    assert(SDL_ReadSurfacePixel(surface, 9, 8, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.g == 255); // second pixel remains inside the two-pixel border
    assert(SDL_ReadSurfacePixel(surface, 12, 12, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.b == 255);

    auto path = "test-output/style-load.css";
    import std.file : mkdirRecurse;
    mkdirRecurse("test-output");
    write(path, "Widget { background: #f00; border: 2px solid #0f0; " ~
        "border-radius: 5px; padding: 1px 2px 3px 4px; color: #abc; }");
    scope(exit) remove(path);
    auto fromFile = loadCSS(path);
    fromFile.apply(child);
    auto resolved = child.computedStyle();
    assert(resolved.border_radius == 5 && resolved.padding_left == 4 &&
        resolved.padding_bottom == 3);
    assert(resolved.has_text_color && resolved.text_color.g == 0xbb);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    root.draw();
    SDL_RenderPresent(renderer);
    assert(SDL_ReadSurfacePixel(surface, 8, 6, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.r != 255 && pixel.g != 255); // rounded corner exposes the parent
    assert(SDL_ReadSurfacePixel(surface, 20, 6, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.g == 255); // border shorthand reaches rendering
    assert(SDL_ReadSurfacePixel(surface, 20, 20, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.r == 255 && pixel.g == 0);

    bool rejected;
    try { StyleSheet.parse("Widget { unsupported: 1; }"); }
    catch (CSSException) { rejected = true; }
    assert(rejected);

    auto controls = StyleSheet.parse(`
        Slider { track-color: #00ff00; thumb-color: #0000ff; }
        ProgressBar { fill-color: #ff0000; }
    `);
    auto slider = new Slider(SDL_FRect(10, 10, 40, 10), renderer, 0, 1, 0.5);
    auto progress = new ProgressBar(SDL_FRect(10, 30, 40, 8), renderer, 0.5);
    controls.apply(slider);
    controls.apply(progress);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    slider.draw();
    progress.draw();
    SDL_RenderPresent(renderer);
    assert(SDL_ReadSurfacePixel(surface, 12, 15, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.g == 255);
    assert(SDL_ReadSurfacePixel(surface, 28, 12, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.b == 255);
    assert(SDL_ReadSurfacePixel(surface, 15, 32, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.r == 255);

    auto livePath = "test-output/style-live.css";
    write(livePath, "Widget { background: #112233; }");
    scope(exit) if (exists(livePath)) remove(livePath);
    auto liveWidget = new Widget(SDL_FRect(0, 0, 10, 10), renderer);
    auto watcher = new StyleSheetWatcher(livePath, liveWidget, 0);
    assert(watcher.sheet !is null && watcher.revision == 1);
    assert(liveWidget.computedStyle().background_color.r == 0x11);
    assert(!watcher.poll() && watcher.revision == 1);
    write(livePath, "Widget { background: #445566; }");
    assert(watcher.poll() && watcher.revision == 2);
    assert(liveWidget.computedStyle().background_color.r == 0x44);
    write(livePath, "Widget { background: broken; }");
    assert(!watcher.poll() && watcher.lastError.length);
    assert(watcher.revision == 2 &&
        liveWidget.computedStyle().background_color.r == 0x44);
    write(livePath, "Widget { background: #778899; }");
    assert(watcher.poll() && watcher.lastError.length == 0);
    assert(liveWidget.computedStyle().background_color.r == 0x77);

    auto liveBox = new Box(SDL_FRect(0, 0, 40, 40), renderer, 3,
        Container.Orientation.Vertical);
    auto liveChild = new Widget(SDL_FRect(0, 0, 10, 10), renderer);
    liveBox.addChild(liveChild);
    watcher.addRoot(liveBox);
    write(livePath, "Widget { background: #778899; } " ~
        "Box { gap: 6px; padding: 4px; }");
    assert(watcher.poll());
    assert(liveBox.spacing == 6 && liveChild.rect.x == 10);
    write(livePath, "Widget { background: #778899; }");
    assert(watcher.poll());
    assert(liveBox.spacing == 3 && liveChild.rect.x == 3);
    remove(livePath);
    assert(!watcher.poll() && watcher.lastError.length);
    assert(liveWidget.computedStyle().background_color.r == 0x77);
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(SDL_Init(0));
    scope(exit) SDL_Quit();
    assert(loadSDLTTF() == LoadMsg.success);
    assert(TTF_Init());
    scope(exit) TTF_Quit();
    auto surface = SDL_CreateSurface(80, 40, SDL_PIXELFORMAT_RGBA32);
    assert(surface !is null);
    scope(exit) SDL_DestroySurface(surface);
    auto renderer = SDL_CreateSoftwareRenderer(surface);
    assert(renderer !is null);
    scope(exit) SDL_DestroyRenderer(renderer);
    auto font = TTF_OpenFont("liberation-sans.ttf", 14);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);

    auto label = new Label(SDL_FRect(0, 0, 50, 20), renderer, font, "Text");
    scope(exit) destroy(label);
    auto button = new Button(SDL_FRect(0, 20, 50, 20), renderer, font, "Go");
    scope(exit) destroy(button);
    auto sheet = StyleSheet.parse(`
        Label { color: #123; padding: 3px 5px; }
        Button { background-color: #f00; }
        Button:hover { background-color: #0f0; }
        Button:pressed { background-color: #00f; }
    `);
    sheet.apply(label);
    sheet.apply(button);
    label.text_placement = Label.TextPlacement.Start;
    assert(label.text_x == 5 && label.text_y == 3);
    assert(label.effectiveTextColor().r == 0x11);
    assert(label.effectiveTextColor().b == 0x33);
    assert(button.effectiveTextColor().r == 0x11); // Label rules reach subclasses
    button.hovered = true;
    assert(button.computedStyle().background_color.g == 255);
    button.pressed = true;
    assert(button.computedStyle().background_color.b == 255);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    button.draw();
    SDL_RenderPresent(renderer);
    SDL_Color pixel;
    assert(SDL_ReadSurfacePixel(surface, 2, 22, &pixel.r, &pixel.g, &pixel.b, &pixel.a));
    assert(pixel.b == 255);

    auto check = new CheckBox(SDL_FRect(0, 0, 50, 20), renderer, font, "Check", true);
    scope(exit) destroy(check);
    auto item = new ListItem(SDL_FRect(0, 0, 50, 20), renderer, font, "Item");
    scope(exit) destroy(item);
    item.selected = true;
    auto states = StyleSheet.parse(`
        CheckBox:checked { background-color: #0f0; }
        ListItem:selected { selection-color: #f0f; }
    `);
    states.apply(check);
    states.apply(item);
    assert(check.computedStyle().background_color.g == 255);
    assert(item.computedStyle().selection_color.b == 255);
    check.draw();
    assert(check.text_x >= check.rect.x + 18);
    auto radio = new RadioButton(SDL_FRect(0, 0, 50, 20), renderer, font, "Radio");
    scope(exit) destroy(radio);
    sheet.apply(radio);
    radio.draw();
    assert(radio.text_x >= radio.rect.x + 18);
}
