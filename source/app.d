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
    if (args.length < 2)
        return -1;

    if (mcwInitAll() != 0) {
        return -1;
    }
    scope(exit) mcwQuitAll();

    TTF_Font *font = TTF_OpenFont("liberation-sans.ttf", TEXT_FONT_SIZE);

    Window[string] windows;
    windows["launcher"] = cast(Window)new Launcher(SDL_FRect(0, 0, 500, 100), "mcw", font);
    windows["test"] = cast(Window)new LayoutTestWindow(SDL_FRect(0, 0, 800, 600), "test", font);
    windows["test_list"] = cast(Window)new ListTestWindow(SDL_FRect(0, 0, 800, 600), "test_list", font);
    string current_window = args[1];
    if (current_window !in windows) {
        writeln("Invalid window name: ", current_window);
        return -1;
    }

    SDL_ShowWindow(windows[current_window].window);

    while (!windows[current_window].quit) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            windows[current_window].handleEvent(&event);
        }
        windows[current_window].draw();
    }

    return 0;
}
