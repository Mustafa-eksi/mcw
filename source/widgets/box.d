import std.algorithm : max, remove;
import std.range : popBack;
import std.string : toStringz, fromStringz, toLower;

import bindbc.sdl;

import widgets;

class Box : Widget {
    enum Orientation {
        Vertical,
        Horizontal
    }
    int spacing;
    Orientation orientation;
    Widget*[] children;
    bool uniform = true;

    this (SDL_FRect rect, SDL_Renderer *renderer, int spacing, Orientation
            orientation) {
        super(rect, renderer);
        this.spacing = spacing;
        this.orientation = orientation;
        this.type = WidgetTypes.Box;
    }

    void addChild(Widget* w) {
        children ~= w;
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

    void adjustLayout() {
        float ycursor = rect.y + spacing;
        float xcursor = rect.x + spacing;

        float maxw = 0, maxh = 0;

        float h = (rect.h-spacing)/children.length-spacing;
        float w = (rect.w-spacing)/children.length-spacing;
        foreach (i, ref ch; children) {
            ch.rect.x = xcursor;
            ch.rect.y = ycursor;

            if (orientation == Orientation.Vertical) {
                if (uniform)
                    ch.rect.h = h;
                ycursor += ch.rect.h + spacing;
                maxw = max(maxw, ch.rect.w);
                ch.rect.w = rect.x+(rect.w-spacing)-ch.rect.x;
            } else {
                if (uniform)
                    ch.rect.w = w;
                xcursor += ch.rect.w + spacing;
                maxh = max(maxh, ch.rect.h);
                ch.rect.h = rect.y+(rect.h-spacing)-ch.rect.y;
            }

            ch.has_moved = true;
        }
        // if (orientation == Orientation.Vertical) {
        //     rect.h = ycursor - rect.y;
        //     rect.w = maxw;
        // } else {
        //     rect.w = xcursor - rect.x;
        //     rect.h = maxh;
        // }
    }

    override void draw() {
        this.Widget.draw();
        if (has_moved) {
            adjustLayout();
            has_moved = false;
        }
        foreach (i, ch; children) {
            ch.draw();
        }
    }
}
