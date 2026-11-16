module mcw.apps.showcase;

import std.conv : to;
import std.string : startsWith;
import bindbc.sdl;

import mcw.window;
import mcw.desktop : DesktopEntry;
import mcw.widgets;

private class Swatch : Widget {
    void delegate() onClick;

    this(SDL_FRect rect, SDL_Renderer *renderer, SDL_Color color) {
        super(rect, renderer);
        style.background_color = color;
        style.border_color = SDL_Color(215, 220, 235, 255);
    }

    override void handleEvent(SDL_Event *event) {
        if (event !is null && event.type == SDL_EVENT_MOUSE_BUTTON_UP &&
                contains(event.button.x, event.button.y) && onClick !is null)
            onClick();
    }
}

class WidgetShowcaseWindow : Window {
    enum string[4] themeNames = ["Midnight", "Daylight", "Forest", "Sunset"];
    enum string[4] themePaths = ["themes/midnight.css", "themes/daylight.css",
        "themes/forest.css", "themes/sunset.css"];

    Tabs tabs;
    Menu demoMenu;
    Menu submenu;
    Button menuToggle;
    ScrollView listScroll;
    SelectableList listChoices;
    IconList listIcons;
    Button resizeAnchor;
    Button hoverButton;
    Tooltip basicsTooltip;
    TextInput controlsInput;
    SDL_Texture *demoTexture;
    Label[6] status;
    Button[4] themeButtons;
    StyleSheetWatcher themeWatcher;
    int themeIndex = -1;

    this(SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title);
        SDL_SetWindowMinimumSize(window, 900, 650);
        SDL_StartTextInput(window);
        demoTexture = makeTexture();

