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
            int count;
            foreach (child; children) if (child.visible) count++;
            return (element_size+spacing).to!int * count + spacing;
        }
        assert(0);
    }

    int idealWidth() {
        if (orientation == Orientation.Horizontal) {
            int count;
            foreach (child; children) if (child.visible) count++;
            return (element_size+spacing).to!int * count + spacing;
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
        auto s = computedStyle();
        float ycursor = rect.y + spacing + s.padding_top;
        float xcursor = rect.x + spacing + s.padding_left;

        float h = element_size;
        float w = element_size;
        // int total_h = (h+spacing).to!int*children.length.to!int+spacing.to!int;
        // assert(rect.h >= total_h);
        // assert(rect.w >= element_size);
        foreach (i, ref ch; children) {
            if (!ch.visible)
                continue;
            SDL_FRect child_rect = ch.rect;
            child_rect.x = xcursor;
            child_rect.y = ycursor;

            if (orientation == Orientation.Vertical) {
                child_rect.h = h;
                ycursor += child_rect.h + spacing;
                child_rect.w = max(0.0f, rect.x+(rect.w-spacing-s.padding_right)-child_rect.x);
            } else {
                child_rect.w = w;
                xcursor += child_rect.w + spacing;
                child_rect.h = max(0.0f, rect.y+(rect.h-spacing-s.padding_bottom)-child_rect.y);
            }

            ch.rect = child_rect;
        }
    }
}
