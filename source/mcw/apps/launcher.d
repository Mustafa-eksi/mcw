module mcw.apps.launcher;

import std.process : spawnProcess, spawnShell;
import std.range : empty;
import std.string : startsWith, strip, toLower;

import bindbc.sdl;

import mcw.desktop;
import mcw.launcher_actions : calculate, defaultSearchUrl;
import mcw.launcher_config : loadLauncherTheme, saveLauncherTheme;
import mcw.window;
import mcw.widgets;

class Launcher : Window {
    enum string[4] themePaths = ["themes/midnight.css", "themes/daylight.css",
        "themes/forest.css", "themes/sunset.css"];
    enum string[5] commands = ["theme midnight", "theme daylight",
        "theme forest", "theme sunset", "exit"];
    enum float padding = 14;
    enum float searchHeight = 46;
    enum float listTop = 70;

    DesktopEntry[] entries;
    Canvas panel;
    TextInput text_input;
    Label searchHint;
    IconList icon_list;
    SelectableList commandList;
    ListItem[] commandRows;
    int[] commandIds;
    Label feedback;
    void delegate(string) runBash;
    void delegate(string) openUrl;
    int themeIndex;

    this(SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title);
        SDL_SetWindowAlwaysOnTop(window, true);
        SDL_SetWindowBordered(window, false);
        SDL_SetWindowResizable(window, false);
        SDL_SetWindowPosition(window, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED);

        entries = indexEntries(renderer);
        panel = new Canvas(SDL_FRect(0, 0, rect.w, rect.h), renderer);
        panel.styleClasses = ["panel"];

        text_input = new TextInput(SDL_FRect(padding, padding,
                rect.w - 2 * padding, searchHeight), renderer, font);
        text_input.styleClasses = ["launcher-search"];
        text_input.onChange = (string _) { updateMatches(); };
        panel.addAnchored(text_input);

        searchHint = new Label(SDL_FRect(padding + 16, padding,
                rect.w - 2 * padding - 32, searchHeight), renderer, font, "Search apps");
        searchHint.text_placement = Label.TextPlacement.StartCenter;
        searchHint.styleClasses = ["muted"];
        searchHint.enabled = false;
        panel.addAnchored(searchHint);

        icon_list = new IconList(SDL_FRect(padding, listTop,
                rect.w - 2 * padding, 296), renderer, font, 5, 6);
        icon_list.useLauncherRows();
        icon_list.styleClasses = ["launcher-list"];
        icon_list.onActivate = (int index) { launch(index); };
        panel.addAnchored(icon_list);

        commandList = new SelectableList(SDL_FRect(padding, listTop,
                rect.w - 2 * padding, 266), renderer, 6);
        commandList.element_size = 46;
        commandList.styleClasses = ["launcher-command-list"];
        foreach (_; 0 .. commands.length) {
            auto row = new ListItem(SDL_FRect(0, 0, rect.w - 2 * padding, 46),
                    renderer, font, "");
            row.text_placement = Label.TextPlacement.Start;
            row.styleClasses = ["launcher-command"];
            commandRows ~= row;
            commandList.addChild(row);
        }
        commandList.onActivate = (int index) { activateCommand(index); };
        panel.addAnchored(commandList);

        feedback = new Label(SDL_FRect(padding, listTop,
                rect.w - 2 * padding, 48), renderer, font, "");
        feedback.text_placement = Label.TextPlacement.Start;
        feedback.styleClasses = ["launcher-feedback"];
        feedback.enabled = false;
        panel.addAnchored(feedback);

        runBash = (string command) { spawnProcess(["bash", "-lc", command]); };
        openUrl = (string url) { spawnProcess(["xdg-open", url]); };

