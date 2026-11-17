import std.stdio;
import std.string;
import std.uni;
import std.process;
import std.range;
import std.algorithm;

import bindbc.sdl;
import bindbc.loader;

import mcw.window;
import mcw.widgets;
import mcw.apps;
import mcw.util;

const uint TEXT_FONT_SIZE = 32;
const uint WINDOW_HORIZONTAL_PADDING = 10;
const uint WINDOW_VERTICAL_PADDING = 10;
const uint PROMPT_BOTTOM_MARGIN = 20;

int main(string[] args) {
    if (args.length < 2) {
        writeln("Usage: mcw <launcher|test|test_list|dialog|showcase|bar>");
        return -1;
    }

    // Wayland does not allow ordinary windows to select an absolute position.
    // Use XWayland for the bar when it is available and no driver was chosen.
    if (args[1] == "bar" && environment.get("XDG_SESSION_TYPE", "") == "wayland" &&
            environment.get("DISPLAY", "").length &&
            !environment.get("SDL_VIDEO_DRIVER", "").length &&
            !environment.get("SDL_VIDEODRIVER", "").length)
        environment["SDL_VIDEO_DRIVER"] = "x11,wayland";

    if (mcwInitAll() != 0) {
        return -1;
    }
    scope(exit) mcwQuitAll();

    string current_window = args[1];
    if (current_window != "launcher" && current_window != "test" &&
            current_window != "test_list" && current_window != "dialog" &&
            current_window != "showcase" && current_window != "bar") {
        writeln("Invalid window name: ", current_window);
        return -1;
    }
    TTF_Font *font = TTF_OpenFont("liberation-sans.ttf",
            current_window == "showcase" ? 17 :
            current_window == "bar" ? 15 : TEXT_FONT_SIZE);
    if (font is null) {
        writeln("Could not open liberation-sans.ttf: ", SDL_GetError());
        return -1;
    }
    scope(exit) TTF_CloseFont(font);

    Window current;
    switch (current_window) {
    case "launcher":
        current = new Launcher(SDL_FRect(0, 0, 500, 100), "mcw", font);
        break;
    case "test":
        current = new LayoutTestWindow(SDL_FRect(0, 0, 800, 600), "test", font);
        break;
    case "test_list":
        current = new ListTestWindow(SDL_FRect(0, 0, 800, 600), "test_list", font);
        break;
    case "dialog":
        current = new DialogExampleWindow(SDL_FRect(0, 0, 600, 260), "dialog", font);
        break;
    case "showcase":
        current = new WidgetShowcaseWindow(SDL_FRect(0, 0, 1100, 760),
                "MCW widget showcase", font);
        break;
    case "bar":
        SDL_Rect displayBounds;
        if (!SDL_GetDisplayBounds(SDL_GetPrimaryDisplay(), &displayBounds))
            displayBounds = SDL_Rect(0, 0, 1280, 720);
        current = new BarWindow(SDL_FRect(0, 0, displayBounds.w, 44),
                "MCW bar", font);
        SDL_SetWindowPosition(current.window, displayBounds.x, displayBounds.y);
        break;
    default: assert(false);
    }
    scope(exit) destroy(current);

    SDL_ShowWindow(current.window);
    if (current_window == "bar") {
        SDL_Rect displayBounds;
        if (SDL_GetDisplayBounds(SDL_GetPrimaryDisplay(), &displayBounds))
            SDL_SetWindowPosition(current.window, displayBounds.x, displayBounds.y);
    }
    current.draw();

    while (!current.quit) {
        SDL_Event event;
        int timeout = current.idleTimeoutMs();
        bool received = timeout < 0 ? SDL_WaitEvent(&event) :
            SDL_WaitEventTimeout(&event, timeout);
        bool redraw = false;
        if (received) {
            do {
                if (event.type != SDL_EVENT_POLL_SENTINEL) {
                    current.handleEvent(&event);
                    redraw = true;
                }
            } while (SDL_PollEvent(&event));
        } else if (timeout >= 0) {
            redraw = current.onIdle();
        } else {
            writeln("Could not wait for window events: ", SDL_GetError());
            return -1;
        }
        if (redraw && !current.quit) current.draw();
    }

    return 0;
}
