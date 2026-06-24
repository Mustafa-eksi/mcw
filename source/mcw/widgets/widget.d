module mcw.widgets.widget;

import bindbc.sdl;
import mcw.widgets.styling;

class Widget {
    private SDL_FRect _rect;
    SDL_Renderer *renderer;
    Style style;
    bool visible = true;


    this (SDL_FRect rect, SDL_Renderer *renderer) {
        this._rect = rect;
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
                SDL_RenderFillRect(renderer, rectAddr);
            }
            if (style.border_color.a != 0) {
                SDL_SetRenderDrawColor(renderer, style.border_color.tupleof);
                SDL_RenderRect(renderer, rectAddr);
            }
        }
    }

    void handleEvent(SDL_Event *event) {}

    void hasMoved() { }

    @property void rect(SDL_FRect r) {
        _rect = r;
        hasMoved();
    }

    @property ref SDL_FRect rect() {
        return _rect;
    }

    SDL_FRect *rectAddr() {
        return &_rect;
    }

    invariant {
        assert(_rect.x >= 0 && _rect.y >= 0 && _rect.w >= 0 && _rect.h >= 0);
        assert(renderer !is null);
    }
}
