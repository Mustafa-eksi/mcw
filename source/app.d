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
import mcw.daemon;
import mcw.ipc : sendCommand;
import mcw.util;
import mcw.window_factory : knownWindow, makeWindow, positionBar, windowFontSize;

const uint TEXT_FONT_SIZE = 32;
const uint WINDOW_HORIZONTAL_PADDING = 10;
const uint WINDOW_VERTICAL_PADDING = 10;
const uint PROMPT_BOTTOM_MARGIN = 20;

private int runDaemon() {
    if (mcwInitAll() != 0) return -1;
    scope(exit) mcwQuitAll();
    // A window close only hides that window in daemon mode. Keep SDL from
    // turning the last close request into a process-wide quit event.
    if (!SDL_SetHintWithPriority(SDL_HINT_QUIT_ON_LAST_WINDOW_CLOSE, "0",
            SDL_HINT_OVERRIDE)) {
        writeln("Could not configure daemon window close behavior: ", SDL_GetError());
        return -1;
    }
    auto daemon = new Daemon();
    scope(exit) {
        daemon.close();
        destroy(daemon);
    }
    try daemon.run();
    catch (Exception e) {
        writeln("Daemon error: ", e.msg);
        return -1;
    }
    return 0;
}

int main(string[] args) {
    if (args.length < 2) {
        writeln("Usage: mcw <daemon|show|hide|toggle|status|stop|launcher|bar|dialog|showcase|test|test_list>");
        return -1;
    }

    if (args[1] == "show" || args[1] == "hide" || args[1] == "toggle" ||
            args[1] == "status" || args[1] == "stop") {
        if ((args[1] == "status" || args[1] == "stop") ? args.length != 2 :
                args.length != 3 || !knownWindow(args[2])) {
            writeln("Invalid IPC command");
            return -1;
        }
        try {
            auto response = sendCommand(args[1 .. $].join(" "));
            writeln(response);
            return response.startsWith("OK") ? 0 : -1;
        } catch (Exception e) {
            writeln("Could not contact MCW daemon: ", e.msg);
            return -1;
        }
    }

    // Wayland does not allow ordinary windows to select an absolute position.
    // Use XWayland for the bar when it is available and no driver was chosen.
    if ((args[1] == "bar" || args[1] == "daemon") &&
            environment.get("XDG_SESSION_TYPE", "") == "wayland" &&
            environment.get("DISPLAY", "").length &&
            !environment.get("SDL_VIDEO_DRIVER", "").length &&
            !environment.get("SDL_VIDEODRIVER", "").length)
        environment["SDL_VIDEO_DRIVER"] = "x11,wayland";

    if (args[1] == "daemon") return runDaemon();

    if (mcwInitAll() != 0) {
        return -1;
    }
    scope(exit) mcwQuitAll();

    string current_window = args[1];
    if (!knownWindow(current_window)) {
        writeln("Invalid window name: ", current_window);
        return -1;
    }
    TTF_Font *font = TTF_OpenFont("liberation-sans.ttf",
            windowFontSize(current_window));
    if (font is null) {
        writeln("Could not open liberation-sans.ttf: ", SDL_GetError());
        return -1;
    }
    scope(exit) TTF_CloseFont(font);

    Window current = makeWindow(current_window, font);
    scope(exit) destroy(current);

    SDL_ShowWindow(current.window);
    if (current_window == "bar") positionBar(current);
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
