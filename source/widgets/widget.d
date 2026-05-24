import bindbc.sdl;
import styling;

class Widget {
    SDL_FRect rect;
    SDL_Renderer *renderer;
    Style style;
    bool has_moved;

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
}
