module mcw.widgets.widget;

import bindbc.sdl;
import mcw.widgets.styling;

enum WidgetTypes {
    Unknown = 0, Box, IconList, TextInput, Label, List, Icon,
}

class Widget {
    SDL_FRect rect;
    SDL_Renderer *renderer;
    Style style;
    bool visible=true;
    WidgetTypes type;

    this (SDL_FRect rect, SDL_Renderer *renderer) {
        this.rect = rect;
        this.renderer = renderer;
    }

    void draw() {
        version (NoWidgetDraw) {} else {
            version (SaveDrawColor) {
                SDL_Color c;
                SDL_GetRenderDrawColor(renderer, &c.r, &c.g, &c.b, &c.a);
                scope(exit) SDL_SetRenderDrawColor(renderer, c.tupleof);
            }

            if (style.background_color.a != 0) {
                SDL_SetRenderDrawColor(renderer, style.background_color.tupleof);
                SDL_RenderFillRect(renderer, &rect);
            }
            if (style.border_color.a != 0) {
                SDL_SetRenderDrawColor(renderer, style.border_color.tupleof);
                SDL_RenderRect(renderer, &rect);
            }
        }
    }

    void handleEvent(SDL_Event *event) {}

    void hasMoved() { }

    invariant {
        assert(rect.x >= 0 && rect.y >= 0 && rect.w >= 0 && rect.h >= 0);
        assert(renderer !is null);
    }
}
