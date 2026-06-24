module mcw.widgets.container;

import std.algorithm : max, remove;
import std.range : empty, popBack;
import std.string : toStringz, fromStringz, toLower;
import std.conv : to;
import std.stdio : writeln;

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
    int focused_child = -1;

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
        if (i == focused_child)
            focused_child = -1;
        children = children.remove(i);
        adjustLayout();
    }

    override void handleEvent(SDL_Event *event) {
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            foreach (i, ref ch; children) {
                if (ch.visible &&
                        ch.rect.x <= event.button.x &&
                        event.button.x <= ch.rect.x+ch.rect.w &&
                        ch.rect.y <= event.button.y &&
                        event.button.y <= ch.rect.y+ch.rect.h) {
                    if (focused_child != -1 && focused_child != i.to!int)
                        children[focused_child].focused = false;
                    focused_child = i.to!int;
                    ch.focused = true;
                }
            }
        }
        if (focused_child != -1) {
            children[focused_child].handleEvent(event);
        }
        if (event && event.type == SDL_EVENT_KEY_DOWN && focused_child != -1) {
            if (event.key.key == SDLK_TAB) {
                children[focused_child].focused = false;
                if (event.key.mod & SDL_KMOD_SHIFT) {
                    focused_child--;
                    if (focused_child < 0)
                        focused_child = children.length.to!int-1;
                } else {
                    focused_child++;
                    if (focused_child >= children.length)
                        focused_child = 0;
                }
                children[focused_child].focused = true;
                *event = SDL_Event();
            }
        }
    }

    @property override void focused(bool focused) {
        this.Widget.focused = focused;
        if (!focused && focused_child != -1) {
            writeln("Container focused: ", focused);
            children[focused_child].focused = false;
            focused_child = -1;
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
