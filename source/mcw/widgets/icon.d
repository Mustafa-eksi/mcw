module mcw.widgets.icon;

import mcw.widgets;
import bindbc.sdl;

class Icon : Widget {
    SDL_Texture *texture;

    this (SDL_FRect rect, SDL_Renderer *renderer, SDL_Texture* texture) {
        super(rect, renderer);
        this.type = WidgetTypes.Icon;
        this.texture = texture;
    }

    override void draw() {
        this.Widget.draw();
        SDL_RenderTexture(renderer, texture, null, rectAddr);
    }
}
