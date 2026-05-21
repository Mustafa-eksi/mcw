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

    this (SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title);
        entries = indexEntries(renderer);

        FONT_HEIGHT = TTF_GetFontHeight(font);

        text_input = new TextInput(SDL_FRect(0, 0, 400, FONT_HEIGHT), renderer, font);
        icon_list = new IconList(SDL_FRect(0, 0, 400, FONT_HEIGHT*5), renderer, font);
        box = new Box(SDL_FRect(0, 0), renderer, 5, Box.Orientation.Vertical);

        box.addChild(cast(Widget*)&text_input);
        box.addChild(cast(Widget*)&icon_list);
        widget = cast(Widget*)&box;
        writeln("ti: ", text_input.rect, " - il: ", icon_list.rect);

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
        icon_list.entries = findInEntries(entries, text_input.prompt[0..$-1]);
        icon_list.updateList();
        SDL_SetWindowSize(window, cast(int)widget.rect.w, cast(int)widget.rect.h);
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
