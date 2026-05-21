import bindbc.sdl;

class Widget {
    SDL_FRect rect;
    SDL_Renderer *renderer;
    this (SDL_FRect rect, SDL_Renderer *renderer) {
        this.rect = rect;
        this.renderer = renderer;
    }
    void draw() {}
    void handleEvent(SDL_Event *event) {}
}
