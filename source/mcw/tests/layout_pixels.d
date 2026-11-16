module mcw.tests.layout_pixels;

import std.file : mkdirRecurse;
import std.path : buildPath;
import std.stdio : File;

import bindbc.sdl;
import bindbc.loader : LoadMsg;

import mcw.widgets;

private void checkPixels(SDL_Surface *surface, string name, bool delegate(int, int, ubyte, ubyte, ubyte) matches) {
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
    assert(matched == surface.w * surface.h, name ~ " pixel mismatch; see test-output/" ~ name ~ ".ppm");
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(SDL_Init(0));
    scope(exit) SDL_Quit();

    auto surface = SDL_CreateSurface(20, 12, SDL_PIXELFORMAT_RGBA32);
    assert(surface !is null);
    scope(exit) SDL_DestroySurface(surface);
    auto renderer = SDL_CreateSoftwareRenderer(surface);
    assert(renderer !is null);
    scope(exit) SDL_DestroyRenderer(renderer);

    auto box = new Box(SDL_FRect(0, 0, 20, 12), renderer, 2, Box.Orientation.Vertical);
    auto first = new Widget(SDL_FRect(0, 0, 0, 0), renderer);
    auto second = new Widget(SDL_FRect(0, 0, 0, 0), renderer);
    first.style.background_color = SDL_Color(255, 0, 0, 255);
    second.style.background_color = SDL_Color(0, 0, 255, 255);
    box.addChild(first);
    box.addChild(second);

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    box.draw();
    SDL_RenderPresent(renderer);

    int red, blue;
    checkPixels(surface, "box", (x, y, r, g, b) {
        if (r == 255 && g == 0 && b == 0)
            red++;
        if (r == 0 && g == 0 && b == 255)
            blue++;
        bool inside = x >= 2 && x < 18;
        if (inside && y >= 2 && y < 5) {
            return r == 255 && g == 0 && b == 0;
        }
        if (inside && y >= 7 && y < 10) {
            return r == 0 && g == 0 && b == 255;
        }
        return r == 0 && g == 0 && b == 0;
    });
    assert(red == 48 && blue == 48);
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(SDL_Init(0));
    scope(exit) SDL_Quit();

    auto surface = SDL_CreateSurface(20, 14, SDL_PIXELFORMAT_RGBA32);
    assert(surface !is null);
    scope(exit) SDL_DestroySurface(surface);
    auto renderer = SDL_CreateSoftwareRenderer(surface);
    assert(renderer !is null);
    scope(exit) SDL_DestroyRenderer(renderer);

    auto list = new List(SDL_FRect(0, 0, 20, 14), renderer, 2, List.Orientation.Vertical);
    foreach (i; 0 .. 3) {
        auto child = new Widget(SDL_FRect(0, 0, 0, 3), renderer);
        child.style.background_color = SDL_Color(0, 255, 0, 255);
        list.addChild(child);
    }
    list.children[1].visible = false;
    list.adjustLayout();

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    list.draw();
    SDL_RenderPresent(renderer);

    int green;
    checkPixels(surface, "list", (x, y, r, g, b) {
        if (r == 0 && g == 255 && b == 0)
            green++;
        bool inside = x >= 2 && x < 18 && ((y >= 2 && y < 5) || (y >= 7 && y < 10));
        if (inside) {
            return r == 0 && g == 255 && b == 0;
        }
        return r == 0 && g == 0 && b == 0;
    });
    assert(green == 96);
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(SDL_Init(0));
    scope(exit) SDL_Quit();

    auto surface = SDL_CreateSurface(20, 12, SDL_PIXELFORMAT_RGBA32);
    assert(surface !is null);
    scope(exit) SDL_DestroySurface(surface);
    auto renderer = SDL_CreateSoftwareRenderer(surface);
    assert(renderer !is null);
    scope(exit) SDL_DestroyRenderer(renderer);

    auto box = new Box(SDL_FRect(0, 0, 20, 12), renderer, 2, Box.Orientation.Horizontal);
    box.uniform = false;
    auto first = new Widget(SDL_FRect(0, 0, 3, 0), renderer);
    auto second = new Widget(SDL_FRect(0, 0, 5, 0), renderer);
    first.style.background_color = SDL_Color(255, 0, 0, 255);
    second.style.background_color = SDL_Color(0, 0, 255, 255);
    box.addChild(first);
    box.addChild(second);

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    box.draw();
    SDL_RenderPresent(renderer);

    int red, blue;
    checkPixels(surface, "box-horizontal", (x, y, r, g, b) {
        if (r == 255 && g == 0 && b == 0)
            red++;
        if (r == 0 && g == 0 && b == 255)
            blue++;
        if (y >= 2 && y < 10 && x >= 2 && x < 5)
            return r == 255 && g == 0 && b == 0;
        if (y >= 2 && y < 10 && x >= 7 && x < 12)
            return r == 0 && g == 0 && b == 255;
        return r == 0 && g == 0 && b == 0;
    });
    assert(red == 24 && blue == 40);
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(SDL_Init(0));
    scope(exit) SDL_Quit();

    auto surface = SDL_CreateSurface(20, 12, SDL_PIXELFORMAT_RGBA32);
    assert(surface !is null);
    scope(exit) SDL_DestroySurface(surface);
    auto renderer = SDL_CreateSoftwareRenderer(surface);
    assert(renderer !is null);
    scope(exit) SDL_DestroyRenderer(renderer);

    auto list = new List(SDL_FRect(0, 0, 20, 12), renderer, 2, List.Orientation.Horizontal);
    foreach (i; 0 .. 3) {
        auto child = new Widget(SDL_FRect(0, 0, 3, 0), renderer);
        child.style.background_color = SDL_Color(0, 255, 0, 255);
        list.addChild(child);
    }
    list.children[1].visible = false;
    list.adjustLayout();

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    list.draw();
    SDL_RenderPresent(renderer);

    int green;
    checkPixels(surface, "list-horizontal", (x, y, r, g, b) {
        if (r == 0 && g == 255 && b == 0)
            green++;
        if (y >= 2 && y < 10 && ((x >= 2 && x < 5) || (x >= 7 && x < 10)))
            return r == 0 && g == 255 && b == 0;
        return r == 0 && g == 0 && b == 0;
    });
    assert(green == 48);
}
