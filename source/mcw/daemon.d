module mcw.daemon;

import std.algorithm : min;
import std.string : split, strip, toStringz;

import bindbc.sdl;

import mcw.apps.bar : BarWindow;
import mcw.apps.launcher : Launcher;
import mcw.ipc : IpcServer;
import mcw.window : Window;
import mcw.window_factory : knownWindow, makeWindow, positionBar, windowFontSize;

class Daemon {
    private Window[string] windows;
    private TTF_Font*[string] fonts;
    private bool[string] visible;
    private ulong[string] nextIdle;
    private IpcServer server;
    private bool stopping;

    void run() {
        server = new IpcServer();
        server.start();
        show("bar");
        while (!stopping) {
            SDL_Event event;
            int timeout = waitTimeout();
            bool received = timeout < 0 ? SDL_WaitEvent(&event) :
                SDL_WaitEventTimeout(&event, timeout);
            if (received) {
                do {
                    if (event.type != SDL_EVENT_POLL_SENTINEL)
                        handleEvent(&event);
                } while (!stopping && SDL_PollEvent(&event));
            } else if (timeout < 0) {
                throw new Exception("Could not wait for SDL events");
            }
            runIdle();
        }
    }

    void close() {
        if (server !is null) server.stop();
        foreach (window; windows) destroy(window);
        windows.clear();
        foreach (font; fonts) TTF_CloseFont(font);
        fonts.clear();
    }

    private Window getWindow(string name) {
        if (auto existing = name in windows) return *existing;
        auto font = TTF_OpenFont("liberation-sans.ttf".toStringz,
                windowFontSize(name));
        if (font is null) throw new Exception("Could not load font");
        Window window;
        try window = makeWindow(name, font);
        catch (Exception e) {
            TTF_CloseFont(font);
            throw e;
        }
        fonts[name] = font;
        windows[name] = window;
        if (name == "launcher" || name == "dialog" || name == "showcase")
            SDL_StopTextInput(window.window);
        return window;
    }

    private void show(string name) {
        auto window = getWindow(name);
        if (name == "launcher") (cast(Launcher) window).prepareShow();
        else if (name == "dialog" || name == "showcase")
            SDL_StartTextInput(window.window);
        window.quit = false;
        if (!SDL_ShowWindow(window.window))
            throw new Exception("Could not show " ~ name);
        if (name == "bar") positionBar(window);
        SDL_RaiseWindow(window.window);
        visible[name] = true;
        window.draw();
    }

    private void hide(string name) {
        auto found = name in windows;
        if (found is null) return;
        auto window = *found;
        if (name == "bar") (cast(BarWindow) window).hidePopups();
        if (name == "launcher" || name == "dialog" || name == "showcase")
            SDL_StopTextInput(window.window);
        SDL_HideWindow(window.window);
        window.quit = false;
        visible[name] = false;
    }

    private string command(string line) {
        auto words = line.strip().split();
        if (!words.length) return "ERR empty command";
        if (words[0] != "v1") return "ERR unsupported protocol";
        words = words[1 .. $];
        if (!words.length) return "ERR empty command";
        if (words[0] == "status" && words.length == 1) {
            string result = "OK";
            foreach (name; ["bar", "launcher", "dialog", "showcase", "test", "test_list"])
                result ~= " " ~ name ~ "=" ~ (visible.get(name, false) ? "visible" : "hidden");
            return result;
        }
        if (words[0] == "stop" && words.length == 1) {
            stopping = true;
            return "OK stopping";
        }
        if (words.length != 2 || !knownWindow(words[1]))
            return "ERR expected show|hide|toggle <window>";
        auto name = words[1];
        try {
            switch (words[0]) {
            case "show": show(name); break;
            case "hide": hide(name); break;
            case "toggle":
                if (visible.get(name, false)) hide(name);
                else show(name);
                break;
            default: return "ERR unknown command";
            }
        } catch (Exception e) {
            return "ERR " ~ e.msg;
        }
        return "OK " ~ name ~ "=" ~ (visible.get(name, false) ? "visible" : "hidden");
    }

    private uint windowId(SDL_Event *event) {
        if (event.type >= SDL_EVENT_WINDOW_FIRST && event.type <= SDL_EVENT_WINDOW_LAST)
            return event.window.windowID;
        switch (event.type) {
        case SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
            return event.key.windowID;
        case SDL_EVENT_TEXT_INPUT:
            return event.text.windowID;
        case SDL_EVENT_TEXT_EDITING:
            return event.edit.windowID;
        case SDL_EVENT_MOUSE_MOTION:
            return event.motion.windowID;
        case SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
            return event.button.windowID;
        case SDL_EVENT_MOUSE_WHEEL:
            return event.wheel.windowID;
        default:
            return 0;
        }
    }

    private void handleEvent(SDL_Event *event) {
        if (event.type == SDL_EVENT_QUIT) { stopping = true; return; }
        if (event.type == server.eventType) {
            for (auto request = server.take(); request !is null; request = server.take())
                server.complete(request, command(request.command));
            return;
        }
        uint id = windowId(event);
        if (id == 0) return;
        foreach (name, window; windows) {
            bool owns = name == "bar" ? (cast(BarWindow) window).ownsWindow(id) :
                SDL_GetWindowID(window.window) == id;
            if (!owns || !visible.get(name, false)) continue;
            if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED &&
                    id == SDL_GetWindowID(window.window)) {
                hide(name);
                return;
            }
            window.handleEvent(event);
            if (window.quit) hide(name);
            else if (visible[name]) window.draw();
            return;
        }
    }

    private int waitTimeout() {
        auto now = SDL_GetTicks();
        int timeout = -1;
        foreach (name, window; windows) {
            if (!visible.get(name, false) && name != "bar") continue;
            int period = window.idleTimeoutMs();
            if (period < 0) continue;
            auto deadline = name in nextIdle;
            ulong latest = now + cast(ulong) period;
            if (deadline is null || *deadline > latest) nextIdle[name] = latest;
            int remaining = nextIdle[name] <= now ? 0 :
                cast(int) min(nextIdle[name] - now, cast(ulong) int.max);
            timeout = timeout < 0 ? remaining : min(timeout, remaining);
        }
        return timeout;
    }

    private void runIdle() {
        auto now = SDL_GetTicks();
        foreach (name, window; windows) {
            if (!visible.get(name, false) && name != "bar") continue;
            auto deadline = name in nextIdle;
            if (deadline is null || *deadline > now) continue;
            bool changed = window.onIdle();
            int period = window.idleTimeoutMs();
            if (period >= 0) nextIdle[name] = SDL_GetTicks() + cast(ulong) period;
            else nextIdle.remove(name);
            if (changed && visible.get(name, false)) window.draw();
        }
    }
}
