import std.conv : to;
import std.math : sin, cos;
import std.range : back, popBack, empty;
import std.algorithm : map;

import bindbc.sdl;

import window;
import widgets;

class ListTestWindow : Window {
    List list;
    Label[] labels;
    TTF_Font *font;
    const int FONT_HEIGHT;

    this (SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title);
        list = new List(rect, renderer, 5, List.Orientation.Horizontal);
        list.style.background_color = SDL_Color(20, 50, 20, 255);
        list.style.border_color = SDL_Color(20, 100, 20, 255);
        this.font = font;

        FONT_HEIGHT = TTF_GetFontHeight(font);
        for (int i = 0; i < 5; i++) {
            labels ~= new Label(SDL_FRect(0, 0, 200, FONT_HEIGHT), renderer,
                    font, (i+10).to!string);
            list.addChild(cast(Widget*)&labels.back);
        }
        list.applyStyleToChildren();
        widget = cast(Widget*)&list;
    }

    override void handleEvent(SDL_Event *event) {
        import std.stdio;
        if (event.type == SDL_EVENT_KEY_UP) {
            if (event.key.key == SDLK_ENTER) {
                labels ~= new Label(SDL_FRect(0, 0, 200, FONT_HEIGHT), renderer,
                        font, (labels.length+100).to!string);
                list.addChild(cast(Widget*)&labels.back);
                list.applyStyleToChildren();
            } else if (event.key.key == SDLK_BACKSPACE) {
                if (labels.empty)
                    return;
                writeln(labels.length.to!int-1);
                list.removeChild(labels.length.to!int-1);
                labels.popBack();
            } else if (event.key.key == SDLK_P) {
                writeln(labels);
                foreach (ch; list.children)
                    write((*cast(Label*)ch).text, ", ");
                writeln();
            }
        }
        this.Window.handleEvent(event);
    }

    override void draw() {
        this.Window.draw();
    }
}
