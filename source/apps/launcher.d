import std.stdio : writeln;
import std.range : empty, front;
import std.process : executeShell;
import std.algorithm.iteration : map;

import bindbc.sdl;

import desktop;
import window;
import widgets;

class Launcher : Window {
    DesktopEntry[] entries, filtered_entries;
    TextInput text_input;
    IconList icon_list;
    Box box;
    int FONT_HEIGHT;
    int spacing = 10;

    this (SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title);
        SDL_SetWindowBordered(window, false);

        entries = indexEntries(renderer);

        FONT_HEIGHT = TTF_GetFontHeight(font);
        int window_width, window_height;
        SDL_GetWindowSize(window, &window_width, &window_height);

        text_input = new TextInput(SDL_FRect(0, 0, 0, FONT_HEIGHT), renderer, font);
        icon_list = new IconList(SDL_FRect(0, 0, 0, FONT_HEIGHT), renderer, font);
        box = new Box(SDL_FRect(0, 0, window_width, window_height), renderer,
                spacing, Box.Orientation.Vertical);
        box.uniform = false;

        box.addChild(cast(Widget*)&text_input);
        box.addChild(cast(Widget*)&icon_list);
        box.applyStyleToChildren();
        widget = cast(Widget*)&box;
    }

    override void handleEvent(SDL_Event *event) {
        if (event.key.key == SDLK_ENTER) {
            auto fe = findInEntries(entries, text_input.prompt[0..$-1]);
            if (!fe.empty) {
                executeShell(fe.front.exec);
                quit = true;
            } else {
                // writeln(fe);
            }
            return;
        }
        if (event.type == SDL_EVENT_KEY_UP) {
            icon_list.entries = findInEntries(entries, text_input.prompt[0..$-1]);
            icon_list.updateList();
            icon_list.rect.h = FONT_HEIGHT * icon_list.entries.length;
            box.rect.h = text_input.rect.h + FONT_HEIGHT *
                icon_list.entries.length + spacing*3;
            SDL_SetWindowSize(window, cast(int)box.rect.w, cast(int)box.rect.h);
            box.adjustLayout();
        }
        this.Window.handleEvent(event);
    }

    override void draw() {
        this.Window.draw();
    }

    ~this () {
        entries.map!((DesktopEntry e) {
            if (e.icon_texture)
                SDL_DestroyTexture(e.icon_texture);
            return 0;
        });
    }
}
