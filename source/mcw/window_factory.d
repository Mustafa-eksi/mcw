module mcw.window_factory;

import bindbc.sdl;

import mcw.apps;
import mcw.window;

bool knownWindow(string name) {
    return name == "bar" || name == "launcher" || name == "dialog" ||
        name == "showcase" || name == "test" || name == "test_list";
}

int windowFontSize(string name) {
    return name == "bar" ? 15 : name == "launcher" ? 18 :
        name == "showcase" ? 17 : 32;
}

Window makeWindow(string name, TTF_Font *font) {
    switch (name) {
    case "bar":
        SDL_Rect bounds;
        if (!SDL_GetDisplayBounds(SDL_GetPrimaryDisplay(), &bounds))
            bounds = SDL_Rect(0, 0, 1280, 720);
        auto bar = new BarWindow(SDL_FRect(0, 0, bounds.w, 44), "MCW bar", font);
        SDL_SetWindowPosition(bar.window, bounds.x, bounds.y);
        return bar;
    case "launcher":
        return new Launcher(SDL_FRect(0, 0, 560, 380), "MCW launcher", font);
    case "dialog":
        return new DialogExampleWindow(SDL_FRect(0, 0, 600, 260), "dialog", font);
    case "showcase":
        return new WidgetShowcaseWindow(SDL_FRect(0, 0, 1100, 760),
                "MCW widget showcase", font);
    case "test":
        return new LayoutTestWindow(SDL_FRect(0, 0, 800, 600), "test", font);
    case "test_list":
        return new ListTestWindow(SDL_FRect(0, 0, 800, 600), "test_list", font);
    default:
        assert(false);
    }
}

void positionBar(Window window) {
    SDL_Rect bounds;
    if (SDL_GetDisplayBounds(SDL_GetPrimaryDisplay(), &bounds))
        SDL_SetWindowPosition(window.window, bounds.x, bounds.y);
}
