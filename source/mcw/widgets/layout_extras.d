module mcw.widgets.layout_extras;

import std.algorithm : min, max;
import bindbc.sdl;
import mcw.widgets.widget;
import mcw.widgets.container;

class Canvas : Container {
    private struct Placement {
        Widget child;
        float left, top, right, bottom, width, height;
        bool anchorRight, anchorBottom;
    }
    private Placement[] placements;

    this(SDL_FRect rect, SDL_Renderer *renderer) {
        super(rect, renderer, 0, Orientation.Vertical);
    }

    void addAnchored(Widget child, bool right = false, bool bottom = false) {
        auto bounds = child.rect;
        Placement p;
        p.child = child;
        p.left = bounds.x - rect.x;
        p.top = bounds.y - rect.y;
        p.right = rect.x + rect.w - bounds.x - bounds.w;
        p.bottom = rect.y + rect.h - bounds.y - bounds.h;
        p.width = bounds.w; p.height = bounds.h;
        p.anchorRight = right; p.anchorBottom = bottom;
        placements ~= p;
        super.addChild(child);
    }

    override void adjustLayout() {
        foreach (p; placements) {
            p.child.rect = SDL_FRect(
                p.anchorRight ? rect.x + rect.w - p.right - p.width : rect.x + p.left,
                p.anchorBottom ? rect.y + rect.h - p.bottom - p.height : rect.y + p.top,
                p.width, p.height);
        }
    }

    override void removeChild(int index) {
        auto child = children[index];
        foreach (i, p; placements) if (p.child is child) {
            import std.algorithm : remove;
            placements = placements.remove(i);
            break;
        }
        super.removeChild(index);
    }
}

class ScrollView : Container {
    Widget content;
    float contentWidth = 0, contentHeight = 0;
    float scrollX = 0, scrollY = 0;
    float wheelStep = 24;

    this(SDL_FRect rect, SDL_Renderer *renderer) {
        super(rect, renderer, 0, Orientation.Vertical);
    }

    void setContent(Widget widget, float width, float height) {
        children.length = 0;
        content = widget;
        contentWidth = width;
        contentHeight = height;
        if (widget !is null) children ~= widget;
        setScroll(scrollX, scrollY);
    }

    void setScroll(float x, float y) {
        scrollX = max(0.0f, min(x, max(0.0f, contentWidth - rect.w)));
        scrollY = max(0.0f, min(y, max(0.0f, contentHeight - rect.h)));
        adjustLayout();
    }

    override void adjustLayout() {
        if (content !is null)
            content.rect = SDL_FRect(rect.x - scrollX, rect.y - scrollY,
                max(rect.w, contentWidth), max(rect.h, contentHeight));
    }

    override void handleEvent(SDL_Event *event) {
        if (!enabled || !visible || event is null) return;
        if (event.type == SDL_EVENT_MOUSE_WHEEL && contains(event.wheel.mouseX, event.wheel.mouseY)) {
            setScroll(scrollX - event.wheel.x * wheelStep,
                scrollY - event.wheel.y * wheelStep);
            return;
        }
        if (event.type == SDL_EVENT_KEY_DOWN && focused) {
            if (event.key.key == SDLK_PAGEDOWN) setScroll(scrollX, scrollY + rect.h);
            else if (event.key.key == SDLK_PAGEUP) setScroll(scrollX, scrollY - rect.h);
            else if (event.key.key == SDLK_HOME) setScroll(0, 0);
            else if (event.key.key == SDLK_END) setScroll(scrollX, contentHeight);
            else if (content !is null) content.handleEvent(event);
        } else if (content !is null &&
                ((event.type == SDL_EVENT_MOUSE_BUTTON_UP && contains(event.button.x, event.button.y)) ||
                 (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN && contains(event.button.x, event.button.y)) ||
                 (event.type == SDL_EVENT_MOUSE_MOTION && contains(event.motion.x, event.motion.y)))) {
            content.handleEvent(event);
        }
    }

    override void draw() {
        if (!visible) return;
        this.Widget.draw();
        if (content is null || !content.visible) return;
        SDL_Rect previous;
        bool hadClip = SDL_RenderClipEnabled(renderer);
        if (hadClip) SDL_GetRenderClipRect(renderer, &previous);
        SDL_Rect clip = SDL_Rect(cast(int) rect.x, cast(int) rect.y,
                cast(int) rect.w, cast(int) rect.h);
        if (hadClip) {
            int x = max(clip.x, previous.x), y = max(clip.y, previous.y);
            int right = min(clip.x + clip.w, previous.x + previous.w);
            int bottom = min(clip.y + clip.h, previous.y + previous.h);
            clip = SDL_Rect(x, y, max(0, right - x), max(0, bottom - y));
        }
        SDL_SetRenderClipRect(renderer, &clip);
        content.draw();
        if (hadClip) SDL_SetRenderClipRect(renderer, &previous);
        else SDL_SetRenderClipRect(renderer, null);
    }
}
