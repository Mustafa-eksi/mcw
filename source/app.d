import std.stdio;
import std.string;
import std.uni;
import std.process;
import std.range;
import std.algorithm;

import bindbc.sdl;
import bindbc.loader;

import desktop;

const uint TEXT_FONT_SIZE = 32;
const uint WINDOW_HORIZONTAL_PADDING = 10;
const uint WINDOW_VERTICAL_PADDING = 10;
const uint PROMPT_BOTTOM_MARGIN = 20;

int main(string[] args) {
    LoadMsg ret = loadSDL();
    if(ret != LoadMsg.success) {
      writeln("Error loading SDL dll");
      return -4;
    }

    ret = loadSDLTTF();
    if(ret != LoadMsg.success) {
      writeln("Error loading SDL_ttf dll");
      return -5;
    }

    ret = loadSDLImage();
    if(ret != LoadMsg.success) {
      writeln("Error loading SDL_image dll");
      return -6;
    }

    // TTF initializing and font loading
    if (!TTF_Init()) {
        writeln("TTF init failed");
        return -1;
    }
    scope(exit) TTF_Quit();

    TTF_Font *font = TTF_OpenFont("liberation-sans.ttf", TEXT_FONT_SIZE);
    const int FONT_HEIGHT = TTF_GetFontHeight(font);
    uint WINDOW_HEIGHT = cast(uint)(FONT_HEIGHT*1.5);
    const uint WINDOW_WIDTH = 500;

    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        writeln(SDL_GetError());
        return -1;
    }
    scope(exit) SDL_Quit();

    SDL_PropertiesID props = SDL_CreateProperties();
    scope(exit) SDL_DestroyProperties(props);

    SDL_SetStringProperty(props, SDL_PROP_WINDOW_CREATE_TITLE_STRING, "MCW");
    SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_ALWAYS_ON_TOP_BOOLEAN, true);
    SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_BORDERLESS_BOOLEAN, true);
    SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER,
            WINDOW_WIDTH);
    SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER,
            WINDOW_HEIGHT);
    SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_RESIZABLE_BOOLEAN, true);

    SDL_Window* sdl_window = SDL_CreateWindowWithProperties(
        props
    );
    if (!sdl_window) {
        writeln(SDL_GetError());
        return -2;
    }
    scope(exit) SDL_DestroyWindow(sdl_window);

    SDL_Renderer *renderer = SDL_CreateRenderer(sdl_window, null);
    if (!renderer) {
        writeln(SDL_GetError());
        return -3;
    }
    scope(exit) SDL_DestroyRenderer(renderer);

    DesktopEntry[] entries = indexEntries(renderer);
    // Not actually needed
    scope(exit) {
        entries.map!((DesktopEntry e) {
            if (e.icon_texture)
                SDL_DestroyTexture(e.icon_texture);
            return 0;
        });
    }

    bool quit = false;
    string prompt = "|";
    TTF_TextEngine *text_engine = TTF_CreateRendererTextEngine(renderer);
    TTF_Text *ttf_text = TTF_CreateText(text_engine, font, prompt.toStringz,
            prompt.length);
    string list_str;
    TTF_Text *list_text = TTF_CreateText(text_engine, font, list_str.toStringz,
            list_str.length);
    DesktopEntry[] filtered_entries;
    while (!quit) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
                case SDL_EVENT_QUIT:
                    quit = true;
                    break;
                case SDL_EVENT_WINDOW_RESIZED:
                    // writeln(event.window.data1, " - ", event.window.data2);
                    break;
                case SDL_EVENT_KEY_UP:
                    prompt.length--;
                    if (SDLK_A <= event.key.key && SDLK_Z >= event.key.key) {
                        if (event.key.mod & SDL_KMOD_SHIFT) {
                            prompt ~= SDL_GetKeyName(event.key.key).fromStringz;
                        } else {
                            prompt ~=
                                SDL_GetKeyName(event.key.key).fromStringz.toLower;
                        }
                    } else if (event.key.key == SDLK_BACKSPACE) {
                        if (prompt.length != 0)
                            prompt.length--;
                    } else if (event.key.key == SDLK_ENTER) {
                        auto fe = findInEntries(entries, prompt);
                        if (!fe.empty) {
                            executeShell(fe.front.exec);
                            quit = true;
                        } else {
                            writeln(fe);
                        }
                    } else if (event.key.key == SDLK_SPACE) {
                        prompt ~= ' ';
                    } else if (event.key.key == SDLK_ESCAPE) {
                        quit = true;
                        break;
                    }
                    filtered_entries = findInEntries(entries, prompt);
                    list_str = generateList(filtered_entries);
                    TTF_SetTextString(list_text, list_str.toStringz, list_str.length);
                    SDL_SetWindowSize(sdl_window, cast(int) WINDOW_WIDTH,
                        cast(int)(
                            WINDOW_HEIGHT +
                            PROMPT_BOTTOM_MARGIN +
                            FONT_HEIGHT * filtered_entries.length));
                    prompt ~= "|";
                    TTF_SetTextString(ttf_text, prompt.toStringz, prompt.length);
                    break;
                default: break;
            }
        }
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);

        TTF_DrawRendererText(ttf_text, WINDOW_HORIZONTAL_PADDING,
                WINDOW_VERTICAL_PADDING);
        const int ICON_SIZE = FONT_HEIGHT;
        TTF_DrawRendererText(list_text, WINDOW_HORIZONTAL_PADDING+ICON_SIZE,
                PROMPT_BOTTOM_MARGIN+FONT_HEIGHT);
        foreach (i, fe; filtered_entries) {
            SDL_FRect dstrect = SDL_FRect(WINDOW_HORIZONTAL_PADDING,
                    PROMPT_BOTTOM_MARGIN+FONT_HEIGHT*(i+1), ICON_SIZE, ICON_SIZE);
            SDL_RenderTexture(renderer, fe.icon_texture, null, &dstrect);
        }

        SDL_RenderPresent(renderer);
    }

    return 0;
}
