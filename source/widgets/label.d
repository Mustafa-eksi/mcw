import std.string : toStringz;

import bindbc.sdl;

import widget;

class Label : Widget {
    string text;
    TTF_TextEngine *engine;
    TTF_Text *ttf_text;
    enum TextPlacement {
        Start, Center
    }
    TextPlacement tp;
    float text_x, text_y;
    int FONT_HEIGHT;
    int text_width;

    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, string s) {
        super(rect, renderer);
        this.type = WidgetTypes.Label;
        text = s;
        engine = TTF_CreateRendererTextEngine(renderer);
        ttf_text = TTF_CreateText(engine, font, text.toStringz,
                text.length);
        FONT_HEIGHT = TTF_GetFontHeight(font);
        TTF_MeasureString(font, text.toStringz, text.length, cast(int)rect.w, &text_width, null);
        text_x = rect.x;
        text_y = rect.y;
        tp = TextPlacement.Center;
    }

    void setText(string s) {
        text = s;
        TTF_SetTextString(ttf_text, text.toStringz, text.length);
    }

    void setTextPlacement() {
        switch (tp) {
        case TextPlacement.Start:
            text_x = rect.x;
            text_y = rect.y;
            break;
        case TextPlacement.Center:
            text_x = rect.x+(rect.w-text_width)/2;
            text_y = rect.y+(rect.h-FONT_HEIGHT)/2;
            break;
        default:
            assert(false);
            break;
        }
    }

    override void draw() {
        this.Widget.draw();
        // FIXME: this is bad for performance
        if (has_moved) {
            setTextPlacement();
            has_moved = false;
        }
        TTF_DrawRendererText(ttf_text, cast(int)text_x, cast(int)text_y);
    }
}
