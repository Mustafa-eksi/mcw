module mcw.widgets.container;

import std.algorithm : max, remove;
import std.range : empty, popBack;
import std.string : toStringz, fromStringz, toLower;
import std.conv : to;

import bindbc.sdl;

import mcw.widgets;

abstract class Container : Widget {
    enum Orientation {
        Vertical,
        Horizontal
    }
    int spacing;
    Orientation orientation;
    Widget[] children;

    this (SDL_FRect rect, SDL_Renderer *renderer, int spacing, Orientation
            orientation) {
        super(rect, renderer);
        this.spacing = spacing;
        this.orientation = orientation;
    }

    void addChild(W)(W w) if (is(W : Widget)) {
        children ~= w;
        adjustLayout();
    }

    void removeChild(int i) {
        assert(0 <= i && i < children.length);
        children = children.remove(i);
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
            if (auto b = cast(Box)ch) {
                b.applyStyleToChildren();
            } if (auto l = cast(List)ch) {
                l.applyStyleToChildren();
            }
        }
    }

    void adjustLayout() {}

    override void hasMoved() {
        adjustLayout();
    }

    override void draw() {
        this.Widget.draw();
        foreach (i, ch; children) {
            if (ch.visible)
                ch.draw();
        }
    }
}
