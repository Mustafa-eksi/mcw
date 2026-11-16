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
    int cssBaseSpacing;
    bool cssGapApplied;
    Orientation orientation;
    Widget[] children;
    int focused_child = -1;

    this (SDL_FRect rect, SDL_Renderer *renderer, int spacing, Orientation
            orientation) {
        super(rect, renderer);
        this.spacing = spacing;
        this.cssBaseSpacing = spacing;
        this.orientation = orientation;
    }

    void addChild(W)(W w) if (is(W : Widget)) {
        children ~= w;
        adjustLayout();
    }

    void removeChild(int i) {
        assert(0 <= i && i < children.length);
        if (i == focused_child) {
            children[i].focused = false;
            focused_child = -1;
        } else if (i < focused_child) {
            focused_child--;
        }
        children = children.remove(i);
        adjustLayout();
    }

    override void handleEvent(SDL_Event *event) {
        if (event is null || !enabled || !visible)
            return;
        if (event.type == SDL_EVENT_MOUSE_MOTION) {
            foreach (ch; children) {
                ch.hovered = ch.enabled && ch.contains(event.motion.x, event.motion.y);
                if (ch.visible && ch.enabled)
                    ch.handleEvent(event);
            }
            return;
        }
        if (event.type == SDL_EVENT_MOUSE_WHEEL) {
            foreach_reverse (ch; children) {
                if (ch.enabled && ch.contains(event.wheel.mouseX,
                            event.wheel.mouseY)) {
                    ch.handleEvent(event);
                    return;
                }
            }
        }
        if (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN ||
                event.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            // Children draw front to back; the last drawn hit receives the click.
            foreach_reverse (i, ch; children) {
                if (ch.visible && ch.enabled &&
                        ch.contains(event.button.x, event.button.y)) {
                    if (focused_child != -1 && focused_child != i.to!int)
                        children[focused_child].focused = false;
                    focused_child = i.to!int;
                    ch.focused = true;
                    ch.focusVisible = false;
                    break;
                }
            }
        }
        if (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_TAB) {
            int next = focused_child;
            foreach (_; 0 .. children.length) {
                next = (next + ((event.key.mod & SDL_KMOD_SHIFT) ?
                    cast(int) children.length - 1 : 1)) % cast(int) children.length;
                if (children[next].visible && children[next].enabled &&
                        children[next].focusable) {
                    if (focused_child != -1)
                        children[focused_child].focused = false;
                    focused_child = next;
                    children[next].focused = true;
                    children[next].focusVisible = true;
                    *event = SDL_Event();
                    return;
                }
            }
        }
        if (focused_child != -1) {
            children[focused_child].handleEvent(event);
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

    @property override bool focused() {
        return this.Widget.focused;
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
