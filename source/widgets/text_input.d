import std.string : toStringz, fromStringz, toLower;

import bindbc.sdl;

import widget;

class TextInput : Widget {
    string prompt;
    // TODO: make these pointers ref counted
    TTF_TextEngine *engine;
    TTF_Text *ttf_text;

    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font) {
        super(rect, renderer);
        prompt = "|";
        engine = TTF_CreateRendererTextEngine(renderer);
        ttf_text = TTF_CreateText(engine, font, prompt.toStringz,
                prompt.length);
    }

    override void draw() {
        TTF_DrawRendererText(ttf_text, rect.x, rect.y);
    }

    override void handleEvent(SDL_Event *event) {
        prompt.length--;
        if (SDLK_A <= event.key.key && SDLK_Z >= event.key.key) {
            if (event.key.mod & SDL_KMOD_SHIFT) {
                prompt ~= SDL_GetKeyName(event.key.key).fromStringz;
            } else {
                prompt ~= SDL_GetKeyName(event.key.key).fromStringz.toLower;
            }
        } else if (event.key.key == SDLK_BACKSPACE) {
            if (prompt.length != 0)
                prompt.length--;
        } else if (event.key.key == SDLK_ENTER) {
            import std.stdio;
            writeln("prompt: ", prompt);
            // TODO: Handle this in the parent widget/window
            // auto fe = findInEntries(entries, prompt);
            // if (!fe.empty) {
            //     executeShell(fe.front.exec);
            //     quit = true;
            // } else {
            //     writeln(fe);
            // }
        } else if (event.key.key == SDLK_SPACE) {
            prompt ~= ' ';
        }
            // TODO: Handle this in the parent widget/window
        // filtered_entries = findInEntries(entries, prompt);
        // list_str = generateList(filtered_entries);
        // TTF_SetTextString(list_text, list_str.toStringz, list_str.length);
        // SDL_SetWindowSize(sdl_window, cast(int) WINDOW_WIDTH,
        //     cast(int)(
        //         WINDOW_HEIGHT +
        //         PROMPT_BOTTOM_MARGIN +
        //         FONT_HEIGHT * filtered_entries.length));
        prompt ~= "|";
        TTF_SetTextString(ttf_text, prompt.toStringz, prompt.length);
    }
}
