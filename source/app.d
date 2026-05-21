import std.stdio;
import std.string;
import std.uni;
import std.process;
import std.range;
import std.algorithm;

import bindbc.sdl;
import bindbc.loader;

import desktop;
import window;
import widget;
import widgets;
import launcher;

const uint TEXT_FONT_SIZE = 32;
const uint WINDOW_HORIZONTAL_PADDING = 10;
const uint WINDOW_VERTICAL_PADDING = 10;
const uint PROMPT_BOTTOM_MARGIN = 20;

int main() {
    LoadMsg ret = loadSDL();
    if(ret != LoadMsg.success) {
      writeln("Error loading SDL dll");
      return -4;
    }

    ret = loadSDLTTF();
    if(ret != LoadMsg.success) {
      writeln("Error loading SDL_ttf dll");
      return -5;
    }

    ret = loadSDLImage();
    if(ret != LoadMsg.success) {
      writeln("Error loading SDL_image dll");
      return -6;
    }

    // TTF initializing and font loading
    if (!TTF_Init()) {
        writeln("TTF init failed");
        return -1;
    }
    scope(exit) TTF_Quit();

    TTF_Font *font = TTF_OpenFont("liberation-sans.ttf", TEXT_FONT_SIZE);
    const int FONT_HEIGHT = TTF_GetFontHeight(font);
    uint WINDOW_HEIGHT = cast(uint)(FONT_HEIGHT*1.5);
    const uint WINDOW_WIDTH = 500;

    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        writeln(SDL_GetError());
        return -1;
    }
    scope(exit) SDL_Quit();

    Launcher launcher_window = new Launcher(SDL_FRect(0, 0, 500, 100), "mcw",
            font);

    while (!launcher_window.quit) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            launcher_window.handleEvent(&event);
        }
        launcher_window.draw();
    }

    return 0;
}
