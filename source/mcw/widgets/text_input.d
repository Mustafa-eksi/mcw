module mcw.widgets.text_input;

import std.string : toStringz, fromStringz, toLower;

import bindbc.sdl;

import mcw.widgets;

class TextInput : Label {
    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font) {
        super(rect, renderer, font, "|");
        this.text_placement = TextPlacement.Start;

        this.type = WidgetTypes.TextInput;
    }

    override void handleEvent(SDL_Event *event) {
        text.length--;
        if (SDLK_A <= event.key.key && SDLK_Z >= event.key.key) {
            if (event.key.mod & SDL_KMOD_SHIFT) {
                text ~= SDL_GetKeyName(event.key.key).fromStringz;
            } else {
                text ~= SDL_GetKeyName(event.key.key).fromStringz.toLower;
            }
        } else if (event.key.key == SDLK_BACKSPACE) {
            if (text.length != 0)
                text.length--;
        } else if (event.key.key == SDLK_SPACE) {
            text ~= ' ';
        }
        text ~= "|";
        TTF_SetTextString(ttf_text, text.toStringz, text.length);
    }
}
