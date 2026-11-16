module mcw.widgets.box;

import std.algorithm : max, remove;
import std.range : popBack, empty;
import std.string : toStringz, fromStringz, toLower;

import bindbc.sdl;

import mcw.widgets;

class Box : Container {
    bool uniform = true;

    this (SDL_FRect rect, SDL_Renderer *renderer, int spacing, Orientation
            orientation) {
        super(rect, renderer, spacing, orientation);
    }

    override void adjustLayout() {
        if (children.empty)
            return;
        auto s = computedStyle();
        float ycursor = rect.y + spacing + s.padding_top;
        float xcursor = rect.x + spacing + s.padding_left;

        float h = max(0.0f, (rect.h-s.padding_top-s.padding_bottom-spacing)/children.length-spacing);
        float w = max(0.0f, (rect.w-s.padding_left-s.padding_right-spacing)/children.length-spacing);
        float flexibleSize = 0;
        if (!uniform) {
            float fixedSize = 0;
            int flexibleCount;
            foreach (ch; children) {
                if (cast(Spacer) ch) flexibleCount++;
                else fixedSize += orientation == Orientation.Vertical ? ch.rect.h : ch.rect.w;
            }
            if (flexibleCount > 0) {
                float available = orientation == Orientation.Vertical ?
                    rect.h - s.padding_top - s.padding_bottom :
                    rect.w - s.padding_left - s.padding_right;
                flexibleSize = max(0.0f,
                    (available - fixedSize - spacing * (children.length + 1)) /
                    flexibleCount);
            }
        }
        foreach (i, ref ch; children) {
            SDL_FRect child_rect = ch.rect;
            child_rect.x = xcursor;
            child_rect.y = ycursor;

            if (orientation == Orientation.Vertical) {
                if (uniform)
                    child_rect.h = h;
                else if (cast(Spacer) ch)
                    child_rect.h = flexibleSize;
                ycursor += child_rect.h + spacing;
                child_rect.w = max(0.0f, rect.x+(rect.w-spacing-s.padding_right)-child_rect.x);
            } else {
                if (uniform)
                    child_rect.w = w;
                else if (cast(Spacer) ch)
                    child_rect.w = flexibleSize;
                xcursor += child_rect.w + spacing;
                child_rect.h = max(0.0f, rect.y+(rect.h-spacing-s.padding_bottom)-child_rect.y);
            }

            ch.rect = child_rect;
        }
    }
}
