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
        this.type = WidgetTypes.TextInput;
        prompt = "|";
        engine = TTF_CreateRendererTextEngine(renderer);
        ttf_text = TTF_CreateText(engine, font, prompt.toStringz,
                prompt.length);
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
        } else if (event.key.key == SDLK_SPACE) {
            prompt ~= ' ';
        }
        prompt ~= "|";
        TTF_SetTextString(ttf_text, prompt.toStringz, prompt.length);
    }

    override void draw() {
        this.Widget.draw();
        TTF_DrawRendererText(ttf_text, rect.x, rect.y);
    }
}
