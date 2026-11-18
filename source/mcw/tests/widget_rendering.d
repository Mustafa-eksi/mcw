module mcw.tests.widget_rendering;

import std.algorithm : max;
import std.file : mkdirRecurse;
import std.path : buildPath;
import std.stdio : File;
import std.string : toStringz;

import bindbc.sdl;
import bindbc.loader : LoadMsg;

import mcw.widgets;
import mcw.desktop : DesktopEntry;

private struct Canvas {
    SDL_Surface *surface;
    SDL_Renderer *renderer;

    @disable this(this);

    this(int width, int height) {
        assert(loadSDL() == LoadMsg.success);
        assert(SDL_Init(0));
        surface = SDL_CreateSurface(width, height, SDL_PIXELFORMAT_RGBA32);
        assert(surface !is null);
        renderer = SDL_CreateSoftwareRenderer(surface);
        assert(renderer !is null);
    }

    ~this() {
        SDL_DestroyRenderer(renderer);
        SDL_DestroySurface(surface);
        SDL_Quit();
    }

    void draw(Widget widget) {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
        widget.draw();
        SDL_RenderPresent(renderer);
    }

    void check(string name, bool delegate(int, int, ubyte, ubyte, ubyte) matches) {
        mkdirRecurse("test-output");
        auto file = File(buildPath("test-output", name ~ ".ppm"), "wb");
        file.writef("P6\n%d %d\n255\n", surface.w, surface.h);
        int matched;
        foreach (y; 0 .. surface.h) {
            foreach (x; 0 .. surface.w) {
                ubyte r, g, b, a;
                assert(SDL_ReadSurfacePixel(surface, x, y, &r, &g, &b, &a));
                ubyte[3] pixel = [r, g, b];
                file.rawWrite(pixel[]);
                if (matches(x, y, r, g, b))
                    matched++;
            }
        }
        file.close();
        assert(matched == surface.w * surface.h,
                name ~ " pixel mismatch; see test-output/" ~ name ~ ".ppm");
    }
}

unittest {
    auto canvas = Canvas(12, 12);
    auto widget = new Widget(SDL_FRect(2, 2, 6, 6), canvas.renderer);
    widget.style.background_color = SDL_Color(255, 0, 0, 255);
    widget.style.border_color = SDL_Color(0, 255, 0, 255);
    widget.style.focused_border_color = SDL_Color(0, 0, 255, 255);

    foreach (focused; [false, true]) {
        widget.focused = focused;
        canvas.draw(widget);
        int background, border;
        canvas.check(focused ? "widget-focused" : "widget", (x, y, r, g, b) {
            bool inside = x >= 2 && x < 8 && y >= 2 && y < 8;
            bool edge = inside && (x == 2 || x == 7 || y == 2 || y == 7);
            if (edge) {
                if (focused ? r == 0 && g == 0 && b == 255
                            : r == 0 && g == 255 && b == 0)
                    border++;
                return focused ? r == 0 && g == 0 && b == 255
                               : r == 0 && g == 255 && b == 0;
            }
            if (inside) {
                if (r == 255 && g == 0 && b == 0)
                    background++;
                return r == 255 && g == 0 && b == 0;
            }
            return r == 0 && g == 0 && b == 0;
        });
        assert(background == 16 && border == 20);
    }
}

unittest {
    auto canvas = Canvas(44, 44);
    auto widget = new Widget(SDL_FRect(2, 2, 40, 40), canvas.renderer);
    widget.style.background_color = SDL_Color(100, 150, 200, 255);
    widget.style.border_radius = 20;
    SDL_SetRenderDrawColor(canvas.renderer, 0, 0, 0, 0);
    SDL_RenderClear(canvas.renderer);
    SDL_BlendMode_ before, after;
    assert(SDL_GetRenderDrawBlendMode(canvas.renderer, &before));
    widget.draw();
    SDL_RenderPresent(canvas.renderer);
    assert(SDL_GetRenderDrawBlendMode(canvas.renderer, &after));
    assert(before == after);
    ubyte r, g, b, a;
    assert(SDL_ReadSurfacePixel(canvas.surface, 2, 2, &r, &g, &b, &a));
    assert(a == 0);
    assert(SDL_ReadSurfacePixel(canvas.surface, 7, 8, &r, &g, &b, &a));
    assert(a > 0 && a < 255);
    assert(SDL_ReadSurfacePixel(canvas.surface, 22, 22, &r, &g, &b, &a));
    assert(r == 100 && g == 150 && b == 200 && a == 255);
}

