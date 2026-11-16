module mcw.apps.dialog;

import bindbc.sdl;

import mcw.window;
import mcw.widgets;

class DialogExampleWindow : Window {
    Box main_box;
    Box button_box;
    Label title_label;
    Label message_label;
    TextInput text_input;
    Button ok_button;
    Button cancel_button;
    int FONT_HEIGHT;

    this (SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title);

        FONT_HEIGHT = TTF_GetFontHeight(font);

        main_box = new Box(rect, renderer, 8, Box.Orientation.Vertical);
        main_box.uniform = false;
        main_box.style.background_color = SDL_Color(30, 30, 36, 255);
        main_box.style.border_color = SDL_Color(70, 70, 90, 255);
        main_box.style.focused_border_color = SDL_Color(120, 90, 200, 255);

        title_label = new Label(SDL_FRect(0, 0, rect.w, FONT_HEIGHT + 8),
                renderer, font, "Example dialog");
        message_label = new Label(SDL_FRect(0, 0, rect.w, FONT_HEIGHT + 8),
                renderer, font, "Enter a value, then press Enter or Escape.");
        text_input = new TextInput(SDL_FRect(0, 0, rect.w, FONT_HEIGHT + 8),
                renderer, font);

        button_box = new Box(SDL_FRect(0, 0, rect.w, FONT_HEIGHT + 16),
                renderer, 8, Box.Orientation.Horizontal);
        ok_button = new Button(SDL_FRect(0, 0, 100, FONT_HEIGHT + 8),
                renderer, font, "OK");
        cancel_button = new Button(SDL_FRect(0, 0, 100, FONT_HEIGHT + 8),
                renderer, font, "Cancel");
        ok_button.onActivate = () { quit = true; };
        cancel_button.onActivate = () { quit = true; };

        button_box.addChild(ok_button);
        button_box.addChild(cancel_button);

        main_box.addChild(title_label);
        main_box.addChild(message_label);
        main_box.addChild(text_input);
        main_box.addChild(button_box);
        main_box.applyStyleToChildren();

        widget = main_box;
        main_box.focused = true;
        main_box.focused_child = 2;
        text_input.focused = true;
        SDL_StartTextInput(window);
    }

    override void handleEvent(SDL_Event *event) {
        this.Window.handleEvent(event);
        if (event.type == SDL_EVENT_KEY_DOWN &&
                (event.key.key == SDLK_ENTER || event.key.key == SDLK_ESCAPE))
            quit = true;
    }
}
