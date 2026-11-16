module mcw.widgets.controls;

import std.algorithm : min, max;
import std.conv : to;

import bindbc.sdl;
import mcw.widgets.widget;
import mcw.widgets.label;

class Button : Label {
    void delegate() onActivate;
    bool pressed;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, string caption) {
        super(rect, renderer, font, caption);
        focusable = true;
    }

    void activate() {
        if (enabled && onActivate !is null) onActivate();
    }

    override void onFocusLost() { pressed = false; }

    override void handleEvent(SDL_Event *event) {
        if (!enabled || !visible || event is null) return;
        if (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN)
            pressed = contains(event.button.x, event.button.y);
        else if (event.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            bool shouldActivate = pressed && contains(event.button.x, event.button.y);
            pressed = false;
            if (shouldActivate) activate();
        } else if (event.type == SDL_EVENT_KEY_DOWN && focused &&
                (event.key.key == SDLK_RETURN || event.key.key == SDLK_KP_ENTER ||
                 event.key.key == SDLK_SPACE)) activate();
    }

    override void draw() {
        if (!visible) return;
        super.draw();
    }

    override bool cssState(string state) {
        return state == "pressed" ? pressed : super.cssState(state);
    }

    override bool showFocusBorder() { return focused && focusVisible; }
}

class CheckBox : Button {
    bool checked;
    void delegate(bool) onToggle;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, string caption,
            bool checked = false) {
        super(rect, renderer, font, caption);
        this.checked = checked;
        text_placement = TextPlacement.Start;
    }

    override void activate() {
        if (!enabled) return;
        checked = !checked;
        if (onToggle !is null) onToggle(checked);
        super.activate();
    }

    override bool cssState(string state) {
        return state == "checked" ? checked : super.cssState(state);
    }

    override protected float textStartOffset() {
        return max(0, 18 - computedStyle().padding_left);
    }

    override void draw() {
        if (!visible) return;
        super.draw();
        SDL_FRect square = SDL_FRect(rect.x + 2, rect.y + (rect.h - 12) / 2, 12, 12);
        auto markColor = effectiveTextColor();
        SDL_SetRenderDrawColor(renderer, markColor.tupleof);
        SDL_RenderRect(renderer, &square);
        if (checked) {
            square.x += 3; square.y += 3; square.w -= 6; square.h -= 6;
            SDL_RenderFillRect(renderer, &square);
        }
    }
}

class RadioGroup {
    RadioButton[] buttons;
    int selected = -1;
    void delegate(int) onChange;

    void add(RadioButton button) {
        buttons ~= button;
        button.group = this;
        button.index = cast(int) buttons.length - 1;
    }

    void select(int index) {
        if (index < 0 || index >= buttons.length || !buttons[index].enabled) return;
        if (selected == index) return;
        selected = index;
        foreach (i, button; buttons) button.checked = i == index;
        if (onChange !is null) onChange(index);
    }
}

class RadioButton : Button {
    RadioGroup group;
    int index = -1;
    bool checked;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, string caption) {
        super(rect, renderer, font, caption);
        text_placement = TextPlacement.Start;
    }

    override void activate() {
        if (!enabled) return;
        if (group !is null) group.select(index);
        else checked = true;
        super.activate();
    }

    override bool cssState(string state) {
        return state == "checked" ? checked : super.cssState(state);
    }

    override protected float textStartOffset() {
        return max(0, 18 - computedStyle().padding_left);
    }

    override void draw() {
        if (!visible) return;
        super.draw();
        SDL_FRect mark = SDL_FRect(rect.x + 2, rect.y + (rect.h - 12) / 2, 12, 12);
        auto markColor = effectiveTextColor();
        SDL_SetRenderDrawColor(renderer, markColor.tupleof);
        SDL_RenderRect(renderer, &mark);
        if (checked) {
            mark.x += 4; mark.y += 4; mark.w = 4; mark.h = 4;
            SDL_RenderFillRect(renderer, &mark);
        }
    }
}

