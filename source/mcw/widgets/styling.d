module mcw.widgets.styling;

import bindbc.sdl;

struct Style {
    SDL_Color background_color, border_color, focused_border_color;
    SDL_Color hover_color, pressed_color, disabled_color;
    SDL_Color text_color, track_color, thumb_color, fill_color, selection_color;
    bool has_text_color, has_track_color, has_thumb_color, has_fill_color,
        has_selection_color, has_border_width;
    int border_width, border_radius;
    int padding_top, padding_right, padding_bottom, padding_left;
    int gap = -1;
}
