import std.algorithm : max, remove;
import std.range : empty, popBack;
import std.string : toStringz, fromStringz, toLower;
import std.conv : to;

import bindbc.sdl;

import widgets;

abstract class Container : Widget {
    enum Orientation {
        Vertical,
        Horizontal
    }
    int spacing;
    Orientation orientation;
    Widget*[] children;

    this (SDL_FRect rect, SDL_Renderer *renderer, int spacing, Orientation
            orientation) {
        super(rect, renderer);
        this.spacing = spacing;
        this.orientation = orientation;
    }

    void addChild(Widget* w) {
        children ~= w;
        adjustLayout();
    }

    void removeChild(int i) {
        assert(0 <= i && i < children.length);
        if (i+1 == children.length) {
            children.popBack();
            return;
        }
        // FIXME: This is a quickfix, change this later
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

    void adjustLayout() {}

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
