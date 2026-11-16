module mcw.widgets.navigation;

import std.algorithm : min, max;
import std.string : toStringz;
import bindbc.sdl;
import mcw.widgets.widget;
import mcw.widgets.container;
import mcw.widgets.list;
import mcw.widgets.label;
import mcw.widgets.controls;

class ListItem : Button {
    bool selected;
    SDL_Color selectionColor = SDL_Color(70, 90, 140, 255);

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font, string text) {
        super(rect, renderer, font, text);
    }

    override bool cssState(string state) {
        return state == "selected" ? selected : super.cssState(state);
    }

    override void draw() {
        if (!visible) return;
        auto saved = style.background_color;
        if (selected) style.background_color = selectionColor;
        scope(exit) style.background_color = saved;
        super.draw();
    }
}

class SelectableList : List {
    int selectedIndex = -1;
    void delegate(int) onSelection;
    void delegate(int) onActivate;

    this(SDL_FRect rect, SDL_Renderer *renderer, int spacing = 0) {
        super(rect, renderer, spacing, Orientation.Vertical);
    }

    void select(int index) {
        if (index < 0 || index >= children.length || !children[index].visible ||
                !children[index].enabled) return;
        if (selectedIndex >= 0 && selectedIndex < children.length) {
            if (auto oldItem = cast(ListItem) children[selectedIndex]) oldItem.selected = false;
            children[selectedIndex].focused = false;
        }
        selectedIndex = index;
        focused_child = index;
        children[index].focused = true;
        children[index].focusVisible = false;
        if (auto item = cast(ListItem) children[index]) item.selected = true;
        if (onSelection !is null) onSelection(index);
    }

    void clearSelection() {
        if (selectedIndex >= 0 && selectedIndex < children.length) {
            children[selectedIndex].focused = false;
            if (auto item = cast(ListItem) children[selectedIndex])
                item.selected = false;
        }
        selectedIndex = -1;
        focused_child = -1;
    }

    override void removeChild(int index) {
        if (index == selectedIndex) selectedIndex = -1;
        else if (index < selectedIndex) selectedIndex--;
        super.removeChild(index);
    }

    override void handleEvent(SDL_Event *event) {
        if (!enabled || event is null) return;
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            foreach (i, child; children)
                if (child.enabled && child.contains(event.button.x, event.button.y)) {
                    select(cast(int)i);
                    if (onActivate !is null) onActivate(cast(int)i);
                    return;
                }
        }
        if (event.type == SDL_EVENT_KEY_DOWN) {
            if (event.key.key == SDLK_DOWN || event.key.key == SDLK_UP) {
                int step = event.key.key == SDLK_DOWN ? 1 : -1;
                int candidate = selectedIndex < 0 ?
                    (step > 0 ? -1 : cast(int)children.length) : selectedIndex;
                foreach (_; 0 .. children.length) {
                    candidate = (candidate + step + cast(int)children.length) % cast(int)children.length;
                    if (children[candidate].visible && children[candidate].enabled) {
                        select(candidate);
                        children[candidate].focusVisible = true;
                        break;
                    }
                }
                return;
            }
            if ((event.key.key == SDLK_RETURN || event.key.key == SDLK_KP_ENTER) &&
                    selectedIndex >= 0 && onActivate !is null) {
                onActivate(selectedIndex);
                return;
            }
        }
        super.handleEvent(event);
    }
}

class Tabs : Container {
    string[] titles;
    TTF_Font *font;
    int selected = -1;
    float headerHeight = 28;
    void delegate(int) onChange;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font) {
        super(rect, renderer, 0, Orientation.Horizontal);
        this.font = font;
    }

    void addTab(string title, Widget panel) {
        titles ~= title;
        children ~= panel;
        if (selected < 0) selected = 0;
        adjustLayout();
    }

    void select(int index) {
        if (index < 0 || index >= children.length || selected == index) return;
        selected = index;
        if (onChange !is null) onChange(index);
    }

    override void adjustLayout() {
        foreach (panel; children)
            panel.rect = SDL_FRect(rect.x, rect.y + headerHeight, rect.w,
                    max(0.0f, rect.h - headerHeight));
    }

    override void handleEvent(SDL_Event *event) {
        if (!enabled || event is null) return;
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP && titles.length &&
                event.button.y >= rect.y && event.button.y < rect.y + headerHeight &&
                event.button.x >= rect.x && event.button.x < rect.x + rect.w) {
            select(min(cast(int)titles.length - 1,
                cast(int)((event.button.x - rect.x) / (rect.w / titles.length))));
        } else if (event.type == SDL_EVENT_KEY_DOWN && focused &&
                (event.key.key == SDLK_LEFT || event.key.key == SDLK_RIGHT) && titles.length) {
            select((selected + (event.key.key == SDLK_RIGHT ? 1 :
                cast(int)titles.length - 1)) % cast(int)titles.length);
        } else if (selected >= 0) children[selected].handleEvent(event);
    }

    override void draw() {
        if (!visible) return;
        this.Widget.draw();
        auto tabStyle = computedStyle();
        foreach (i, title; titles) {
            SDL_FRect tab = SDL_FRect(rect.x + rect.w * i / titles.length,
                    rect.y, rect.w / titles.length, headerHeight);
            SDL_Color tabColor = i == selected ?
                (tabStyle.has_selection_color ? tabStyle.selection_color :
                    SDL_Color(90, 90, 120, 255)) :
                (styleSheet !is null && tabStyle.background_color.a != 0 ?
                    tabStyle.background_color : SDL_Color(55, 55, 70, 255));
            SDL_SetRenderDrawColor(renderer, tabColor.tupleof);
            SDL_RenderFillRect(renderer, &tab);
            auto engine = TTF_CreateRendererTextEngine(renderer);
            auto t = TTF_CreateText(engine, font, title.toStringz, title.length);
            if (t !is null) {
                if (tabStyle.has_text_color)
                    TTF_SetTextColor(t, tabStyle.text_color.tupleof);
                TTF_DrawRendererText(t, cast(int)tab.x + 4, cast(int)tab.y + 3);
                TTF_DestroyText(t);
            }
            TTF_DestroyRendererTextEngine(engine);
        }
        if (selected >= 0 && children[selected].visible) children[selected].draw();
    }
}

