import std.string : toStringz, fromStringz, toLower;
import std.range : back;
import std.conv : to;
import std.algorithm : min;

import bindbc.sdl;

import widgets;
import desktop;

class IconList : Widget {
    // string list_str;
    // TTF_TextEngine *engine;
    // TTF_Text *ttf_text;
    List list;
    Label[] labels;
    Icon[] icons;
    List[] lists;
    DesktopEntry[] entries;
    TTF_Font *font;
    int FONT_HEIGHT;

    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, int max_count,
            int spacing) {
        super(rect, renderer);
        this.type = WidgetTypes.IconList;
        FONT_HEIGHT = TTF_GetFontHeight(font);
        this.font = font;
        list = new List(rect, renderer, spacing, List.Orientation.Vertical);
        // list.style.background_color = SDL_Color(20, 50, 20, 255);
        // list.style.border_color = SDL_Color(20, 100, 20, 255);
        // engine = TTF_CreateRendererTextEngine(renderer);
        // ttf_text = TTF_CreateText(engine, font, list_str.toStringz,
        //         list_str.length);
        for (int i = 0; i < 5; i++) {
            lists ~= new List(SDL_FRect(0, 0, 200, FONT_HEIGHT), renderer, 5,
                    List.Orientation.Horizontal);
            icons ~= new Icon(SDL_FRect(0, 0, FONT_HEIGHT, FONT_HEIGHT),
                    renderer, null);
            labels ~= new Label(SDL_FRect(0, 0, 200, FONT_HEIGHT), renderer,
                    font, (i+10).to!string);
            labels.back.text_placement = Label.TextPlacement.Start;
            lists.back.addChild(&icons.back);
            lists.back.addChild(&labels.back);
            list.addChild(&lists.back);
        }
        list.applyStyleToChildren();
        // import std.stdio;
        // foreach (ch; list.children) {
        //     writeln((*cast(Label*)ch).rect);
        // }
    }

    void updateList() {
        for (int i = 0; i < 5; i++) {
            if (i >= entries.length) {
                lists[i].visible = false;
                continue;
            }
            lists[i].visible = true;
            labels[i].setText(entries[i].name.to!string);
            icons[i].texture = entries[i].icon_texture;
        }
        // list_str = generateList(entries);
        // TTF_SetTextString(ttf_text, list_str.toStringz, list_str.length);
    }

    override void hasMoved() {
        list.rect = rect;
        list.adjustLayout();
    }

    override void draw() {
        this.Widget.draw();
        const int ICON_SIZE = FONT_HEIGHT;
        // TTF_DrawRendererText(ttf_text, rect.x+ICON_SIZE+5, rect.y);
        list.draw();
        // foreach (i, fe; entries) {
        //     SDL_FRect dstrect = SDL_FRect(rect.x, rect.y+FONT_HEIGHT*(i), ICON_SIZE, ICON_SIZE);
        //     SDL_RenderTexture(renderer, fe.icon_texture, null, &dstrect);
        // }
    }
}
