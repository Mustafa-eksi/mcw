module mcw.widgets.icon_list;

import std.string : toStringz, fromStringz, toLower;
import std.range : back;
import std.conv : to;
import std.algorithm : min, max;

import bindbc.sdl;

import mcw.widgets;
import mcw.desktop;

private class IconRow : List {
    int iconSize;
    enum padding = 5;

    this(SDL_FRect rect, SDL_Renderer *renderer, int iconSize) {
        super(rect, renderer, padding, Orientation.Horizontal);
        this.iconSize = iconSize;
    }

    override void adjustLayout() {
        if (children.length < 2) return;
        auto icon = cast(Icon) children[0];
        auto label = cast(Label) children[1];
        if (icon is null || label is null) return;

        float available = max(0.0f, rect.w - 2 * padding);
        float iconWidth = min(cast(float) iconSize, available);
        float nameWidth = max(0.0f, available - iconWidth - padding);
        float visibleNameWidth = min(cast(float) label.text_width, nameWidth);
        float groupWidth = iconWidth + padding + visibleNameWidth;
        float x = cast(int)(rect.x + max(cast(float) padding,
                    (rect.w - groupWidth) / 2));
        float y = rect.y + padding;
        float height = max(0.0f, min(cast(float) iconSize,
                    rect.h - 2 * padding));
        icon.rect = SDL_FRect(x, y, iconWidth, height);
        label.rect = SDL_FRect(x + iconWidth + padding, y,
                visibleNameWidth, height);
    }
}

class IconList : SelectableList {
    Label[] labels;
    Icon[] icons;
    List[] lists;
    DesktopEntry[] entries;
    TTF_Font *font;
    int FONT_HEIGHT;

    this (SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, int max_count,
            int spacing) {
        super(rect, renderer, spacing);
        FONT_HEIGHT = TTF_GetFontHeight(font);
        this.font = font;
        for (int i = 0; i < max_count; i++) {
            lists ~= new IconRow(SDL_FRect(0, 0, 200, FONT_HEIGHT + 10),
                    renderer, FONT_HEIGHT);
            icons ~= new Icon(SDL_FRect(0, 0, FONT_HEIGHT, FONT_HEIGHT),
                    renderer, null);
            labels ~= new Label(SDL_FRect(0, 0, 200, FONT_HEIGHT), renderer,
                    font, (i+10).to!string);
            lists.back.addChild(icons.back);
            lists.back.addChild(labels.back);
            addChild(lists.back);
        }
        applyStyleToChildren();
    }

    void updateList() {
        if (selectedIndex >= entries.length)
            clearSelection();
        for (int i = 0; i < lists.length; i++) {
            if (i >= entries.length) {
                lists[i].visible = false;
                continue;
            }
            lists[i].visible = true;
            labels[i].setText(entries[i].name.to!string);
            icons[i].texture = entries[i].icon_texture;
        }
        adjustLayout();
    }

    override void hasMoved() {
        adjustLayout();
    }
}
