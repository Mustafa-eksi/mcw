import std.algorithm : max, remove;
import std.range : empty, popBack;
import std.string : toStringz, fromStringz, toLower;
import std.conv : to;

import bindbc.sdl;

import widgets;

class List : Widget {
    enum Orientation {
        Vertical,
        Horizontal
    }
    int spacing;
    Orientation orientation;
    Widget*[] children;
    float element_size = 0;

    this (SDL_FRect rect, SDL_Renderer *renderer, int spacing, Orientation
            orientation) {
        this.type = WidgetTypes.List;
        super(rect, renderer);
        this.spacing = spacing;
        this.orientation = orientation;
    }

    void addChild(W)(W* w) if (is(W : Widget)) {
        if (children.empty && element_size == 0) {
            if (orientation == Orientation.Vertical)
                element_size = w.rect.h;
            else
                element_size = w.rect.w;
        }
        children ~= cast(Widget*)w;
        adjustLayout();
    }

    void removeChild(int i) {
        // FIXME: This is a quickfix, change this later
        assert(0 <= i && i < children.length);
        if (i+1 == children.length) {
            children.popBack();
            return;
        }
        children = children[0..i]~children[i+1..$-1];
        adjustLayout();
    }

    override void handleEvent(SDL_Event *event) {
        foreach (ch; children) {
            ch.handleEvent(event);
        }
    }

    void applyStyleToChildren() {
        foreach (ref ch; children) {
            ch.style = style;
            if (ch.type == WidgetTypes.Box)
                (cast(Box*)ch).applyStyleToChildren();
            if (ch.type == WidgetTypes.List)
                (cast(List*)ch).applyStyleToChildren();
        }
    }

    int idealHeight() {
        if (orientation == Orientation.Vertical) {
            return (element_size+spacing).to!int*children.length.to!int+spacing.to!int;
        }
        assert(0);
    }

    void adjustLayout() {
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

            ch.has_moved = true;
        }
    }

    override void draw() {
        this.Widget.draw();
        if (has_moved) {
            adjustLayout();
            has_moved = false;
        }
        foreach (i, ch; children) {
            if (ch.visible)
                ch.draw();
        }
    }
}
