module mcw.widgets.widget;

import bindbc.sdl;
import mcw.widgets.styling;
import mcw.widgets.css : StyleSheet;
import std.algorithm : min;
import std.math : ceil;

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
                outlineRounded(rect, resolved.border_radius, width);
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

    private float cornerCoverage(int x, int y, float radius) {
        int inside;
        foreach (sy; 0 .. 4) foreach (sx; 0 .. 4) {
            float dx = radius - x - (sx + 0.5f) / 4;
            float dy = radius - y - (sy + 0.5f) / 4;
            if (dx * dx + dy * dy <= radius * radius) ++inside;
        }
        return inside / 16.0f;
    }

    private void fillRounded(SDL_FRect area, int radius) {
        int width = cast(int) area.w, height = cast(int) area.h;
        if (width <= 0 || height <= 0) return;
        float r = min(cast(float) radius, min(area.w, area.h) / 2);
        if (r <= 0) { SDL_RenderFillRect(renderer, &area); return; }
        int corner = cast(int) ceil(r);

        // Draw the fully covered spans first, then blend only the few pixels
        // intersected by the circular edge.
        foreach (row; 0 .. height) {
            int y = min(row, height - 1 - row);
            int firstFull;
            if (y < r) {
                firstFull = corner;
                foreach (x; 0 .. corner) {
                    if (cornerCoverage(x, y, r) == 1) {
                        firstFull = x;
                        break;
                    }
                }
            }
            if (firstFull <= width - 1 - firstFull)
                SDL_RenderLine(renderer, area.x + firstFull, area.y + row,
                    area.x + width - 1 - firstFull, area.y + row);
        }

        SDL_Color color;
        SDL_GetRenderDrawColor(renderer, &color.r, &color.g, &color.b, &color.a);
        SDL_BlendMode_ originalBlend;
        SDL_GetRenderDrawBlendMode(renderer, &originalBlend);
        scope(exit) {
            SDL_SetRenderDrawColor(renderer, color.tupleof);
            SDL_SetRenderDrawBlendMode(renderer, originalBlend);
        }
        SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
        foreach (row; 0 .. height) {
            int y = min(row, height - 1 - row);
            if (y >= r) continue;
            foreach (x; 0 .. corner) {
                float coverage = cornerCoverage(x, y, r);
                if (coverage == 1) break;
                if (coverage == 0) continue;
                SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b,
                    cast(ubyte)(color.a * coverage + 0.5f));
                SDL_RenderPoint(renderer, area.x + x, area.y + row);
                if (x != width - 1 - x)
                    SDL_RenderPoint(renderer, area.x + width - 1 - x, area.y + row);
            }
        }
    }

    private void outlineRounded(SDL_FRect area, int radius, int thickness) {
        int width = cast(int) area.w, height = cast(int) area.h;
        if (width <= 0 || height <= 0) return;
        int border = min(thickness, (min(width, height) + 1) / 2);
        float r = min(cast(float) radius, min(area.w, area.h) / 2);
        if (r <= 0) {
            foreach (i; 0 .. border) {
                SDL_FRect ring = SDL_FRect(area.x + i, area.y + i,
                    area.w - 2 * i, area.h - 2 * i);
                if (ring.w <= 0 || ring.h <= 0) break;
                SDL_RenderRect(renderer, &ring);
            }
            return;
        }

        int corner = cast(int) ceil(r);
        SDL_Color color;
        SDL_GetRenderDrawColor(renderer, &color.r, &color.g, &color.b, &color.a);
        SDL_BlendMode_ originalBlend;
        SDL_GetRenderDrawBlendMode(renderer, &originalBlend);
        scope(exit) {
            SDL_SetRenderDrawColor(renderer, color.tupleof);
            SDL_SetRenderDrawBlendMode(renderer, originalBlend);
        }
        SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);

        // Straight sides are fully covered. Only the curved corner pixels need
        // the same 4x4 coverage sampling used by fillRounded.
        foreach (i; 0 .. border) {
            if (corner <= width - 1 - corner) {
                SDL_RenderLine(renderer, area.x + corner, area.y + i,
                    area.x + width - 1 - corner, area.y + i);
                if (i != height - 1 - i)
                    SDL_RenderLine(renderer, area.x + corner, area.y + height - 1 - i,
                        area.x + width - 1 - corner, area.y + height - 1 - i);
            }
            int start = i < corner ? corner : border;
            int end = height - 1 - start;
            if (start <= end) {
                SDL_RenderLine(renderer, area.x + i, area.y + start,
                    area.x + i, area.y + end);
                if (i != width - 1 - i)
                    SDL_RenderLine(renderer, area.x + width - 1 - i, area.y + start,
                        area.x + width - 1 - i, area.y + end);
            }
        }
        float innerRadius = r > border ? r - border : 0;
        foreach (y; 0 .. corner) foreach (x; 0 .. corner) {
            float coverage = cornerCoverage(x, y, r);
            if (x >= border && y >= border)
                coverage -= innerRadius > 0 ?
                    cornerCoverage(x - border, y - border, innerRadius) : 1;
            if (coverage <= 0) continue;
            SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b,
                cast(ubyte)(color.a * coverage + 0.5f));
            int right = width - 1 - x, bottom = height - 1 - y;
            SDL_RenderPoint(renderer, area.x + x, area.y + y);
            if (right != x)
                SDL_RenderPoint(renderer, area.x + right, area.y + y);
            if (bottom != y) {
                SDL_RenderPoint(renderer, area.x + x, area.y + bottom);
                if (right != x)
                    SDL_RenderPoint(renderer, area.x + right, area.y + bottom);
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
