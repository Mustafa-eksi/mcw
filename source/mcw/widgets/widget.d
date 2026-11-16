module mcw.widgets.widget;

import bindbc.sdl;
import mcw.widgets.styling;
import mcw.widgets.css : StyleSheet;
import std.algorithm : min;
import std.math : sqrt;

class Widget {
    private SDL_FRect _rect;
    SDL_Renderer *renderer;
    Style style;
    StyleSheet styleSheet;
    string styleId;
    string[] styleClasses;
    bool visible = true;
    bool enabled = true;
    bool focusable = true;
    bool hovered = false;
    bool focusVisible = false;

    // Only set by the parent container, not by the widget itself
    bool _focused = false;

    this (SDL_FRect rect, SDL_Renderer *renderer) {
        this._rect = rect;
        this.renderer = renderer;
    }

    void draw() {
        version (NoWidgetDraw) {} else {
            if (!visible) return;
            version (SaveDrawColor) {
                SDL_Color c;
                SDL_GetRenderDrawColor(renderer, &c.r, &c.g, &c.b, &c.a);
                scope(exit) SDL_SetRenderDrawColor(renderer, c.tupleof);
            }

            auto resolved = computedStyle();
            auto background = resolved.background_color;
            if (!enabled && resolved.disabled_color.a != 0)
                background = resolved.disabled_color;
            else if (cssState("pressed") && resolved.pressed_color.a != 0)
                background = resolved.pressed_color;
            else if (hovered && resolved.hover_color.a != 0)
                background = resolved.hover_color;
            if (cssState("selected") && resolved.has_selection_color)
                background = resolved.selection_color;
            if (background.a != 0) {
                SDL_SetRenderDrawColor(renderer, background.tupleof);
                fillRounded(rect, resolved.border_radius);
            }
            auto border = showFocusBorder() && resolved.focused_border_color.a != 0
                ? resolved.focused_border_color : resolved.border_color;
            int width = resolved.has_border_width ? resolved.border_width :
                (resolved.border_width > 0 ? resolved.border_width : 1);
            if (border.a != 0 && width > 0) {
                SDL_SetRenderDrawColor(renderer, border.tupleof);
                foreach (i; 0 .. width) {
                    SDL_FRect ring = SDL_FRect(rect.x + i, rect.y + i,
                        rect.w - 2 * i, rect.h - 2 * i);
                    if (ring.w <= 0 || ring.h <= 0) break;
                    outlineRounded(ring, resolved.border_radius - i);
                }
            }
        }
    }

    Style computedStyle() {
        return styleSheet is null ? style : styleSheet.compute(this);
    }

    bool cssState(string state) {
        switch (state) {
        case "hover": return hovered;
        case "focus": return focused;
        case "focus-visible": return focused && focusVisible;
        case "disabled": return !enabled;
        default: return false;
        }
    }

    bool showFocusBorder() { return focused; }

    private float cornerInset(float y, float w, float h, int radius) {
        float r = min(cast(float) radius, min(w, h) / 2);
        if (r <= 0) return 0;
        float distance = y < r ? r - y - 0.5f :
            (y >= h - r ? y - (h - r) + 0.5f : 0);
        return distance <= 0 ? 0 : r - cast(float) sqrt(r * r - distance * distance);
    }

    private void fillRounded(SDL_FRect area, int radius) {
        if (radius <= 0) { SDL_RenderFillRect(renderer, &area); return; }
        foreach (row; 0 .. cast(int) area.h) {
            float inset = cornerInset(row, area.w, area.h, radius);
            SDL_RenderLine(renderer, area.x + inset, area.y + row,
                area.x + area.w - 1 - inset, area.y + row);
        }
    }

    private void outlineRounded(SDL_FRect area, int radius) {
        if (radius <= 0) { SDL_RenderRect(renderer, &area); return; }
        foreach (row; 0 .. cast(int) area.h) {
            float inset = cornerInset(row, area.w, area.h, radius);
            if (row == 0 || row == cast(int) area.h - 1)
                SDL_RenderLine(renderer, area.x + inset, area.y + row,
                    area.x + area.w - 1 - inset, area.y + row);
            else {
                SDL_RenderPoint(renderer, area.x + inset, area.y + row);
                SDL_RenderPoint(renderer, area.x + area.w - 1 - inset, area.y + row);
            }
        }
    }

    void handleEvent(SDL_Event *event) {}

    void onFocusLost() {}

    bool contains(float x, float y) {
        return visible && rect.x <= x && x < rect.x + rect.w &&
            rect.y <= y && y < rect.y + rect.h;
    }

    void hasMoved() { }

    @property void rect(SDL_FRect r) {
        _rect = r;
        hasMoved();
    }

    @property ref const(SDL_FRect) rect() {
        return _rect;
    }

    @property bool focused() {
        return _focused;
    }

    @property void focused(bool f) {
        if (_focused && !f)
            onFocusLost();
        if (!f)
            focusVisible = false;
        _focused = f;
    }

    protected SDL_FRect *rectAddr() {
        return &_rect;
    }

    invariant {
        assert(_rect.w >= 0 && _rect.h >= 0);
        assert(renderer !is null);
    }
}
