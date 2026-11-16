module mcw.widgets.image;

import std.algorithm : min;
import bindbc.sdl;
import mcw.widgets.widget;

class Image : Widget {
    enum Fit { Contain, Cover, Stretch }
    Fit fit = Fit.Contain;
    SDL_Texture *texture;
    float alignmentX = 0.5f;
    float alignmentY = 0.5f;

    this(SDL_FRect rect, SDL_Renderer *renderer, SDL_Texture *texture,
            Fit fit = Fit.Contain) {
        super(rect, renderer);
        this.texture = texture;
        this.fit = fit;
        focusable = false;
    }

    override void draw() {
        if (!visible) return;
        super.draw();
        if (texture is null) return;
        float sourceWidth, sourceHeight;
        if (!SDL_GetTextureSize(texture, &sourceWidth, &sourceHeight) ||
                sourceWidth <= 0 || sourceHeight <= 0 || rect.w <= 0 || rect.h <= 0) return;
        SDL_FRect source = SDL_FRect(0, 0, sourceWidth, sourceHeight);
        SDL_FRect destination = rect;
        if (fit == Fit.Contain) {
            float scale = min(rect.w / sourceWidth, rect.h / sourceHeight);
            destination.w = sourceWidth * scale;
            destination.h = sourceHeight * scale;
            destination.x = rect.x + (rect.w - destination.w) * alignmentX;
            destination.y = rect.y + (rect.h - destination.h) * alignmentY;
        } else if (fit == Fit.Cover) {
            float targetRatio = rect.w / rect.h;
            float sourceRatio = sourceWidth / sourceHeight;
            if (sourceRatio > targetRatio) source.w = sourceHeight * targetRatio;
            else source.h = sourceWidth / targetRatio;
            source.x = (sourceWidth - source.w) * alignmentX;
            source.y = (sourceHeight - source.h) * alignmentY;
        }
        SDL_RenderTexture(renderer, texture, &source, &destination);
    }
}
