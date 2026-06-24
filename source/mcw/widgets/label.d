module mcw.widgets.label;

import std.string : toStringz;

import bindbc.sdl;

import mcw.widgets.widget;

class Label : Widget {
    private SDL_Color _text_color = SDL_Color(255, 255, 255, 255);

    string text;
    TTF_TextEngine *engine;
    TTF_Text *ttf_text;
    enum TextPlacement {
        Start, Center
    }
    TextPlacement _tp;
    float text_x, text_y;
    int FONT_HEIGHT;
    int text_width;

    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, string s) {
        super(rect, renderer);
        text = s;
        engine = TTF_CreateRendererTextEngine(renderer);
        ttf_text = TTF_CreateText(engine, font, text.toStringz,
                text.length);
        FONT_HEIGHT = TTF_GetFontHeight(font);
        TTF_MeasureString(font, text.toStringz, text.length, cast(int)rect.w, &text_width, null);
        text_x = rect.x;
        text_y = rect.y;
        text_placement = TextPlacement.Center;
    }

    void setText(string s) {
        text = s;
        TTF_SetTextString(ttf_text, text.toStringz, text.length);
    }

    @property void text_placement(TextPlacement tp) {
        _tp = tp;
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

    @property TextPlacement text_placement() {
        return _tp;
    }

    @property void text_color(SDL_Color c) {
        _text_color = c;
        TTF_SetTextColor(ttf_text, _text_color.tupleof);
    }

    @property SDL_Color text_color() {
        return _text_color;
    }

    override void hasMoved() {
        text_placement(_tp);
    }

    override void draw() {
        this.Widget.draw();
        TTF_DrawRendererText(ttf_text, cast(int)text_x, cast(int)text_y);
    }

    ~this () {
        TTF_DestroyText(ttf_text);
        TTF_DestroyRendererTextEngine(engine);
    }
}