class MenuItem : Button {
    string shortcut;
    SDL_KeyCode shortcutKey;
    SDL_KeyMod shortcutModifiers;
    Menu submenu;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font,
            string caption, string shortcut = "") {
        super(rect, renderer, font, caption);
        this.shortcut = shortcut;
        text_placement = TextPlacement.Start;
    }

    void setShortcut(SDL_KeyCode key, SDL_KeyMod modifiers) {
        shortcutKey = key;
        shortcutModifiers = modifiers;
    }

    void setSubmenu(Menu value) {
        submenu = value;
        if (submenu !is null)
            submenu.rect = SDL_FRect(rect.x + rect.w, rect.y,
                    submenu.rect.w, submenu.rect.h);
    }

    override void hasMoved() {
        super.hasMoved();
        if (submenu !is null)
            submenu.rect = SDL_FRect(rect.x + rect.w, rect.y,
                    submenu.rect.w, submenu.rect.h);
    }
}

class Menu : List {
    bool open;
    int activeIndex = -1;
    void delegate(int) onPick;

    this(SDL_FRect rect, SDL_Renderer *renderer, int spacing = 0) {
        super(rect, renderer, spacing, Orientation.Vertical);
    }

    void addItem(MenuItem item) { addChild(item); }

    void close() {
        open = false;
        if (activeIndex >= 0 && activeIndex < children.length)
            children[activeIndex].focused = false;
        activeIndex = -1;
        foreach (child; children) {
            auto item = cast(MenuItem) child;
            if (item !is null && item.submenu !is null) item.submenu.close();
        }
    }

    private void activateItem(int index) {
        if (index < 0 || index >= children.length) return;
        auto item = cast(MenuItem) children[index];
        if (item is null || !item.enabled || !item.visible) return;
        if (item.submenu !is null) {
            item.submenu.open = true;
            return;
        }
        item.activate();
        if (onPick !is null) onPick(index);
        close();
    }

    private void moveSelection(int step) {
        if (children.length == 0) return;
        int candidate = activeIndex < 0 ?
            (step > 0 ? -1 : cast(int)children.length) : activeIndex;
        foreach (_; 0 .. children.length) {
            candidate = (candidate + step + cast(int)children.length) % cast(int)children.length;
            if (children[candidate].enabled && children[candidate].visible) {
                if (activeIndex >= 0) children[activeIndex].focused = false;
                activeIndex = candidate;
                children[activeIndex].focused = true;
                children[activeIndex].focusVisible = true;
                return;
            }
        }
    }

    override bool contains(float x, float y) {
        if (super.contains(x, y)) return true;
        foreach (child; children) {
            auto item = cast(MenuItem) child;
            if (item !is null && item.submenu !is null && item.submenu.open &&
                    item.submenu.contains(x, y)) return true;
        }
        return false;
    }

    override void handleEvent(SDL_Event *event) {
        if (!enabled || event is null) return;
        if (event.type == SDL_EVENT_KEY_DOWN) {
            foreach (child; children) {
                auto item = cast(MenuItem) child;
                if (item !is null && item.shortcutKey != 0 &&
                        event.key.key == item.shortcutKey &&
                        (event.key.mod & item.shortcutModifiers) == item.shortcutModifiers) {
                    item.activate();
                    close();
                    return;
                }
            }
        }
        if (!open) return;
        foreach (child; children) {
            auto item = cast(MenuItem) child;
            if (item !is null && item.submenu !is null && item.submenu.open) {
                if (event.type == SDL_EVENT_MOUSE_BUTTON_UP &&
                        item.submenu.contains(event.button.x, event.button.y)) {
                    item.submenu.handleEvent(event);
                    if (!item.submenu.open) close();
                    return;
                }
                if (event.type == SDL_EVENT_KEY_DOWN) {
                    if (event.key.key == SDLK_ESCAPE) {
                        item.submenu.close();
                        return;
                    }
                    item.submenu.handleEvent(event);
                    if (!item.submenu.open) close();
                    return;
                }
            }
        }
        if (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE) {
            close();
            return;
        }
        if (event.type == SDL_EVENT_KEY_DOWN) {
            if (event.key.key == SDLK_DOWN || event.key.key == SDLK_UP) {
                moveSelection(event.key.key == SDLK_DOWN ? 1 : -1);
                return;
            }
            if (event.key.key == SDLK_RETURN || event.key.key == SDLK_KP_ENTER ||
                    event.key.key == SDLK_SPACE) {
                activateItem(activeIndex);
                return;
            }
        }
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            foreach (i, child; children) if (child.contains(event.button.x, event.button.y)) {
                activateItem(cast(int)i);
                return;
            }
        }
        super.handleEvent(event);
    }

    override void draw() {
        if (open && visible) {
            super.draw();
            foreach (child; children) {
                auto item = cast(MenuItem) child;
                if (item !is null && item.submenu !is null) item.submenu.draw();
            }
        }
    }
}
