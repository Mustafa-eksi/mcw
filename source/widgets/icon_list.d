import std.string : toStringz, fromStringz, toLower;

import bindbc.sdl;

import widget;
import desktop;

class IconList : Widget {
    string list_str;
    TTF_TextEngine *engine;
    TTF_Text *ttf_text;
    DesktopEntry[] entries;
    int FONT_HEIGHT;

    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font) {
        super(rect, renderer);
        FONT_HEIGHT = TTF_GetFontHeight(font);
        engine = TTF_CreateRendererTextEngine(renderer);
        ttf_text = TTF_CreateText(engine, font, list_str.toStringz,
                list_str.length);
    }

    void updateList() {
        list_str = generateList(entries);
        TTF_SetTextString(ttf_text, list_str.toStringz, list_str.length);
    }

    override void draw() {
        this.Widget.draw();
        const int ICON_SIZE = FONT_HEIGHT;
        TTF_DrawRendererText(ttf_text, rect.x+ICON_SIZE+5, rect.y);
        foreach (i, fe; entries) {
            SDL_FRect dstrect = SDL_FRect(rect.x, rect.y+FONT_HEIGHT*(i), ICON_SIZE, ICON_SIZE);
            SDL_RenderTexture(renderer, fe.icon_texture, null, &dstrect);
        }
    }
}
