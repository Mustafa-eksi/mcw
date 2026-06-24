module mcw.widgets.icon_list;

import std.string : toStringz, fromStringz, toLower;
import std.range : back;
import std.conv : to;
import std.algorithm : min;

import bindbc.sdl;

import mcw.widgets;
import mcw.desktop;

class IconList : List {
    Label[] labels;
    Icon[] icons;
    List[] lists;
    DesktopEntry[] entries;
    TTF_Font *font;
    int FONT_HEIGHT;

    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, int max_count,
            int spacing) {
        super(rect, renderer, spacing, Container.Orientation.Vertical);
        FONT_HEIGHT = TTF_GetFontHeight(font);
        this.font = font;
        for (int i = 0; i < 5; i++) {
            lists ~= new List(SDL_FRect(0, 0, 200, FONT_HEIGHT), renderer, 5,
                    List.Orientation.Horizontal);
            icons ~= new Icon(SDL_FRect(0, 0, FONT_HEIGHT, FONT_HEIGHT),
                    renderer, null);
            labels ~= new Label(SDL_FRect(0, 0, 200, FONT_HEIGHT), renderer,
                    font, (i+10).to!string);
            labels.back.text_placement = Label.TextPlacement.Start;
            lists.back.addChild(icons.back);
            lists.back.addChild(labels.back);
            addChild(lists.back);
        }
        applyStyleToChildren();
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
    }

    override void hasMoved() {
        adjustLayout();
    }
}
