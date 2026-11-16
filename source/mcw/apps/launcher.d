module mcw.apps.launcher;

import std.stdio : writeln;
import std.range : empty, front;
import std.process : executeShell;
import std.algorithm.iteration : map;
import std.conv : to;

import bindbc.sdl;

import mcw.desktop;
import mcw.window;
import mcw.widgets;

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
        SDL_StartTextInput(window);
        icon_list = new IconList(SDL_FRect(0, 0, rect.w, FONT_HEIGHT), renderer,
                font, 5, spacing);
        box = new Box(SDL_FRect(0, 0, window_width, window_height), renderer,
                spacing, Box.Orientation.Vertical);
        // box.style.background_color = SDL_Color(50, 20, 20, 255);
        // box.style.border_color = SDL_Color(100, 20, 20, 255);
        box.style.focused_border_color = SDL_Color(100, 50, 200, 255);
        box.uniform = false;

        box.addChild(text_input);
        box.addChild(icon_list);
        box.applyStyleToChildren();
        widget = box;
        icon_list.updateList();
        box.focused = true;
        text_input.focused = true;
        box.focused_child = 0;
    }

    override void handleEvent(SDL_Event *event) {
        string ti_s = text_input.text;
        this.Window.handleEvent(event);

        if (ti_s != text_input.text)
            updateMatches();

        if (event.type != SDL_EVENT_KEY_DOWN)
            return;

        if (event.key.key == SDLK_DOWN || event.key.key == SDLK_UP) {
            if (!icon_list.entries.empty)
                icon_list.handleEvent(event);
            return;
        }
        if (event.key.key == SDLK_ENTER) {
            auto fe = findInEntries(entries, text_input.text);
            if (!fe.empty) {
                int selected = icon_list.selectedIndex;
                if (selected >= 0 && selected < icon_list.entries.length)
                    executeShell(icon_list.entries[selected].exec);
                else
                    executeShell(fe.front.exec);
                quit = true;
            } else {
                // writeln(fe);
            }
            return;
        }
        if (event.key.key == SDLK_ESCAPE) {
            quit = true;
            return;
        }
    }

    private void updateMatches() {
        icon_list.clearSelection();
        icon_list.entries = findInEntries(entries, text_input.text);
        icon_list.updateList();
        SDL_FRect icon_rect = icon_list.rect;
        icon_rect.h = icon_list.idealHeight();
        icon_list.rect = icon_rect;
        SDL_FRect box_rect = box.rect;
        box_rect.h = text_input.rect.h + icon_rect.h + spacing * 3;
        box.rect = box_rect;
        SDL_SetWindowSize(window, cast(int)box_rect.w, cast(int)box_rect.h);
    }

    override void draw() {
        this.Window.draw();
    }

    ~this () {
        foreach (ref DesktopEntry e; entries) {
            if (e.icon_texture)
                SDL_DestroyTexture(e.icon_texture);
        }
    }
}
