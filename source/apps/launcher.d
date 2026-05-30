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
        SDL_SetWindowAlwaysOnTop(window, true);
        SDL_SetWindowBordered(window, false);

        entries = indexEntries(renderer);

        FONT_HEIGHT = TTF_GetFontHeight(font);
        int window_width, window_height;
        SDL_GetWindowSize(window, &window_width, &window_height);

        text_input = new TextInput(SDL_FRect(0, 0, 0, FONT_HEIGHT), renderer, font);
        icon_list = new IconList(SDL_FRect(0, 0, rect.w, FONT_HEIGHT), renderer,
                font, 4, spacing);
        box = new Box(SDL_FRect(0, 0, window_width, window_height), renderer,
                spacing, Box.Orientation.Vertical);
        // box.style.background_color = SDL_Color(50, 20, 20, 255);
        // box.style.border_color = SDL_Color(100, 20, 20, 255);
        box.uniform = false;

        box.addChild(cast(Widget*)&text_input);
        box.addChild(cast(Widget*)&icon_list);
        box.applyStyleToChildren();
        widget = cast(Widget*)&box;
        icon_list.updateList();
    }

    override void handleEvent(SDL_Event *event) {
        string ti_s = text_input.text;
        this.Window.handleEvent(event);
        if (event.key.key == SDLK_ENTER) {
            auto fe = findInEntries(entries, text_input.text[0..$-1]);
            if (!fe.empty) {
                executeShell(fe.front.exec);
                quit = true;
            } else {
                // writeln(fe);
            }
            return;
        }
        if (ti_s != text_input.text) {
            icon_list.entries = findInEntries(entries, text_input.text[0..$-1]);
            icon_list.updateList();
            box.rect.h = text_input.rect.h + icon_list.list.idealHeight() +
                spacing * 3;
            SDL_SetWindowSize(window, cast(int)box.rect.w, cast(int)box.rect.h);
            icon_list.rect.h = icon_list.list.idealHeight();
            icon_list.list.rect.h = icon_list.list.idealHeight();
            box.adjustLayout();
        }
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