        widget = panel;
        applyTheme(loadLauncherTheme(), false);
        updateMatches();
        panel.focused = true;
        text_input.focused = true;
        panel.focused_child = 0;
        SDL_StartTextInput(window);
    }

    private void applyTheme(int index, bool remember = true) {
        try {
            loadCSS(themePaths[index]).apply(panel);
            themeIndex = index;
            if (remember) {
                try { saveLauncherTheme(index); }
                catch (Exception) { }
            }
        } catch (Exception) {
            // The launcher remains usable when run outside the project root.
        }
    }

    private void updateMatches() {
        auto input = text_input.text;
        searchHint.visible = input.length == 0;
        icon_list.clearSelection();
        commandList.clearSelection();
        icon_list.visible = false;
        commandList.visible = false;
        feedback.visible = false;
        float contentHeight = 0;

        if (input.length && input[0] == '>') {
            auto query = input[1 .. $].strip().toLower();
            commandIds.length = 0;
            foreach (i, command; commands)
                if (command.startsWith(query)) commandIds ~= cast(int)i;
            foreach (i, row; commandRows) {
                row.visible = i < commandIds.length;
                if (row.visible) row.setText(commands[commandIds[i]]);
            }
            commandList.adjustLayout();
            commandList.visible = commandIds.length > 0;
            if (commandList.visible) {
                commandList.select(0);
                contentHeight = commandList.idealHeight();
            } else {
                feedback.setText("No matching command");
                feedback.visible = true;
                contentHeight = feedback.rect.h;
            }
        } else if (input.length && (input[0] == '!' ||
                input[0] == '=' || input[0] == '?')) {
            auto query = input[1 .. $].strip();
            string message;
            switch (input[0]) {
            case '!': message = query.length ? "Run in Bash" : "Type a Bash command"; break;
            case '?': message = query.length ? "Search in browser" : "Type a web search"; break;
            case '=':
                if (!query.length) message = "Type a calculation";
                else if (!calculate(query, message)) message = "Invalid expression";
                break;
            default: break;
            }
            feedback.setText(message);
            feedback.visible = true;
            contentHeight = feedback.rect.h;
        } else {
            icon_list.entries = findInEntries(entries, input);
            icon_list.updateList();
            if (!icon_list.entries.empty) icon_list.select(0);
            icon_list.visible = !icon_list.entries.empty;
            if (icon_list.visible) contentHeight = icon_list.idealHeight();
        }

        float height = contentHeight == 0 ? padding + searchHeight + padding :
            listTop + contentHeight + padding;
        if (height != rect.h) {
            this.rect = SDL_FRect(0, 0, rect.w, height);
            panel.rect = rect;
            SDL_SetWindowSize(window, cast(int)rect.w, cast(int)height);
        }
    }

    private void activateCommand(int index) {
        if (index < 0 || index >= commandIds.length) return;
        int command = commandIds[index];
        if (command == 4) { quit = true; return; }
        applyTheme(command);
        commandList.focused = false;
        panel.focused_child = 0;
        text_input.focused = true;
        text_input.setValue("");
    }

    private void activateInput() {
        auto input = text_input.text;
        if (!input.length) { launch(icon_list.selectedIndex); return; }
        string query;
        if (input[0] == '>' || input[0] == '!' || input[0] == '=' ||
                input[0] == '?') query = input[1 .. $].strip();
        switch (input[0]) {
        case '>': activateCommand(commandList.selectedIndex); break;
        case '!':
            if (query.length) {
                try { runBash(query); quit = true; }
                catch (Exception) { feedback.setText("Could not start Bash"); }
            }
            break;
        case '?':
            if (query.length) {
                try { openUrl(defaultSearchUrl(query)); quit = true; }
                catch (Exception) { feedback.setText("Could not open browser"); }
            }
            break;
        case '=': break;
        default: launch(icon_list.selectedIndex);
        }
    }

    private void launch(int index) {
        if (index < 0 || index >= icon_list.entries.length) return;
        try {
            spawnShell(icon_list.entries[index].exec.idup);
            quit = true;
        } catch (Exception) { }
    }

    void prepareShow() {
        quit = false;
        panel.focused = true;
        panel.focused_child = 0;
        text_input.focused = true;
        text_input.setValue("");
        SDL_StartTextInput(window);
    }

    override void handleEvent(SDL_Event *event) {
        if (event.type == SDL_EVENT_KEY_DOWN) {
            if (event.key.key == SDLK_ESCAPE) { quit = true; return; }
            if (event.key.key >= SDLK_F1 && event.key.key <= SDLK_F4) {
                applyTheme(cast(int)(event.key.key - SDLK_F1));
                return;
            }
            if (event.key.key == SDLK_DOWN || event.key.key == SDLK_UP) {
                if (commandList.visible) commandList.handleEvent(event);
                else if (icon_list.visible) icon_list.handleEvent(event);
                return;
            }
            if (event.key.key == SDLK_RETURN || event.key.key == SDLK_KP_ENTER) {
                activateInput();
                return;
            }
        }
        super.handleEvent(event);
    }

    ~this() {
        SDL_StopTextInput(window);
        foreach (ref entry; entries)
            if (entry.icon_texture !is null) SDL_DestroyTexture(entry.icon_texture);
    }
}
