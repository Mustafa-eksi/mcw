module mcw.widgets.label;

import std.algorithm : min, max;
import std.string : toStringz;

import bindbc.sdl;

import mcw.widgets.widget;

class Label : Widget {
    private SDL_Color _text_color = SDL_Color(255, 255, 255, 255);

    string text;
    TTF_TextEngine *engine;
    TTF_Text *ttf_text;
    TTF_Font *font;
    enum TextPlacement {
        Start, StartCenter, Center
    }
    TextPlacement _tp = TextPlacement.Center;
    float text_x, text_y;
    int FONT_HEIGHT;
    int text_width;

    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, string s) {
        super(rect, renderer);
        this.font = font;
        focusable = false;
        text = s;
        engine = TTF_CreateRendererTextEngine(renderer);
        ttf_text = TTF_CreateText(engine, font, text.toStringz,
                text.length);
        FONT_HEIGHT = TTF_GetFontHeight(font);
        TTF_GetStringSize(font, text.toStringz, text.length, &text_width, null);
        text_x = rect.x;
        text_y = rect.y;
        text_placement = TextPlacement.Center;
    }

    void setText(string s) {
        text = s;
        TTF_SetTextString(ttf_text, text.toStringz, text.length);
        TTF_GetStringSize(font, text.toStringz, text.length, &text_width, null);
        text_placement = _tp;
    }

    @property void text_placement(TextPlacement tp) {
        _tp = tp;
        auto s = computedStyle();
        float left = rect.x + s.padding_left;
        float top = rect.y + s.padding_top;
        float width = max(0.0f, rect.w - s.padding_left - s.padding_right);
        float height = max(0.0f, rect.h - s.padding_top - s.padding_bottom);
        switch (tp) {
        case TextPlacement.Start:
            text_x = left + textStartOffset();
            text_y = top;
            break;
        case TextPlacement.StartCenter:
            text_x = left + textStartOffset();
            text_y = top + (height - FONT_HEIGHT) / 2;
            break;
        case TextPlacement.Center:
            text_x = left + max(0.0f, (width - text_width) / 2);
            text_y = top + (height-FONT_HEIGHT)/2;
            break;
        default:
            assert(false);
            break;
        }
    }

    protected float textStartOffset() { return 0; }

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

    SDL_Color effectiveTextColor() {
        auto s = computedStyle();
        return s.has_text_color ? s.text_color : _text_color;
    }

    override void hasMoved() {
        text_placement(_tp);
    }

    override void draw() {
        if (!visible) return;
        SDL_Rect previous;
        bool hadClip = SDL_RenderClipEnabled(renderer);
        if (hadClip) SDL_GetRenderClipRect(renderer, &previous);
        SDL_Rect clip = SDL_Rect(cast(int)rect.x, cast(int)rect.y,
                cast(int)rect.w, cast(int)rect.h);
        if (hadClip) {
            int x = max(clip.x, previous.x), y = max(clip.y, previous.y);
            int right = min(clip.x + clip.w, previous.x + previous.w);
            int bottom = min(clip.y + clip.h, previous.y + previous.h);
            clip = SDL_Rect(x, y, max(0, right - x), max(0, bottom - y));
        }
        SDL_SetRenderClipRect(renderer, &clip);
        scope(exit) {
            if (hadClip) SDL_SetRenderClipRect(renderer, &previous);
            else SDL_SetRenderClipRect(renderer, null);
        }
        this.Widget.draw();
        text_placement = _tp;
        auto color = effectiveTextColor();
        TTF_SetTextColor(ttf_text, color.tupleof);
        TTF_DrawRendererText(ttf_text, cast(int)text_x, cast(int)text_y);
    }

    ~this () {
        TTF_DestroyText(ttf_text);
        TTF_DestroyRendererTextEngine(engine);
    }
}
