module mcw.widgets.text_input;

import std.algorithm : min, max;
import std.string : toStringz, fromStringz;

import bindbc.sdl;
import mcw.widgets.label;

class TextInput : Label {
    size_t cursor;
    size_t anchor;
    float scrollX = 0;
    bool draggingSelection;
    void delegate(string) onChange;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font) {
        super(rect, renderer, font, "");
        focusable = true;
        text_placement = TextPlacement.Start;
    }

    private size_t previous(size_t at) {
        if (at == 0) return 0;
        at--;
        while (at > 0 && (cast(ubyte) text[at] & 0xC0) == 0x80) at--;
        return at;
    }

    private size_t next(size_t at) {
        if (at >= text.length) return text.length;
        at++;
        while (at < text.length && (cast(ubyte) text[at] & 0xC0) == 0x80) at++;
        return at;
    }

    private void changed(string value) {
        setText(value);
        if (onChange !is null) onChange(text);
    }

    void setValue(string value) {
        changed(value);
        cursor = anchor = text.length;
        keepCursorVisible();
    }

    private void replaceSelection(string value) {
        auto lo = min(cursor, anchor);
        auto hi = max(cursor, anchor);
        changed(text[0 .. lo] ~ value ~ text[hi .. $]);
        cursor = anchor = lo + value.length;
        keepCursorVisible();
    }

    private int prefixWidth(size_t end) {
        int width;
        auto prefix = text[0 .. end];
        TTF_GetStringSize(font, prefix.toStringz, prefix.length, &width, null);
        return width;
    }

    private void keepCursorVisible() {
        auto s = computedStyle();
        float caret = prefixWidth(cursor);
        float available = max(0.0f, rect.w - s.padding_left - s.padding_right - 2);
        if (caret - scrollX > available) scrollX = caret - available;
        if (caret < scrollX) scrollX = caret;
        scrollX = min(scrollX, max(0.0f, cast(float) text_width - available));
        text_x = rect.x + s.padding_left - scrollX;
        text_y = rect.y + s.padding_top;
    }

    override void hasMoved() {
        super.hasMoved();
        keepCursorVisible();
    }

    private size_t cursorAt(float x) {
        auto s = computedStyle();
        size_t best;
        float distance = float.max;
        for (size_t at = 0; at <= text.length; at = next(at)) {
            float candidate = rect.x + s.padding_left + prefixWidth(at) - scrollX;
            float delta = candidate > x ? candidate - x : x - candidate;
            if (delta < distance) { best = at; distance = delta; }
            if (at == text.length) break;
        }
        return best;
    }

    override void draw() {
        if (!visible) return;
        keepCursorVisible();
        auto s = computedStyle();
        SDL_Rect previous;
        bool hadClip = SDL_RenderClipEnabled(renderer);
        if (hadClip) SDL_GetRenderClipRect(renderer, &previous);
        SDL_Rect clip = SDL_Rect(cast(int)rect.x, cast(int)rect.y,
                cast(int)rect.w, cast(int)rect.h);
        if (hadClip) {
            int x = max(clip.x, previous.x), y = max(clip.y, previous.y);
            int right = min(clip.x + clip.w, previous.x + previous.w);
            int bottom = min(clip.y + clip.h, previous.y + previous.h);
            clip = SDL_Rect(x, y, max(0, right - x), max(0, bottom - y));
        }
        SDL_SetRenderClipRect(renderer, &clip);
        scope(exit) {
            if (hadClip) SDL_SetRenderClipRect(renderer, &previous);
            else SDL_SetRenderClipRect(renderer, null);
        }
        this.Widget.draw();
        if (focused && cursor != anchor) {
            auto lo = min(cursor, anchor), hi = max(cursor, anchor);
            SDL_FRect selected = SDL_FRect(rect.x + s.padding_left + prefixWidth(lo) - scrollX,
                    rect.y + s.padding_top, prefixWidth(hi) - prefixWidth(lo),
                    rect.h - s.padding_top - s.padding_bottom);
            auto selection = s.has_selection_color ? s.selection_color :
                SDL_Color(60, 95, 170, 255);
            SDL_SetRenderDrawColor(renderer, selection.tupleof);
            SDL_RenderFillRect(renderer, &selected);
        }
        auto textColor = effectiveTextColor();
        TTF_SetTextColor(ttf_text, textColor.tupleof);
        TTF_DrawRendererText(ttf_text, cast(int)text_x, cast(int)text_y);
        if (!focused) return;
        SDL_Color color = textColor;
        SDL_SetRenderDrawColor(renderer, color.tupleof);
        float x = rect.x + s.padding_left + prefixWidth(cursor) - scrollX;
        SDL_RenderLine(renderer, x, rect.y + s.padding_top + 2,
            x, rect.y + rect.h - s.padding_bottom - 2);
    }

    override void handleEvent(SDL_Event *event) {
        if (!enabled || event is null) return;
        if (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN && contains(event.button.x, event.button.y)) {
            cursor = cursorAt(event.button.x);
            if (!(SDL_GetModState() & SDL_KMOD_SHIFT)) anchor = cursor;
            draggingSelection = true;
            keepCursorVisible();
            return;
        }
        if (event.type == SDL_EVENT_MOUSE_MOTION && draggingSelection) {
            cursor = cursorAt(event.motion.x);
            keepCursorVisible();
            return;
        }
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            draggingSelection = false;
            return;
        }
        if (event.type == SDL_EVENT_TEXT_INPUT) {
            if (event.text.text !is null)
                replaceSelection(event.text.text.fromStringz.idup);
            return;
        }
        if (event.type != SDL_EVENT_KEY_DOWN) return;
        bool ctrl = (event.key.mod & SDL_KMOD_CTRL) != 0;
        bool shift = (event.key.mod & SDL_KMOD_SHIFT) != 0;
        switch (event.key.key) {
        case SDLK_LEFT:
            cursor = previous(cursor);
            if (!shift) anchor = cursor;
            break;
        case SDLK_RIGHT:
            cursor = next(cursor);
            if (!shift) anchor = cursor;
            break;
        case SDLK_HOME:
            cursor = 0;
            if (!shift) anchor = cursor;
            break;
        case SDLK_END:
            cursor = text.length;
            if (!shift) anchor = cursor;
            break;
        case SDLK_BACKSPACE:
            if (cursor != anchor) replaceSelection("");
            else if (cursor > 0) {
                anchor = previous(cursor);
                replaceSelection("");
            }
            break;
        case SDLK_DELETE:
            if (cursor != anchor) replaceSelection("");
            else if (cursor < text.length) {
                anchor = next(cursor);
                replaceSelection("");
            }
            break;
        case SDLK_A:
            if (ctrl) { anchor = 0; cursor = text.length; }
            break;
        case SDLK_C:
            if (ctrl && cursor != anchor) {
                auto selected = text[min(cursor, anchor) .. max(cursor, anchor)];
                SDL_SetClipboardText(selected.toStringz);
            }
            break;
        case SDLK_X:
            if (ctrl && cursor != anchor) {
                auto selected = text[min(cursor, anchor) .. max(cursor, anchor)];
                SDL_SetClipboardText(selected.toStringz);
                replaceSelection("");
            }
            break;
        case SDLK_V:
            if (ctrl) {
                auto value = SDL_GetClipboardText();
                if (value !is null) {
                    replaceSelection(value.fromStringz.idup);
                    SDL_free(value);
                }
            }
            break;
        default: break;
        }
        keepCursorVisible();
    }
}
