module mcw.tests.layout_behavior;

import bindbc.sdl;
import bindbc.loader : LoadMsg;

import mcw.widgets;

private class MoveProbe : Widget {
    int moves;

    this (SDL_FRect rect, SDL_Renderer *renderer) {
        super(rect, renderer);
    }

    override void hasMoved() {
        moves++;
    }
}

private class OverlapContainer : Container {
    this (SDL_FRect rect, SDL_Renderer *renderer) {
        super(rect, renderer, 0, Container.Orientation.Vertical);
    }
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(SDL_Init(0));
    scope(exit) SDL_Quit();

    auto surface = SDL_CreateSurface(30, 20, SDL_PIXELFORMAT_RGBA32);
    assert(surface !is null);
    scope(exit) SDL_DestroySurface(surface);
    auto renderer = SDL_CreateSoftwareRenderer(surface);
    assert(renderer !is null);
    scope(exit) SDL_DestroyRenderer(renderer);

    auto box = new Box(SDL_FRect(0, 0, 20, 20), renderer, 2, Box.Orientation.Vertical);
    auto child = new MoveProbe(SDL_FRect(0, 0, 0, 0), renderer);
    box.addChild(child);
    assert(child.moves == 1);

    box.rect = SDL_FRect(10, 5, 30, 20);
    assert(child.moves == 2);
    assert(child.rect.x == 12 && child.rect.y == 7);
    assert(child.rect.w == 26 && child.rect.h == 16);

    auto overlap = new OverlapContainer(SDL_FRect(0, 0, 20, 20), renderer);
    auto back = new Widget(SDL_FRect(0, 0, 10, 10), renderer);
    auto front = new Widget(SDL_FRect(0, 0, 10, 10), renderer);
    back.style.background_color = SDL_Color(255, 0, 0, 255);
    front.style.background_color = SDL_Color(0, 0, 255, 255);
    overlap.addChild(back);
    overlap.addChild(front);

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    overlap.draw();
    SDL_RenderPresent(renderer);
    ubyte r, g, b, a;
    assert(SDL_ReadSurfacePixel(surface, 5, 5, &r, &g, &b, &a));
    assert(r == 0 && g == 0 && b == 255);

    SDL_Event click = SDL_Event();
    click.type = SDL_EVENT_MOUSE_BUTTON_UP;
    click.button.x = 5;
    click.button.y = 5;
    overlap.handleEvent(&click);
    assert(overlap.focused_child == 1);
    assert(front.focused && !back.focused);

    SDL_Event tab = SDL_Event();
    tab.type = SDL_EVENT_KEY_DOWN;
    tab.key.key = SDLK_TAB;
    overlap.handleEvent(&tab);
    assert(overlap.focused_child == 0 && back.focused && !front.focused);
    assert(tab.type == 0);

    tab = SDL_Event();
    tab.type = SDL_EVENT_KEY_DOWN;
    tab.key.key = SDLK_TAB;
    tab.key.mod = SDL_KMOD_SHIFT;
    overlap.handleEvent(&tab);
    assert(overlap.focused_child == 1 && front.focused && !back.focused);

    front.visible = false;
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    overlap.draw();
    SDL_RenderPresent(renderer);
    assert(SDL_ReadSurfacePixel(surface, 5, 5, &r, &g, &b, &a));
    assert(r == 255 && g == 0 && b == 0);
    overlap.handleEvent(&click);
    assert(overlap.focused_child == 0);
    assert(back.focused && !front.focused);

    overlap.removeChild(0);
    assert(overlap.children.length == 1 && overlap.children[0] is front);
    assert(overlap.focused_child == -1);
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(SDL_Init(0));
    scope(exit) SDL_Quit();

    auto surface = SDL_CreateSurface(32, 32, SDL_PIXELFORMAT_RGBA32);
    assert(surface !is null);
    scope(exit) SDL_DestroySurface(surface);
    auto renderer = SDL_CreateSoftwareRenderer(surface);
    assert(renderer !is null);
    scope(exit) SDL_DestroyRenderer(renderer);

    auto box = new Box(SDL_FRect(0, 0, 20, 20), renderer, 2, Box.Orientation.Vertical);
    box.uniform = false;
    auto first = new Widget(SDL_FRect(0, 0, 0, 4), renderer);
    auto second = new Widget(SDL_FRect(0, 0, 0, 6), renderer);
    box.addChild(first);
    box.addChild(second);
    assert(first.rect.x == 2 && first.rect.y == 2 && first.rect.w == 16 && first.rect.h == 4);
    assert(second.rect.x == 2 && second.rect.y == 8 && second.rect.w == 16 && second.rect.h == 6);

    auto nested = new List(SDL_FRect(0, 0, 10, 10), renderer, 1, List.Orientation.Vertical);
    auto leaf = new Widget(SDL_FRect(0, 0, 0, 3), renderer);
    nested.addChild(leaf);
    box.addChild(nested);
    box.style.background_color = SDL_Color(12, 34, 56, 255);
    box.applyStyleToChildren();
    assert(first.style.background_color.r == 12);
    assert(second.style.background_color.g == 34);
    assert(nested.style.background_color.b == 56);
    assert(leaf.style.background_color.r == 12);

    auto list = new List(SDL_FRect(0, 0, 20, 20), renderer, 2, List.Orientation.Vertical);
    foreach (i; 0 .. 3)
        list.addChild(new Widget(SDL_FRect(0, 0, 0, 3), renderer));
    assert(list.element_size == 3 && list.idealHeight() == 17);
    list.children[1].visible = false;
    list.adjustLayout();
    assert(list.idealHeight() == 12);
    assert(list.children[2].rect.y == 7);
    list.removeChild(0);
    assert(list.children.length == 2 && list.children[1].rect.y == 2);
    list.rect = SDL_FRect(3, 4, 25, 20);
    assert(list.children[1].rect.x == 5 && list.children[1].rect.y == 6);
    assert(list.children[1].rect.w == 21 && list.children[1].rect.h == 3);
}