class ComboBox : Button {
    string[] options;
    int selected = -1;
    bool expanded;
    void delegate(int, string) onChange;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, string[] options) {
        super(rect, renderer, font, options.length ? options[0] : "");
        this.options = options.dup;
        if (options.length) selected = 0;
    }

    void select(int index) {
        if (index < 0 || index >= options.length) return;
        selected = index;
        setText(options[index]);
        expanded = false;
        if (onChange !is null) onChange(index, options[index]);
    }

    override void onFocusLost() {
        super.onFocusLost();
        expanded = false;
    }

    override bool contains(float x, float y) {
        return super.contains(x, y) || (expanded && visible && x >= rect.x &&
            x < rect.x + rect.w && y >= rect.y + rect.h &&
            y < rect.y + rect.h * (options.length + 1));
    }

    override void handleEvent(SDL_Event *event) {
        if (!enabled || event is null) return;
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP && expanded &&
                !contains(event.button.x, event.button.y)) {
            expanded = false;
            return;
        }
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP && contains(event.button.x, event.button.y)) {
            if (event.button.y >= rect.y + rect.h && expanded) {
                select(cast(int)((event.button.y - rect.y) / rect.h) - 1);
            } else expanded = !expanded;
        } else if (event.type == SDL_EVENT_KEY_DOWN && focused) {
            if (event.key.key == SDLK_ESCAPE) expanded = false;
            else if (event.key.key == SDLK_RETURN || event.key.key == SDLK_KP_ENTER ||
                    event.key.key == SDLK_SPACE) expanded = !expanded;
            else if (event.key.key == SDLK_DOWN && options.length)
                select((selected + 1) % cast(int) options.length);
            else if (event.key.key == SDLK_UP && options.length)
                select((selected + cast(int) options.length - 1) % cast(int) options.length);
        }
    }

    override void draw() {
        super.draw();
        if (!expanded || !visible) return;
        foreach (i, option; options) {
            SDL_FRect row = SDL_FRect(rect.x, rect.y + rect.h * (i + 1), rect.w, rect.h);
            auto rowColor = computedStyle().background_color;
            SDL_SetRenderDrawColor(renderer, rowColor.tupleof);
            SDL_RenderFillRect(renderer, &row);
            auto t = TTF_CreateText(engine, font, option.ptr, option.length);
            if (t !is null) {
                auto optionColor = effectiveTextColor();
                TTF_SetTextColor(t, optionColor.tupleof);
                TTF_DrawRendererText(t, cast(int)row.x + 3, cast(int)row.y + 2);
                TTF_DestroyText(t);
            }
        }
    }
}

class Slider : Widget {
    double minimum, maximum, value;
    bool dragging;
    void delegate(double) onChange;

    this(SDL_FRect rect, SDL_Renderer *renderer, double minimum = 0,
            double maximum = 1, double value = 0) {
        super(rect, renderer);
        assert(maximum > minimum);
        this.minimum = minimum;
        this.maximum = maximum;
        setValue(value);
    }

    void setValue(double newValue) {
        auto clamped = max(minimum, min(maximum, newValue));
        if (clamped == value) return;
        value = clamped;
        if (onChange !is null) onChange(value);
    }

    private void setFromX(float x) {
        auto fraction = max(0.0, min(1.0, cast(double)(x - rect.x) / rect.w));
        setValue(minimum + fraction * (maximum - minimum));
    }

    override void handleEvent(SDL_Event *event) {
        if (!enabled || event is null) return;
        if (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN && contains(event.button.x, event.button.y)) {
            dragging = true; setFromX(event.button.x);
        } else if (event.type == SDL_EVENT_MOUSE_MOTION && dragging) setFromX(event.motion.x);
        else if (event.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            if (dragging) setFromX(event.button.x);
            dragging = false;
        } else if (event.type == SDL_EVENT_KEY_DOWN && focused) {
            double step = (maximum - minimum) / 100;
            if (event.key.key == SDLK_LEFT || event.key.key == SDLK_DOWN) setValue(value - step);
            else if (event.key.key == SDLK_RIGHT || event.key.key == SDLK_UP) setValue(value + step);
            else if (event.key.key == SDLK_HOME) setValue(minimum);
            else if (event.key.key == SDLK_END) setValue(maximum);
        }
    }