unittest {
    auto canvas = Canvas(44, 44);
    auto widget = new Widget(SDL_FRect(2, 2, 40, 40), canvas.renderer);
    widget.style.border_color = SDL_Color(255, 80, 40, 255);
    widget.style.border_radius = 12;
    widget.style.border_width = 1;
    widget.style.has_border_width = true;
    SDL_SetRenderDrawColor(canvas.renderer, 0, 0, 0, 0);
    SDL_RenderClear(canvas.renderer);
    SDL_BlendMode_ before, after;
    assert(SDL_GetRenderDrawBlendMode(canvas.renderer, &before));
    widget.draw();
    SDL_RenderPresent(canvas.renderer);
    assert(SDL_GetRenderDrawBlendMode(canvas.renderer, &after));
    assert(before == after);

    int partial;
    foreach (y; 2 .. 14) foreach (x; 2 .. 14) {
        ubyte r, g, b, a;
        assert(SDL_ReadSurfacePixel(canvas.surface, x, y, &r, &g, &b, &a));
        if (a > 0 && a < 255) partial++;
    }
    assert(partial > 0);
    ubyte r, g, b, a;
    assert(SDL_ReadSurfacePixel(canvas.surface, 22, 2, &r, &g, &b, &a));
    assert(a == 255);
    assert(SDL_ReadSurfacePixel(canvas.surface, 2, 2, &r, &g, &b, &a));
    assert(a == 0);
}

unittest {
    auto canvas = Canvas(10, 10);
    auto source = SDL_CreateSurface(2, 2, SDL_PIXELFORMAT_RGBA32);
    assert(source !is null);
    scope(exit) SDL_DestroySurface(source);
    assert(SDL_WriteSurfacePixel(source, 0, 0, 255, 0, 0, 255));
    assert(SDL_WriteSurfacePixel(source, 1, 0, 0, 255, 0, 255));
    assert(SDL_WriteSurfacePixel(source, 0, 1, 0, 0, 255, 255));
    assert(SDL_WriteSurfacePixel(source, 1, 1, 255, 255, 0, 255));
    auto texture = SDL_CreateTextureFromSurface(canvas.renderer, source);
    assert(texture !is null);
    scope(exit) SDL_DestroyTexture(texture);
    assert(SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST));

    auto icon = new Icon(SDL_FRect(2, 3, 4, 4), canvas.renderer, texture);
    canvas.draw(icon);
    int[4] counts;
    canvas.check("icon", (x, y, r, g, b) {
        if (x < 2 || x >= 6 || y < 3 || y >= 7)
            return r == 0 && g == 0 && b == 0;
        int quadrant = (x >= 4 ? 1 : 0) + (y >= 5 ? 2 : 0);
        final switch (quadrant) {
            case 0:
                if (r == 255 && g == 0 && b == 0) counts[0]++;
                return r == 255 && g == 0 && b == 0;
            case 1:
                if (r == 0 && g == 255 && b == 0) counts[1]++;
                return r == 0 && g == 255 && b == 0;
            case 2:
                if (r == 0 && g == 0 && b == 255) counts[2]++;
                return r == 0 && g == 0 && b == 255;
            case 3:
                if (r == 255 && g == 255 && b == 0) counts[3]++;
                return r == 255 && g == 255 && b == 0;
        }
    });
    assert(counts == [4, 4, 4, 4]);

    icon.rect = SDL_FRect(1, 1, 2, 2);
    canvas.draw(icon);
    canvas.check("icon-resized", (x, y, r, g, b) {
        if (x == 1 && y == 1) return r == 255 && g == 0 && b == 0;
        if (x == 2 && y == 1) return r == 0 && g == 255 && b == 0;
        if (x == 1 && y == 2) return r == 0 && g == 0 && b == 255;
        if (x == 2 && y == 2) return r == 255 && g == 255 && b == 0;
        return r == 0 && g == 0 && b == 0;
    });
}

