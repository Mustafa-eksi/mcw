module mcw.tests.bar_window;

import std.file : mkdirRecurse;
import std.path : buildPath;
import std.string : toStringz;

import bindbc.sdl;
import bindbc.loader : LoadMsg;
import mcw.apps.bar;

private SDL_Event mouse(uint type, uint windowId, float x, float y) {
    SDL_Event event = SDL_Event();
    event.type = type;
    event.button.windowID = windowId;
    event.button.button = SDL_BUTTON_LEFT;
    event.button.x = x;
    event.button.y = y;
    return event;
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(loadSDLTTF() == LoadMsg.success);
    assert(loadSDLImage() == LoadMsg.success);
    SDL_setenv_unsafe("SDL_VIDEODRIVER".toStringz, "dummy".toStringz, 1);
    SDL_setenv_unsafe("SDL_RENDER_DRIVER".toStringz, "software".toStringz, 1);
    assert(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS));
    scope(exit) SDL_Quit();
    assert(TTF_Init());
    scope(exit) TTF_Quit();
    auto font = TTF_OpenFont("liberation-sans.ttf", 15);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);

    auto bar = new BarWindow(SDL_FRect(0, 0, 1280, 44), "Bar test", font);
    scope(exit) destroy(bar);
    assert(bar.desktops.length == 8);
    assert(bar.trayButtons.length == 6);
    assert(bar.seekSlider.rect.w > 0);
    assert(bar.seekSlider.renderer == bar.mediaWindow.renderer);
    assert(bar.timeLabel.renderer == bar.mediaWindow.renderer);
    assert(bar.previous.renderer == bar.mediaWindow.renderer);
    assert(bar.mediaPanel.rect.w == 340 && bar.mediaPanel.rect.h == 360);
    assert(bar.bigArtwork.rect.w == 240 && bar.bigArtwork.rect.h == 240);
    assert(bar.bigArtwork.rect.y + bar.bigArtwork.rect.h < bar.seekSlider.rect.y);
    assert(bar.seekSlider.rect.y < bar.previous.rect.y);
    assert(bar.artwork.rect.x + bar.artwork.rect.w <= bar.trackLabel.rect.x);
    assert(bar.artwork.rect.x > bar.clockLabel.rect.x + bar.clockLabel.rect.w);
    assert(bar.compactPlay.rect.x + bar.compactPlay.rect.w < bar.controlButton.rect.x);
    assert(bar.clockLabel.rect.x + bar.clockLabel.rect.w / 2 == 640);
    assert(bar.controlButton.text.length == 0);
    assert(bar.compactPlay.text.length == 0);
    assert(bar.previous.text.length == 0);
    assert(bar.controlButton.style.border_radius == 7);
    assert(bar.mediaPanel.style.border_radius == 12);

    // A changing tray count must not leave fixed blank slots before Settings.
    bar.trayItems.length = 2;
    SDL_Event resized = SDL_Event();
    resized.type = SDL_EVENT_WINDOW_RESIZED;
    resized.window.windowID = SDL_GetWindowID(bar.window);
    resized.window.data1 = 1280;
    resized.window.data2 = 44;
    bar.handleEvent(&resized);
    assert(bar.compactPlay.rect.x + bar.compactPlay.rect.w <
        bar.trayButtons[0].rect.x);
    assert(bar.trayButtons[1].rect.x + bar.trayButtons[1].rect.w ==
        bar.controlButton.rect.x - 5);
    bar.trayItems.length = 0;
    bar.handleEvent(&resized);

    bar.draw();
    auto surface = SDL_RenderReadPixels(bar.renderer, null);
    assert(surface !is null);
    ubyte r, g, b, a;
    assert(SDL_ReadSurfacePixel(surface, 315, 20, &r, &g, &b, &a));
    assert(r == 22 && g == 27 && b == 37);
    mkdirRecurse("test-output");
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar.bmp").toStringz));
    SDL_DestroySurface(surface);

    auto barId = SDL_GetWindowID(bar.window);
    auto down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId,
        bar.artwork.rect.x + 18, 20);
    auto up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId,
        bar.artwork.rect.x + 18, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.mediaOpen);
    bar.mediaWindow.draw();
    surface = SDL_RenderReadPixels(bar.mediaWindow.renderer, null);
    assert(surface !is null);
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar-media.bmp").toStringz));
    SDL_DestroySurface(surface);
    SDL_Event escape = SDL_Event();
    escape.type = SDL_EVENT_KEY_DOWN;
    escape.key.key = SDLK_ESCAPE;
    escape.key.windowID = SDL_GetWindowID(bar.mediaWindow.window);
    bar.handleEvent(&escape);
    assert(!bar.mediaOpen && !bar.quit);

    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId,
        bar.controlButton.rect.x + 16, 20);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId,
        bar.controlButton.rect.x + 16, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.controlsOpen);

    auto panelId = SDL_GetWindowID(bar.controlWindow.window);
    SDL_Event motion = SDL_Event();
    motion.type = SDL_EVENT_MOUSE_MOTION;
    motion.motion.windowID = panelId;
    motion.motion.x = 50;
    motion.motion.y = 150;
    bar.handleEvent(&motion);
    assert(bar.profileLabel.text == "Power save");
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 297, 152);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 297, 152);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.powerOpen);
    foreach (button; bar.powerActions) assert(button.visible);
    assert(bar.controls.rect.h == 260);
    bar.controlWindow.draw();
    surface = SDL_RenderReadPixels(bar.controlWindow.renderer, null);
    assert(surface !is null);
    assert(SDL_ReadSurfacePixel(surface, 264, 133, &r, &g, &b, &a));
    assert(r == 31 && g == 38 && b == 52);
    assert(SDL_ReadSurfacePixel(surface, 270, 140, &r, &g, &b, &a));
    assert(r == 43 && g == 54 && b == 70);
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar-controls.bmp").toStringz));
    SDL_DestroySurface(surface);

    escape.key.windowID = panelId;
    bar.handleEvent(&escape);
    assert(!bar.controlsOpen && !bar.quit);
    escape.key.windowID = barId;
    bar.handleEvent(&escape);
    assert(!bar.quit);
}
