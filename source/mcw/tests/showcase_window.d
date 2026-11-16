module mcw.tests.showcase_window;

import std.file : mkdirRecurse, write, remove, exists;
import std.path : buildPath;
import std.string : toStringz, startsWith;

import bindbc.sdl;
import bindbc.loader : LoadMsg;

import mcw.apps.showcase;
import mcw.widgets.label : Label;
import mcw.widgets.navigation : MenuItem;

private SDL_Event click(uint type, float x, float y) {
    SDL_Event event = SDL_Event();
    event.type = type;
    event.button.x = x;
    event.button.y = y;
    return event;
}

private SDL_Event motion(float x, float y) {
    SDL_Event event = SDL_Event();
    event.type = SDL_EVENT_MOUSE_MOTION;
    event.motion.x = x;
    event.motion.y = y;
    return event;
}

private void savePage(WidgetShowcaseWindow window, string name) {
    SDL_SetRenderDrawColor(window.renderer, 0, 0, 0, 255);
    SDL_RenderClear(window.renderer);
    window.tabs.draw();
    auto surface = SDL_RenderReadPixels(window.renderer, null);
    assert(surface !is null);
    auto path = buildPath("test-output", name ~ ".bmp");
    assert(SDL_SaveBMP(surface, path.toStringz));
    SDL_DestroySurface(surface);
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(loadSDLTTF() == LoadMsg.success);
    SDL_setenv_unsafe("SDL_VIDEODRIVER".toStringz, "dummy".toStringz, 1);
    SDL_setenv_unsafe("SDL_RENDER_DRIVER".toStringz, "software".toStringz, 1);
    assert(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS));
    scope(exit) SDL_Quit();
    assert(TTF_Init());
    scope(exit) TTF_Quit();
    auto font = TTF_OpenFont("liberation-sans.ttf", 17);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);

    auto window = new WidgetShowcaseWindow(SDL_FRect(0, 0, 1100, 760),
            "Widget showcase test", font);
    scope(exit) destroy(window);
    assert(window.tabs.titles.length == 6);
    assert(window.themeWatcher !is null && window.themeWatcher.sheet !is null);
    assert(window.idleTimeoutMs() == 250);
    assert(!window.onIdle());
    assert(window.themeIndex == 0);
    assert(window.listScroll !is null);
    assert(window.listChoices !is null && window.listIcons !is null);
    foreach (item; window.listChoices.children)
        assert((cast(Label) item).text_placement == Label.TextPlacement.Center);
    foreach (name; window.listIcons.labels) {
        assert(name.rect.w >= name.text_width);
        assert(name.rect.h >= name.FONT_HEIGHT);
    }
    assert(window.demoMenu !is null);

    mkdirRecurse("test-output");
    foreach (page; 0 .. 6) {
        window.tabs.select(page);
        savePage(window, "showcase-" ~ ["basics", "controls",
                "lists", "layout", "menus", "themes"][page]);
        auto surface = SDL_RenderReadPixels(window.renderer, null);
        assert(surface !is null);
        ubyte r, g, b, a;
        assert(SDL_ReadSurfacePixel(surface, 10, 10, &r, &g, &b, &a));
        assert(r > 0 || g > 0 || b > 0);
        SDL_DestroySurface(surface);
    }

    window.tabs.select(1);
    window.controlsInput.focused = true;
    window.controlsInput.setValue("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
    assert(window.controlsInput.scrollX > 0);
    assert(window.status[1].text.length > 70);
    savePage(window, "showcase-controls-long-text");
    auto longTextSurface = SDL_RenderReadPixels(window.renderer, null);
    assert(longTextSurface !is null);
    ubyte longR, longG, longB, longA;
    assert(SDL_ReadSurfacePixel(longTextSurface, 750, 708,
            &longR, &longG, &longB, &longA));
    assert(longR == 23 && longG == 27 && longB == 39);
    assert(SDL_ReadSurfacePixel(longTextSurface, 425, 205,
            &longR, &longG, &longB, &longA));
    assert(longR == 23 && longG == 27 && longB == 39);
    SDL_DestroySurface(longTextSurface);

    window.tabs.select(0);
    auto move = motion(100, 552);
    window.handleEvent(&move);
    assert(window.basicsTooltip.shown);
    savePage(window, "showcase-tooltip-hover");
    auto hoverSurface = SDL_RenderReadPixels(window.renderer, null);
    assert(hoverSurface !is null);
    ubyte r, g, b, a;
    assert(SDL_ReadSurfacePixel(hoverSurface, 350, 586, &r, &g, &b, &a));
    assert(r == 68 && g == 73 && b == 110);
    SDL_DestroySurface(hoverSurface);
    auto down = click(SDL_EVENT_MOUSE_BUTTON_DOWN, 50, 552);
    auto up = click(SDL_EVENT_MOUSE_BUTTON_UP, 50, 552);
    window.handleEvent(&down);
    window.handleEvent(&up);
    assert(window.status[0].text == "Button activated by mouse or keyboard.");
    assert(window.hoverButton.focused && !window.hoverButton.focusVisible);
    move = motion(610, 552);
    window.handleEvent(&move);
    assert(!window.basicsTooltip.shown);
    savePage(window, "showcase-tooltip-after-click");
    auto afterSurface = SDL_RenderReadPixels(window.renderer, null);
    assert(afterSurface !is null);
    assert(SDL_ReadSurfacePixel(afterSurface, 350, 586, &r, &g, &b, &a));
    assert(r == 23 && g == 27 && b == 39);
    SDL_DestroySurface(afterSurface);

    window.tabs.select(2);
    SDL_Event wheel = SDL_Event();
    wheel.type = SDL_EVENT_MOUSE_WHEEL;
    wheel.wheel.mouseX = 690;
    wheel.wheel.mouseY = 205;
    wheel.wheel.y = -1;
    window.handleEvent(&wheel);
    assert(window.listScroll.scrollY > 0);

    window.tabs.select(4);
    down = click(SDL_EVENT_MOUSE_BUTTON_DOWN, 70, 176);
    up = click(SDL_EVENT_MOUSE_BUTTON_UP, 70, 176);
    window.handleEvent(&down);
    window.handleEvent(&up);
    assert(window.demoMenu.open);
    savePage(window, "showcase-menu-open");
    up = click(SDL_EVENT_MOUSE_BUTTON_UP, 70, 220);
    window.handleEvent(&up);
    assert(!window.demoMenu.open);
    assert(window.status[4].text == "Action one / Ctrl+1 activated.");

    down = click(SDL_EVENT_MOUSE_BUTTON_DOWN, 70, 176);
    up = click(SDL_EVENT_MOUSE_BUTTON_UP, 70, 176);
    window.handleEvent(&down);
    window.handleEvent(&up);
    up = click(SDL_EVENT_MOUSE_BUTTON_UP, 70, 255);
    window.handleEvent(&up);
    assert(window.demoMenu.open);
    savePage(window, "showcase-submenu-open");
    down = click(SDL_EVENT_MOUSE_BUTTON_DOWN, 70, 176);
    up = click(SDL_EVENT_MOUSE_BUTTON_UP, 70, 176);
    window.handleEvent(&down);
    window.handleEvent(&up);
    assert(!window.demoMenu.open);
    auto more = cast(MenuItem) window.demoMenu.children[1];
    assert(!more.submenu.open);

    auto previousX = window.resizeAnchor.rect.x;
    auto previousY = window.resizeAnchor.rect.y;
    SDL_Event resize = SDL_Event();
    resize.type = SDL_EVENT_WINDOW_RESIZED;
    resize.window.data1 = 1200;
    resize.window.data2 = 810;
    window.handleEvent(&resize);
    assert(window.resizeAnchor.rect.x == previousX + 100);
    assert(window.resizeAnchor.rect.y == previousY + 50);

    window.tabs.select(5);
    down = click(SDL_EVENT_MOUSE_BUTTON_DOWN, 400, 220);
    up = click(SDL_EVENT_MOUSE_BUTTON_UP, 400, 220);
    window.handleEvent(&down);
    window.handleEvent(&up);
    assert(window.themeIndex == 1);
    SDL_Color[4] backgrounds = [
        SDL_Color(23, 27, 39, 255), SDL_Color(245, 242, 234, 255),
        SDL_Color(16, 40, 32, 255), SDL_Color(38, 29, 52, 255)
    ];
    foreach (i; 0 .. 4) {
        assert(window.selectTheme(i));
        assert(window.themeIndex == i);
        assert(window.themeButtons[i].styleClasses.length == 2);
        savePage(window, "showcase-theme-" ~ ["midnight", "daylight",
            "forest", "sunset"][i]);
        auto themed = SDL_RenderReadPixels(window.renderer, null);
        assert(themed !is null);
        assert(SDL_ReadSurfacePixel(themed, 800, 520, &r, &g, &b, &a));
        assert(r == backgrounds[i].r && g == backgrounds[i].g &&
            b == backgrounds[i].b);
        SDL_DestroySurface(themed);
    }
    assert(window.selectTheme(1));
    window.tabs.select(1);
    savePage(window, "showcase-daylight-controls");
    window.tabs.select(5);
    SDL_Event shortcut = SDL_Event();
    shortcut.type = SDL_EVENT_KEY_DOWN;
    shortcut.key.key = SDLK_F3;
    window.handleEvent(&shortcut);
    assert(window.themeIndex == 2);

    auto livePath = "test-output/showcase-live.css";
    write(livePath, "Canvas.panel { background: #123456; }");
    scope(exit) if (exists(livePath)) remove(livePath);
    window.themeWatcher.path = livePath;
    window.themeWatcher.intervalMs = 0;
    shortcut.key.key = SDLK_F5;
    window.draw();
    assert(window.themeWatcher.revision == 2);
    assert(window.status[5].text.startsWith("Reloaded"));
    savePage(window, "showcase-hot-reload");
    auto liveSurface = SDL_RenderReadPixels(window.renderer, null);
    assert(liveSurface !is null);
    assert(SDL_ReadSurfacePixel(liveSurface, 800, 520, &r, &g, &b, &a));
    assert(r == 0x12 && g == 0x34 && b == 0x56);
    SDL_DestroySurface(liveSurface);
    write(livePath, "Canvas.panel { background: invalid; }");
    window.draw();
    assert(window.status[5].text.startsWith("CSS error"));
    assert(window.tabs.children[5].computedStyle().background_color.r == 0x12);
    write(livePath, "Canvas.panel { background: #123456; }");
    window.draw();
    assert(window.themeWatcher.lastError.length == 0);
    assert(window.status[5].text.startsWith("Active"));
    write(livePath, "Canvas.panel { background: #654321; }");
    window.handleEvent(&shortcut);
    assert(window.themeWatcher.revision == 3);
    assert(window.status[5].text.startsWith("Reloaded"));
    assert(window.selectTheme(0));
}
