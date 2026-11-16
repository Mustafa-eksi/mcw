module mcw.window;

import std.string : toStringz, fromStringz, toLower, StringException;
import std.conv : to;

import bindbc.sdl;

import mcw.widgets.widget;

// Window inheriting widget is a coincidence (or is it?)
class Window : Widget {
    SDL_Window *window;
    SDL_PropertiesID props;
    private Widget _widget;
    bool quit;

    this (SDL_FRect rect, string title) {
        props = SDL_CreateProperties();

        SDL_SetStringProperty(props, SDL_PROP_WINDOW_CREATE_TITLE_STRING, title.toStringz);
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
            case SDL_EVENT_WINDOW_MOUSE_ENTER:
                this.focused = true;
                widget.focused = true;
                break;
            case SDL_EVENT_WINDOW_MOUSE_LEAVE:
                this.focused = false;
                widget.focused = false;
                break;
            case SDL_EVENT_WINDOW_RESIZED:
                rect = SDL_FRect(rect.x, rect.y, event.window.data1, event.window.data2);
                widget.rect = rect;
                break;
            default:
                widget.handleEvent(event);
                break;
        }
    }

    override void draw() {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
        widget.draw();
        SDL_RenderPresent(renderer);
    }

    // Windows with timed work can wake the event loop without redrawing unless
    // that work changed something visible.
    int idleTimeoutMs() { return -1; }
    bool onIdle() { return false; }

    @property void widget(Widget w) {
        _widget = w;
        _widget.rect = rect;
    }

    @property Widget widget() {
        return _widget;
    }

    ~ this() {
        SDL_DestroyProperties(props);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
    }
}