        tabs = new Tabs(rect, renderer, font);
        tabs.headerHeight = 40;
        tabs.style.background_color = SDL_Color(23, 27, 39, 255);
        tabs.addTab("Basics", makeBasics(font));
        tabs.addTab("Controls", makeControls(font));
        tabs.addTab("Lists", makeLists(font));
        tabs.addTab("Layout", makeLayout(font));
        tabs.addTab("Menus", makeMenus(font));
        tabs.addTab("Themes", makeThemes(font));
        tabs.onChange = (int _) { if (demoMenu !is null) demoMenu.close(); };
        widget = tabs;
        tabs.focused = true;
        selectTheme(0);
    }

    ~this() {
        if (demoTexture !is null) SDL_DestroyTexture(demoTexture);
    }

    private SDL_Texture *makeTexture() {
        auto surface = SDL_CreateSurface(4, 2, SDL_PIXELFORMAT_RGBA32);
        assert(surface !is null);
        scope(exit) SDL_DestroySurface(surface);
        foreach (y; 0 .. 2) foreach (x; 0 .. 4) {
            ubyte r = x < 2 ? 240 : 54;
            ubyte g = y == 0 ? 172 : 92;
            ubyte b = x < 2 ? 88 : 220;
            SDL_WriteSurfacePixel(surface, x, y, r, g, b, 255);
        }
        auto texture = SDL_CreateTextureFromSurface(renderer, surface);
        assert(texture !is null);
        SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST);
        return texture;
    }

    private Canvas panel() {
        auto result = new Canvas(SDL_FRect(0, 40, rect.w, rect.h - 40), renderer);
        result.styleClasses = ["panel"];
        result.style.background_color = SDL_Color(23, 27, 39, 255);
        return result;
    }

    private void place(Canvas parent, Widget child, float x, float y,
            float width, float height, bool right = false, bool bottom = false) {
        child.rect = SDL_FRect(parent.rect.x + x, parent.rect.y + y, width, height);
        parent.addAnchored(child, right, bottom);
    }

    private Label label(TTF_Font *font, string caption, bool muted = false) {
        auto result = new Label(SDL_FRect(0, 0, 100, 26), renderer, font, caption);
        result.styleClasses = muted ? ["muted"] : ["normal"];
        result.text_color = muted ? SDL_Color(156, 168, 191, 255) :
            SDL_Color(233, 237, 247, 255);
        return result;
    }

    private Button button(TTF_Font *font, string caption) {
        auto result = new Button(SDL_FRect(0, 0, 120, 34), renderer, font, caption);
        result.style.background_color = SDL_Color(48, 74, 126, 255);
        result.style.border_color = SDL_Color(98, 128, 185, 255);
        result.style.focused_border_color = SDL_Color(249, 191, 92, 255);
        result.style.hover_color = SDL_Color(67, 105, 171, 255);
        result.style.pressed_color = SDL_Color(32, 59, 103, 255);
        result.style.disabled_color = SDL_Color(65, 68, 76, 255);
        return result;
    }

    private void heading(Canvas p, TTF_Font *font, string title, string subtitle) {
        place(p, label(font, title), 30, 22, 780, 30);
        place(p, label(font, subtitle, true), 30, 56, 960, 26);
    }

    private Label statusLine(Canvas p, TTF_Font *font, int page) {
        auto result = label(font, "Ready. Try the widgets on this page.");
        result.styleClasses = ["status"];
        result.style.background_color = SDL_Color(36, 43, 60, 255);
        result.style.border_color = SDL_Color(68, 82, 108, 255);
        place(p, result, 30, p.rect.h - 64, 680, 34, false, true);
        status[page] = result;
        return result;
    }

    private Canvas makeBasics(TTF_Font *font) {
        auto p = panel();
        heading(p, font, "Basics and drawing", "Widget, Label, Icon, Image, Button, Separator and Tooltip");
        auto message = statusLine(p, font, 0);

        place(p, label(font, "Base Widget fill and border"), 40, 112, 330, 26);
        auto base = new Widget(SDL_FRect(0, 0, 1, 1), renderer);
        base.styleClasses = ["base-widget"];
        base.style.background_color = SDL_Color(76, 120, 153, 255);
        base.style.border_color = SDL_Color(180, 224, 247, 255);
        place(p, base, 40, 148, 160, 80);
        place(p, label(font, "Label text placement"), 260, 112, 260, 26);
        auto centered = label(font, "Centered label");
        centered.styleClasses = ["card"];
        centered.style.background_color = SDL_Color(43, 53, 73, 255);
        place(p, centered, 260, 148, 230, 80);

        place(p, label(font, "Icon"), 550, 112, 110, 26);
        place(p, new Icon(SDL_FRect(0, 0, 1, 1), renderer, demoTexture),
                550, 148, 80, 80);
        place(p, label(font, "Image fit modes"), 40, 274, 300, 26);
        auto fitNames = ["Contain", "Cover", "Stretch"];
        foreach (i, name; fitNames) {
            auto fit = cast(Image.Fit)i;
            auto image = new Image(SDL_FRect(0, 0, 1, 1), renderer, demoTexture, fit);
            image.styleClasses = ["image-frame"];
            image.style.background_color = SDL_Color(38, 48, 69, 255);
            image.style.border_color = SDL_Color(98, 128, 185, 255);
            place(p, image, 40 + i * 170, 306, 140, 104);
            place(p, label(font, name), 40 + i * 170, 418, 140, 24);
        }
        auto separator = new Separator(SDL_FRect(0, 0, 1, 1), renderer);
        place(p, separator, 40, 466, 650, 14);
        auto action = button(font, "Hover or click me");
        hoverButton = action;
        action.onActivate = () { message.setText("Button activated by mouse or keyboard."); };
        place(p, action, 40, 502, 210, 40);
        auto tip = new Tooltip(SDL_FRect(0, 0, 260, 30), renderer, font,
                "Hover or focus shows this tooltip", action);
        basicsTooltip = tip;
        tip.style.background_color = SDL_Color(68, 73, 110, 255);
        place(p, tip, 280, 502, 260, 30);
        auto disabled = button(font, "Disabled button");
        disabled.enabled = false;
        place(p, disabled, 570, 502, 190, 40);
        return p;
    }

    private Canvas makeControls(TTF_Font *font) {
        auto p = panel();
        heading(p, font, "Interactive controls", "Type Unicode text; select, toggle, drag and use the keyboard");
        auto message = statusLine(p, font, 1);

        place(p, label(font, "TextInput"), 40, 112, 220, 26);
        auto input = new TextInput(SDL_FRect(0, 0, 1, 1), renderer, font);
        controlsInput = input;
        input.style.background_color = SDL_Color(40, 47, 64, 255);
        input.style.border_color = SDL_Color(107, 128, 160, 255);
        input.style.focused_border_color = SDL_Color(249, 191, 92, 255);
        input.onChange = (string text) { message.setText("Text: " ~ text); };
        place(p, input, 40, 148, 360, 40);
        place(p, label(font, "Ctrl+A/C/X/V, arrows, Home/End" , true), 40, 195, 420, 24);

        place(p, label(font, "CheckBox"), 40, 248, 220, 26);
        auto check = new CheckBox(SDL_FRect(0, 0, 1, 1), renderer, font, "Enable option");
        check.style.background_color = SDL_Color(45, 53, 73, 255);
        check.onToggle = (bool value) {
            message.setText(value ? "CheckBox: on" : "CheckBox: off");
        };
        place(p, check, 40, 280, 250, 40);

        place(p, label(font, "RadioButton / RadioGroup"), 350, 248, 350, 26);
        auto group = new RadioGroup();
        foreach (i, name; ["Small", "Medium", "Large"]) {
            auto radio = new RadioButton(SDL_FRect(0, 0, 1, 1), renderer, font, name);
            radio.style.background_color = SDL_Color(45, 53, 73, 255);
            group.add(radio);
            place(p, radio, 350 + i * 130, 280, 120, 40);
        }
        group.onChange = (int index) { message.setText("Radio choice: " ~ group.buttons[index].text); };
        group.select(0);

        place(p, label(font, "ComboBox"), 40, 356, 220, 26);
        auto combo = new ComboBox(SDL_FRect(0, 0, 1, 1), renderer, font,
                ["Amber", "Cyan", "Violet"]);
        combo.style.background_color = SDL_Color(45, 53, 73, 255);
        combo.style.border_color = SDL_Color(107, 128, 160, 255);
        combo.onChange = (int index, string text) { message.setText("ComboBox: " ~ text); };
        place(p, combo, 40, 390, 220, 38);

        place(p, label(font, "Slider and ProgressBar"), 350, 356, 350, 26);
        auto slider = new Slider(SDL_FRect(0, 0, 1, 1), renderer, 0, 100, 35);
        auto progress = new ProgressBar(SDL_FRect(0, 0, 1, 1), renderer, 0.35);
        progress.style.background_color = SDL_Color(42, 48, 62, 255);
        slider.onChange = (double value) {
            progress.setProgress(value / 100);
            message.setText("Value: " ~ to!int(value).to!string ~ "%");
        };
        place(p, slider, 350, 390, 360, 32);
        place(p, progress, 350, 444, 360, 24);
        return p;
    }

    private Canvas makeLists(TTF_Font *font) {
        auto p = panel();
        heading(p, font, "Lists and scrolling", "Select rows, use arrow keys, or scroll the clipped viewport");
        auto message = statusLine(p, font, 2);

        place(p, label(font, "List"), 35, 110, 250, 26);
        auto plain = new List(SDL_FRect(0, 0, 260, 215), renderer, 3,
                List.Orientation.Vertical);
        plain.style.background_color = SDL_Color(36, 43, 60, 255);
        foreach (i; 0 .. 5) {
            auto row = label(font, "Plain row " ~ (i + 1).to!string);
            row.styleClasses = [i % 2 == 0 ? "row" : "row-alt"];
            row.style.background_color = SDL_Color(46, 56, 77, 255);
            plain.addChild(row);
        }
        place(p, plain, 35, 148, 260, 215);

        place(p, label(font, "SelectableList / ListItem"), 335, 110, 310, 26);
        auto selectable = new SelectableList(SDL_FRect(0, 0, 280, 215), renderer, 3);
        listChoices = selectable;
        selectable.style.background_color = SDL_Color(36, 43, 60, 255);
        foreach (i; 0 .. 5) {
            auto item = new ListItem(SDL_FRect(0, 0, 250, 34), renderer, font,
                    "Choice " ~ (i + 1).to!string);
            item.style.background_color = SDL_Color(46, 56, 77, 255);
            selectable.addChild(item);
        }
        selectable.onSelection = (int index) {
            message.setText("Selected row " ~ (index + 1).to!string);
        };
        selectable.onActivate = (int index) {
            message.setText("Activated row " ~ (index + 1).to!string);
        };
        place(p, selectable, 335, 148, 280, 215);

        place(p, label(font, "ScrollView with 20 rows"), 665, 110, 330, 26);
        auto longList = new List(SDL_FRect(0, 0, 300, 562), renderer, 2,
                List.Orientation.Vertical);
        longList.style.background_color = SDL_Color(36, 43, 60, 255);
        foreach (i; 0 .. 20) {
            auto row = label(font, "Scrollable row " ~ (i + 1).to!string);
            row.styleClasses = [i % 2 == 0 ? "row" : "row-alt"];
            row.style.background_color = (i % 2 == 0) ?
                SDL_Color(47, 56, 78, 255) : SDL_Color(39, 48, 67, 255);
            longList.addChild(row);
        }
        auto scroll = new ScrollView(SDL_FRect(0, 0, 1, 1), renderer);
        listScroll = scroll;
        scroll.style.border_color = SDL_Color(112, 130, 165, 255);
        place(p, scroll, 665, 148, 300, 215);
        scroll.setContent(longList, 300, longList.idealHeight());

        place(p, label(font, "IconList (sample entries)"), 35, 405, 330, 26);
        auto icons = new IconList(SDL_FRect(0, 0, 360, 145), renderer, font, 3, 5);
        listIcons = icons;
        DesktopEntry[3] samples;
        samples[0].name = "Editor".dup;
        samples[1].name = "Browser".dup;
        samples[2].name = "Terminal".dup;
        foreach (ref sample; samples) sample.icon_texture = demoTexture;
        icons.entries = samples[].dup;
        icons.updateList();
        icons.onSelection = (int index) {
            message.setText("IconList: " ~ icons.entries[index].name.idup);
        };
        place(p, icons, 35, 445, 360, 145);
        return p;
    }

    private Canvas makeLayout(TTF_Font *font) {
        auto p = panel();
        heading(p, font, "Layout and hit testing", "Resize the window to watch the lower-right anchored button move");
        auto message = statusLine(p, font, 3);

        place(p, label(font, "Horizontal Box with flexible Spacer"), 40, 108, 450, 26);
        auto row = new Box(SDL_FRect(0, 0, 520, 60), renderer, 8,
                Box.Orientation.Horizontal);
        row.styleClasses = ["layout-box"];
        row.uniform = false;
        row.style.background_color = SDL_Color(40, 48, 66, 255);
        auto left = button(font, "Left");
        auto right = button(font, "Right");
        row.addChild(left);
        row.addChild(new Spacer(SDL_FRect(0, 0, 1, 1), renderer));
        row.addChild(right);
        left.onActivate = () { message.setText("Left Box button clicked."); };
        right.onActivate = () { message.setText("Right Box button clicked."); };
        place(p, row, 40, 146, 520, 60);

        place(p, label(font, "Vertical Box"), 40, 254, 240, 26);
        auto column = new Box(SDL_FRect(0, 0, 200, 235), renderer, 6,
                Box.Orientation.Vertical);
        column.styleClasses = ["layout-box"];
        foreach (color; [SDL_Color(77, 111, 158, 255),
                            SDL_Color(89, 137, 117, 255),
                            SDL_Color(152, 108, 110, 255)]) {
            auto swatch = new Widget(SDL_FRect(0, 0, 1, 1), renderer);
            swatch.style.background_color = color;
            column.addChild(swatch);
        }
        place(p, column, 40, 290, 200, 235);

        place(p, label(font, "Canvas overlap: the last child receives clicks"),
                300, 254, 550, 26);
        auto back = new Swatch(SDL_FRect(0, 0, 1, 1), renderer,
                SDL_Color(67, 129, 185, 255));
        back.onClick = () { message.setText("Back swatch clicked."); };
        place(p, back, 300, 290, 170, 130);
        auto front = new Swatch(SDL_FRect(0, 0, 1, 1), renderer,
                SDL_Color(178, 103, 142, 255));
        front.onClick = () { message.setText("Front swatch clicked."); };
        place(p, front, 390, 355, 170, 130);

        auto anchored = button(font, "Anchored right + bottom");
        resizeAnchor = anchored;
        anchored.onActivate = () { message.setText("Anchored button clicked after resize."); };
        place(p, anchored, p.rect.w - 270, p.rect.h - 112,
                240, 38, true, true);
        return p;
    }

    private Canvas makeMenus(TTF_Font *font) {
        auto p = panel();
        heading(p, font, "Menus and navigation", "Open the menu, use arrows + Enter, or press Ctrl+1 for a shortcut");
        auto message = statusLine(p, font, 4);

        auto open = button(font, "Open menu");
        menuToggle = open;
        place(p, open, 60, 126, 200, 38);
        demoMenu = new Menu(SDL_FRect(0, 0, 220, 105), renderer, 2);
        demoMenu.style.background_color = SDL_Color(42, 49, 67, 255);
        demoMenu.style.border_color = SDL_Color(112, 130, 165, 255);
        auto one = new MenuItem(SDL_FRect(0, 0, 1, 31), renderer, font,
                "Action one", "Ctrl+1");
        auto two = new MenuItem(SDL_FRect(0, 0, 1, 31), renderer, font,
                "More actions >");
        auto three = new MenuItem(SDL_FRect(0, 0, 1, 31), renderer, font,
                "Action three");
        foreach (item; [one, two, three]) {
            item.style.background_color = SDL_Color(49, 62, 83, 255);
            item.style.focused_border_color = SDL_Color(249, 191, 92, 255);
            demoMenu.addItem(item);
        }
        one.setShortcut(SDLK_1, SDL_KMOD_CTRL);
        one.onActivate = () { message.setText("Action one / Ctrl+1 activated."); };
        three.onActivate = () { message.setText("Action three activated."); };
        place(p, demoMenu, 60, 175, 220, 105);

        submenu = new Menu(SDL_FRect(0, 0, 185, 70), renderer, 2);
        submenu.style.background_color = SDL_Color(42, 49, 67, 255);
        auto child = new MenuItem(SDL_FRect(0, 0, 1, 31), renderer, font,
                "Nested action");
        child.style.background_color = SDL_Color(49, 62, 83, 255);
        child.onActivate = () { message.setText("Nested action activated."); };
        submenu.addItem(child);
        two.setSubmenu(submenu);
        open.onActivate = () {
            if (demoMenu.open) demoMenu.close();
            else demoMenu.open = true;
            message.setText(demoMenu.open ? "Menu open." : "Menu closed.");
        };

        place(p, label(font, "Tabs above switch between every demo page."),
                60, 340, 650, 26);
        place(p, label(font, "MenuItem, submenu, keyboard shortcut and focus are live."),
                60, 375, 780, 26);
        return p;
    }

    private void connectThemeButton(Button choice, int index) {
        choice.onActivate = () { selectTheme(index); };
    }

    private Canvas makeThemes(TTF_Font *font) {
        auto p = panel();
        heading(p, font, "CSS themes and hot reload",
            "Choose a palette, then edit its CSS file while the showcase is running.");
        statusLine(p, font, 5);
        foreach (i, name; themeNames) {
            auto choice = button(font, name);
            choice.styleClasses = ["theme-choice"];
            themeButtons[i] = choice;
            connectThemeButton(choice, cast(int)i);
            place(p, choice, 45 + (i % 2) * 300,
                154 + (i / 2) * 106, 250, 64);
        }
        place(p, label(font, "F1–F4 switch themes from any page. F5 reloads the current file.", true),
            45, 396, 900, 30);
        place(p, label(font, "The last valid palette stays visible if a CSS edit has an error.", true),
            45, 436, 900, 30);
        return p;
    }

    bool selectTheme(int index) {
        if (index < 0 || index >= themeNames.length) return false;
        auto candidate = new StyleSheetWatcher(themePaths[index], tabs);
        if (candidate.sheet is null) {
            status[5].setText("Could not load " ~ themePaths[index] ~ ": " ~
                candidate.lastError);
            return false;
        }
        candidate.addRoot(submenu);
        themeWatcher = candidate;
        themeIndex = index;
        foreach (i, choice; themeButtons)
            choice.styleClasses = i == index ?
                ["theme-choice", "active-theme"] : ["theme-choice"];
        status[5].setText("Active: " ~ themeNames[index] ~ " — " ~
            themePaths[index] ~ " (editing this file reloads automatically)");
        return true;
    }

    private bool refreshTheme(bool force = false) {
        if (themeWatcher !is null) {
            if (themeWatcher.poll(force)) {
                status[5].setText("Reloaded " ~ themeWatcher.path ~
                    " (revision " ~ themeWatcher.revision.to!string ~ ")");
                return true;
            } else if (themeWatcher.lastError.length) {
                auto message = "CSS error in " ~ themeWatcher.path ~ ": " ~
                    themeWatcher.lastError;
                if (status[5].text != message) {
                    status[5].setText(message);
                    return true;
                }
            } else if (status[5].text.startsWith("CSS error")) {
                status[5].setText("Active: " ~ themeNames[themeIndex] ~
                    " — " ~ themeWatcher.path);
                return true;
            }
        }
        return false;
    }

    override int idleTimeoutMs() { return 250; }
    override bool onIdle() { return refreshTheme(); }

    override void draw() {
        refreshTheme();
        super.draw();
    }

    override void handleEvent(SDL_Event *event) {
        if (event.type == SDL_EVENT_KEY_DOWN) {
            if (event.key.key >= SDLK_F1 && event.key.key <= SDLK_F4) {
                selectTheme(cast(int)(event.key.key - SDLK_F1));
                return;
            }
            if (event.key.key == SDLK_F5) {
                refreshTheme(true);
                return;
            }
        }
        if (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE) {
            if (demoMenu !is null && demoMenu.open) demoMenu.close();
            else quit = true;
            return;
        }
        if (event.type == SDL_EVENT_KEY_DOWN && tabs.selected == 4 && demoMenu !is null &&
                event.key.key == SDLK_1 && (event.key.mod & SDL_KMOD_CTRL)) {
            demoMenu.handleEvent(event);
            return;
        }
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP && demoMenu !is null &&
                demoMenu.open && !demoMenu.contains(event.button.x, event.button.y) &&
                !menuToggle.contains(event.button.x, event.button.y))
            demoMenu.close();
        super.handleEvent(event);
    }
}
