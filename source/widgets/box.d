import std.algorithm : max;
import std.string : toStringz, fromStringz, toLower;

import bindbc.sdl;

import widget;

class Box : Widget {
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

    override void handleEvent(SDL_Event *event) {
        foreach (ch; children) {
            ch.handleEvent(event);
        }
    }

    void adjustLayout() {
        float ycursor = rect.y + spacing;
        float xcursor = rect.x + spacing;
        float maxw = 0, maxh = 0;
        foreach (i, ch; children) {
            ch.rect.x = xcursor;
            ch.rect.y = ycursor;
            if (orientation == Orientation.Vertical) {
                ycursor += ch.rect.h + spacing;
                maxw = max(maxw, ch.rect.w);
            } else {
                xcursor += ch.rect.w + spacing;
                maxh = max(maxh, ch.rect.h);
            }
        }
        if (orientation == Orientation.Vertical) {
            rect.h = ycursor - rect.y;
            rect.w = maxw;
        } else {
            rect.w = xcursor - rect.x;
            rect.h = maxh;
        }
    }

    override void draw() {
        foreach (i, ch; children) {
            ch.draw();
        }
    }
}