unittest {
    auto canvas = Canvas(100, 50);
    assert(loadSDLTTF() == LoadMsg.success);
    assert(TTF_Init());
    scope(exit) TTF_Quit();
    auto font = TTF_OpenFont("liberation-sans.ttf", 18);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);

    auto label = new Label(SDL_FRect(5, 5, 90, 35), canvas.renderer, font, "A");
    scope(exit) destroy(label);
    assert(label.text_placement == Label.TextPlacement.Center);
    assert(label.text_x == label.rect.x + (label.rect.w - label.text_width) / 2);
    label.text_color = SDL_Color(255, 0, 0, 255);
    label.text_placement = Label.TextPlacement.Start;
    canvas.draw(label);
    int startCount, startX = 100;
    canvas.check("label-start", (x, y, r, g, b) {
        if (r == 0 && g == 0 && b == 0)
            return true;
        startCount++;
        if (x < startX)
            startX = x;
        return r > 0 && g == 0 && b == 0 && x >= 5 && x < 95 && y >= 5 && y < 40;
    });
    assert(startCount > 0);

    label.text_placement = Label.TextPlacement.Center;
    canvas.draw(label);
    int centerCount, centerX = 100;
    canvas.check("label-center", (x, y, r, g, b) {
        if (r == 0 && g == 0 && b == 0)
            return true;
        centerCount++;
        if (x < centerX)
            centerX = x;
        return r > 0 && g == 0 && b == 0 && x >= 5 && x < 95 && y >= 5 && y < 40;
    });
    assert(centerCount == startCount && centerX > startX);

    label.setText("AA");
    label.text_placement = Label.TextPlacement.Start;
    canvas.draw(label);
    int longerCount;
    canvas.check("label-updated", (x, y, r, g, b) {
        if (r == 0 && g == 0 && b == 0)
            return true;
        longerCount++;
        return r > 0 && g == 0 && b == 0 && x >= 5 && x < 95 && y >= 5 && y < 40;
    });
    assert(label.text == "AA" && longerCount > startCount);

    label.rect = SDL_FRect(10, 10, 85, 35);
    canvas.draw(label);
    int movedX = 100;
    canvas.check("label-moved", (x, y, r, g, b) {
        if (r == 0 && g == 0 && b == 0)
            return true;
        if (x < movedX)
            movedX = x;
        return r > 0 && g == 0 && b == 0 && x >= 10 && x < 95 && y >= 10 && y < 45;
    });
    assert(movedX > startX);
}

unittest {
    auto canvas = Canvas(120, 40);
    assert(loadSDLTTF() == LoadMsg.success);
    assert(TTF_Init());
    scope(exit) TTF_Quit();
    auto font = TTF_OpenFont("liberation-sans.ttf", 18);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);

    auto input = new TextInput(SDL_FRect(5, 5, 110, 30), canvas.renderer, font);
    scope(exit) destroy(input);
    SDL_Event event = SDL_Event();
    event.type = SDL_EVENT_KEY_UP;
    event.key.key = SDLK_A;
    input.handleEvent(&event);
    assert(input.text == "");
    event.type = SDL_EVENT_KEY_DOWN;
    event.key.key = SDLK_BACKSPACE;
    input.handleEvent(&event);
    assert(input.text == "");
    event = SDL_Event();
    event.type = SDL_EVENT_TEXT_INPUT;
    event.text.text = "a".toStringz;
    input.handleEvent(&event);
    assert(input.text == "a");
    event.text.text = "A".toStringz;
    input.handleEvent(&event);
    assert(input.text == "aA");
    event.text.text = " ".toStringz;
    input.handleEvent(&event);
    assert(input.text == "aA ");
    event.type = SDL_EVENT_KEY_DOWN;
    event.key.key = SDLK_BACKSPACE;
    input.handleEvent(&event);
    assert(input.text == "aA");

    input.text_color = SDL_Color(0, 255, 255, 255);
    canvas.draw(input);
    int textPixels;
    canvas.check("text-input", (x, y, r, g, b) {
        if (r == 0 && g == 0 && b == 0)
            return true;
        textPixels++;
        return r == 0 && g > 0 && g == b && x >= 5 && x < 115 && y >= 5 && y < 35;
    });
    assert(textPixels > 0);
}

unittest {
    auto canvas = Canvas(150, 45);
    assert(loadSDLTTF() == LoadMsg.success);
    assert(TTF_Init());
    scope(exit) TTF_Quit();
    auto font = TTF_OpenFont("liberation-sans.ttf", 18);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);

    auto label = new Label(SDL_FRect(5, 5, 80, 30), canvas.renderer, font,
            "A long label that exceeds its bounds");
    scope(exit) destroy(label);
    assert(label.text_placement == Label.TextPlacement.Center);
    assert(label.text_x == label.rect.x);
    label.text_color = SDL_Color(255, 0, 0, 255);
    assert(label.text_width > label.rect.w);
    canvas.draw(label);
    assert(!SDL_RenderClipEnabled(canvas.renderer));
    int textPixels;
    canvas.check("label-clipped", (x, y, r, g, b) {
        if (r == 0 && g == 0 && b == 0) return true;
        textPixels++;
        return r > 0 && g == 0 && b == 0 &&
            x >= 5 && x < 85 && y >= 5 && y < 35;
    });
    assert(textPixels > 0);

    SDL_Rect parentClip = SDL_Rect(25, 0, 30, 45);
    assert(SDL_SetRenderClipRect(canvas.renderer, &parentClip));
    canvas.draw(label);
    SDL_Rect restored;
    assert(SDL_RenderClipEnabled(canvas.renderer));
    assert(SDL_GetRenderClipRect(canvas.renderer, &restored));
    assert(restored.x == parentClip.x && restored.w == parentClip.w);
    canvas.check("label-parent-clip", (x, y, r, g, b) {
        if (r == 0 && g == 0 && b == 0) return true;
        return x >= 25 && x < 55 && y >= 5 && y < 35 &&
            r > 0 && g == 0 && b == 0;
    });
    SDL_SetRenderClipRect(canvas.renderer, null);
}

