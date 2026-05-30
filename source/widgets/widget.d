import bindbc.sdl;
import styling;

enum WidgetTypes {
    Box, IconList, TextInput, Label, List, Icon,
}

class Widget {
    SDL_FRect rect;
    SDL_Renderer *renderer;
    Style style;
    bool has_moved, visible=true;
    WidgetTypes type;

    this (SDL_FRect rect, SDL_Renderer *renderer) {
        this.rect = rect;
        this.renderer = renderer;
        this.has_moved = false;
    }

    void draw() {
        SDL_Color c;
        SDL_GetRenderDrawColor(renderer, &c.r, &c.g, &c.b, &c.a);
        SDL_SetRenderDrawColor(renderer, style.background_color.tupleof);
        SDL_RenderFillRect(renderer, &rect);
        SDL_SetRenderDrawColor(renderer, style.border_color.tupleof);
        SDL_RenderRect(renderer, &rect);
        SDL_SetRenderDrawColor(renderer, c.tupleof);
    }

    void handleEvent(SDL_Event *event) {}

    invariant {
        assert(rect.x >= 0 && rect.y >= 0 && rect.w >= 0 && rect.h >= 0);
        assert(renderer !is null);
    }
}
