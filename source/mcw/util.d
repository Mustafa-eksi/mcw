module mcw.util;

import bindbc.sdl;
import bindbc.loader;
import std.stdio : writeln;

int mcwInitAll() {
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

    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        writeln(SDL_GetError());
        return -1;
    }
    return 0;
}

void mcwQuitAll() {
    TTF_Quit();
    SDL_Quit();
}