unittest {
    auto canvas = Canvas(120, 80);
    assert(loadSDLTTF() == LoadMsg.success);
    assert(TTF_Init());
    scope(exit) TTF_Quit();
    auto font = TTF_OpenFont("liberation-sans.ttf", 18);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);

    auto source = SDL_CreateSurface(2, 2, SDL_PIXELFORMAT_RGBA32);
    assert(source !is null);
    scope(exit) SDL_DestroySurface(source);
    foreach (y; 0 .. 2)
        foreach (x; 0 .. 2)
            assert(SDL_WriteSurfacePixel(source, x, y, 255, 0, 255, 255));
    auto texture = SDL_CreateTextureFromSurface(canvas.renderer, source);
    assert(texture !is null);
    scope(exit) SDL_DestroyTexture(texture);
    assert(SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST));

    auto icons = new IconList(SDL_FRect(0, 0, 120, 80), canvas.renderer, font, 2, 5);
    scope(exit) foreach (label; icons.labels) destroy(label);
    DesktopEntry entry;
    entry.name = "App".dup;
    entry.icon_texture = texture;
    icons.entries = [entry];
    icons.updateList();
    assert(icons.lists[0].visible && !icons.lists[1].visible);
    assert(icons.labels[0].text == "App" && icons.icons[0].texture is texture);

    canvas.draw(icons);
    int iconPixels, labelPixels;
    int fontHeight = TTF_GetFontHeight(font);
    int nameWidth;
    assert(TTF_GetStringSize(font, "App", 3, &nameWidth, null));
    int iconX = cast(int)(5 + max(5.0f,
                (110.0f - fontHeight - 5 - nameWidth) / 2));
    assert(icons.labels[0].rect.w == nameWidth);
    assert(icons.labels[0].rect.h == fontHeight);
    canvas.check("icon-list", (x, y, r, g, b) {
        bool inIcon = x >= iconX && x < iconX + fontHeight &&
            y >= 10 && y < 10 + fontHeight;
        if (inIcon) {
            if (r == 255 && g == 0 && b == 255)
                iconPixels++;
            return r == 255 && g == 0 && b == 255;
        }
        if (r == 0 && g == 0 && b == 0)
            return true;
        labelPixels++;
        return r == g && g == b && r > 0 &&
            x >= iconX + fontHeight + 5 &&
            x < iconX + fontHeight + 5 + nameWidth &&
            y >= 10 && y < 10 + fontHeight;
    });
    assert(iconPixels == fontHeight * fontHeight && labelPixels > 0);

    DesktopEntry second;
    second.name = "Two".dup;
    second.icon_texture = texture;
    icons.entries = [entry, second];
    icons.updateList();
    assert(icons.lists[0].visible && icons.lists[1].visible);
    assert(icons.labels[1].text == "Two" && icons.icons[1].texture is texture);
    int secondNameWidth;
    assert(TTF_GetStringSize(font, "Two", 3, &secondNameWidth, null));
    int secondIconX = cast(int)(5 + max(5.0f,
                (110.0f - fontHeight - 5 - secondNameWidth) / 2));
    assert(icons.labels[1].rect.w == secondNameWidth);
    canvas.draw(icons);
    int secondIconPixels;
    canvas.check("icon-list-full", (x, y, r, g, b) {
        bool inSecondIcon = x >= secondIconX && x < secondIconX + fontHeight &&
                y >= fontHeight + 25 && y < 2 * fontHeight + 25;
        if (inSecondIcon) {
            if (r == 255 && g == 0 && b == 255)
                secondIconPixels++;
            return r == 255 && g == 0 && b == 255;
        }
        return true;
    });
    assert(secondIconPixels == fontHeight * fontHeight);

    icons.entries = [];
    icons.updateList();
    assert(!icons.lists[0].visible && !icons.lists[1].visible);
    canvas.draw(icons);
    canvas.check("icon-list-empty", (x, y, r, g, b) {
        return r == 0 && g == 0 && b == 0;
    });
}
