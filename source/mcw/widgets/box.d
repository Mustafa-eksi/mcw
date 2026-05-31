module mcw.widgets.box;

import std.algorithm : max, remove;
import std.range : popBack;
import std.string : toStringz, fromStringz, toLower;

import bindbc.sdl;

import mcw.widgets;

class Box : Container {
    bool uniform = true;

    this (SDL_FRect rect, SDL_Renderer *renderer, int spacing, Orientation
            orientation) {
        super(rect, renderer, spacing, orientation);
        this.type = WidgetTypes.Box;
    }

    override void adjustLayout() {
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

            ch.hasMoved();
        }
    }
}