    override void draw() {
        if (!visible) return;
        super.draw();
        auto s = computedStyle();
        auto trackColor = s.has_track_color ? s.track_color : SDL_Color(180, 180, 180, 255);
        SDL_SetRenderDrawColor(renderer, trackColor.tupleof);
        SDL_FRect track = SDL_FRect(rect.x, rect.y + rect.h / 2 - 2, rect.w, 4);
        SDL_RenderFillRect(renderer, &track);
        float x = rect.x + cast(float)((value - minimum) / (maximum - minimum)) * rect.w;
        SDL_FRect thumb = SDL_FRect(x - 4, rect.y, 8, rect.h);
        auto thumbColor = s.has_thumb_color ? s.thumb_color : trackColor;
        SDL_SetRenderDrawColor(renderer, thumbColor.tupleof);
        SDL_RenderFillRect(renderer, &thumb);
    }
}

class ProgressBar : Widget {
    double progress;
    SDL_Color fillColor = SDL_Color(90, 190, 110, 255);

    this(SDL_FRect rect, SDL_Renderer *renderer, double progress = 0) {
        super(rect, renderer);
        focusable = false;
        setProgress(progress);
    }

    void setProgress(double value) { progress = max(0.0, min(1.0, value)); }

    override void draw() {
        if (!visible) return;
        super.draw();
        SDL_FRect fill = SDL_FRect(rect.x, rect.y, rect.w * cast(float)progress, rect.h);
        auto s = computedStyle();
        auto fillTint = s.has_fill_color ? s.fill_color : fillColor;
        SDL_SetRenderDrawColor(renderer, fillTint.tupleof);
        SDL_RenderFillRect(renderer, &fill);
    }
}

class Separator : Widget {
    bool vertical;
    SDL_Color color = SDL_Color(160, 160, 160, 255);

    this(SDL_FRect rect, SDL_Renderer *renderer, bool vertical = false) {
        super(rect, renderer);
        this.vertical = vertical;
        focusable = false;
    }

    override void draw() {
        if (!visible) return;
        auto s = computedStyle();
        auto lineColor = s.has_fill_color ? s.fill_color : color;
        SDL_SetRenderDrawColor(renderer, lineColor.tupleof);
        if (vertical) SDL_RenderLine(renderer, rect.x + rect.w / 2, rect.y,
                rect.x + rect.w / 2, rect.y + rect.h);
        else SDL_RenderLine(renderer, rect.x, rect.y + rect.h / 2,
                rect.x + rect.w, rect.y + rect.h / 2);
    }
}

class Spacer : Widget {
    this(SDL_FRect rect, SDL_Renderer *renderer) {
        super(rect, renderer);
        focusable = false;
    }
    override void draw() {}
}

class Tooltip : Label {
    Widget target;
    float offset = 8;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font,
            string caption, Widget target) {
        super(rect, renderer, font, caption);
        this.target = target;
    }

    bool shown() {
        return target !is null && target.visible &&
            (target.hovered || (target.focused && target.focusVisible));
    }

    override bool contains(float x, float y) { return false; }

    override void draw() {
        if (!shown()) return;
        super.draw();
    }

    override void handleEvent(SDL_Event *event) {
        if (event !is null && event.type == SDL_EVENT_MOUSE_MOTION && target !is null) {
            target.hovered = target.contains(event.motion.x, event.motion.y);
            if (target.hovered)
                rect = SDL_FRect(event.motion.x + offset, event.motion.y + offset, rect.w, rect.h);
        }
    }
}
