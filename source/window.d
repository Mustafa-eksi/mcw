import std.string : toStringz, fromStringz, toLower, StringException;
import std.conv : to;

import bindbc.sdl;

import widget;

// Window inheriting widget is a coincidence (or is it?)
class Window : Widget {
    SDL_Window *window;
    SDL_PropertiesID props;
    Widget *widget;
    bool quit;

    this (SDL_FRect rect, string title) {
        props = SDL_CreateProperties();

        SDL_SetStringProperty(props, SDL_PROP_WINDOW_CREATE_TITLE_STRING, title.toStringz);
        // FIXME: These are opinionated configurations:
        SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_ALWAYS_ON_TOP_BOOLEAN, true);
        SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN, true);
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, rect.w.to!int);
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, rect.h.to!int);
        SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_RESIZABLE_BOOLEAN, true);

        window = SDL_CreateWindowWithProperties(props);
        if (!window)
            throw new StringException(SDL_GetError.to!string);

        renderer = SDL_CreateRenderer(window, null);
        if (!renderer)
            throw new StringException(SDL_GetError.to!string);

        super(rect, renderer);
    }

    override void handleEvent(SDL_Event *event) {
        switch (event.type) {
            case SDL_EVENT_QUIT:
                quit = true;
                break;
            case SDL_EVENT_WINDOW_RESIZED:
                // writeln(event.window.data1, " - ", event.window.data2);
                break;
            case SDL_EVENT_KEY_UP:
                if (event.key.key == SDLK_ESCAPE) {
                    quit = true;
                    break;
                }
                widget.handleEvent(event);
                break;
            default: break;
        }
    }

    override void draw() {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
        widget.draw();
        SDL_RenderPresent(renderer);
    }

    ~ this() {
        SDL_DestroyProperties(props);
        SDL_DestroyWindow(window);
        SDL_DestroyRenderer(renderer);
    }
}
