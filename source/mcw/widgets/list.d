module mcw.widgets.list;

import std.algorithm : max, remove;
import std.range : empty, popBack;
import std.string : toStringz, fromStringz, toLower;
import std.conv : to;

import bindbc.sdl;

import mcw.widgets;

class List : Container {
    float element_size;

    this (SDL_FRect rect, SDL_Renderer *renderer, int spacing, Orientation
            orientation) {
        super(rect, renderer, spacing, orientation);
        this.element_size = 0;
    }

    int idealHeight() {
        if (orientation == Orientation.Vertical) {
            return (element_size+spacing).to!int*children.length.to!int+spacing.to!int;
        }
        assert(0);
    }

    void addChild(W)(W w) if (is(W : Widget)) {
        if (children.empty && element_size == 0) {
            if (orientation == Orientation.Vertical)
                element_size = w.rect.h;
            else
                element_size = w.rect.w;
        }
        children ~= w;
        adjustLayout();
    }

    override void adjustLayout() {
        float ycursor = rect.y + spacing;
        float xcursor = rect.x + spacing;

        float maxw = 0, maxh = 0;

        float h = element_size;
        float w = element_size;
        // int total_h = (h+spacing).to!int*children.length.to!int+spacing.to!int;
        // assert(rect.h >= total_h);
        // assert(rect.w >= element_size);
        foreach (i, ref ch; children) {
            if (!ch.visible)
                continue;
            ch.rect.x = xcursor;
            ch.rect.y = ycursor;

            if (orientation == Orientation.Vertical) {
                ch.rect.h = h;
                ycursor += ch.rect.h + spacing;
                maxw = max(maxw, ch.rect.w);
                ch.rect.w = rect.x+(rect.w-spacing)-ch.rect.x;
            } else {
                ch.rect.w = w;
                xcursor += ch.rect.w + spacing;
                maxh = max(maxh, ch.rect.h);
                ch.rect.h = rect.y+(rect.h-spacing)-ch.rect.y;
            }

            ch.hasMoved();
        }
    }
}
