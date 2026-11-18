module mcw.tests.launcher_window;

import std.conv : to;
import std.file : exists, mkdirRecurse, readText, rmdirRecurse, tempDir, write;
import std.path : buildPath;
import std.process : environment;
import std.string : toStringz;
import std.uuid : randomUUID;

import bindbc.sdl;
import bindbc.loader : LoadMsg;

import mcw.apps.launcher;
import mcw.desktop : resolveIconPath;
import mcw.launcher_config : launcherConfigPath, loadLauncherTheme;
import mcw.widgets : Label;

private void saveLauncher(Launcher window, string name) {
    SDL_SetRenderDrawColor(window.renderer, 0, 0, 0, 255);
    SDL_RenderClear(window.renderer);
    window.panel.draw();
    auto surface = SDL_RenderReadPixels(window.renderer, null);
    assert(surface !is null);
    auto path = buildPath("test-output", name ~ ".bmp");
    assert(SDL_SaveBMP(surface, path.toStringz));
    SDL_DestroySurface(surface);
}

private void checkPixel(Launcher window, int x, int y,
        ubyte expectedR, ubyte expectedG, ubyte expectedB) {
    auto surface = SDL_RenderReadPixels(window.renderer, null);
    assert(surface !is null);
    ubyte r, g, b, a;
    assert(SDL_ReadSurfacePixel(surface, x, y, &r, &g, &b, &a));
    SDL_DestroySurface(surface);
    assert(r == expectedR && g == expectedG && b == expectedB);
}

unittest {
    assert(loadSDL() == LoadMsg.success);
    assert(loadSDLTTF() == LoadMsg.success);
    assert(loadSDLImage() == LoadMsg.success);
    SDL_setenv_unsafe("SDL_VIDEODRIVER".toStringz, "dummy".toStringz, 1);
    SDL_setenv_unsafe("SDL_RENDER_DRIVER".toStringz, "software".toStringz, 1);
    assert(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS));
    scope(exit) SDL_Quit();
    assert(TTF_Init());
    scope(exit) TTF_Quit();

    auto oldHome = environment.get("HOME", "");
    auto oldDataHome = environment.get("XDG_DATA_HOME", "");
    auto oldDataDirs = environment.get("XDG_DATA_DIRS", "");
    auto oldConfigHome = environment.get("XDG_CONFIG_HOME", "");
    auto fixture = buildPath(tempDir(), "mcw-launcher-" ~ randomUUID().toString());
    auto data = buildPath(fixture, "share");
    auto configHome = buildPath(fixture, "config");
    auto apps = buildPath(data, "applications");
    mkdirRecurse(apps);
    scope(exit) {
        SDL_setenv_unsafe("HOME".toStringz, oldHome.toStringz, 1);
        SDL_setenv_unsafe("XDG_DATA_HOME".toStringz, oldDataHome.toStringz, 1);
        SDL_setenv_unsafe("XDG_DATA_DIRS".toStringz, oldDataDirs.toStringz, 1);
        SDL_setenv_unsafe("XDG_CONFIG_HOME".toStringz, oldConfigHome.toStringz, 1);
        rmdirRecurse(fixture);
    }
    SDL_setenv_unsafe("HOME".toStringz, fixture.toStringz, 1);
    SDL_setenv_unsafe("XDG_DATA_HOME".toStringz, data.toStringz, 1);
    SDL_setenv_unsafe("XDG_DATA_DIRS".toStringz, data.toStringz, 1);
    SDL_setenv_unsafe("XDG_CONFIG_HOME".toStringz, configHome.toStringz, 1);
    assert(loadLauncherTheme() == 0);

    auto iconSource = SDL_CreateSurface(4, 4, SDL_PIXELFORMAT_RGBA32);
    assert(iconSource !is null);
    foreach (y; 0 .. 4)
        foreach (x; 0 .. 4)
            assert(SDL_WriteSurfacePixel(iconSource, x, y, 255, 191, 92, 255));
    auto iconPath = buildPath(fixture, "app.bmp");
    assert(SDL_SaveBMP(iconSource, iconPath.toStringz));
    auto iconRoot = buildPath(data, "icons");
    auto iconFolder = buildPath(iconRoot, "hicolor", "48x48", "apps");
    mkdirRecurse(iconFolder);
    auto namedIcon = buildPath(iconFolder, "test-app.png");
    assert(IMG_SavePNG(iconSource, namedIcon.toStringz));
    assert(IMG_SavePNG(iconSource,
        buildPath(iconFolder, "test-application.png").toStringz));
    SDL_DestroySurface(iconSource);
    assert(resolveIconPath("test-app", [iconRoot]) == namedIcon);
    assert(resolveIconPath("test-app.png", [iconRoot]) == namedIcon);
    assert(resolveIconPath("test", [iconRoot]) == "");
    foreach (i, name; ["Alpha Notes", "Beta Browser", "Delta Files",
            "Epsilon Music", "Gamma Editor"]) {
        write(buildPath(apps, "app" ~ i.to!string ~ ".desktop"),
            "[Desktop Entry]\nType=Application\nName=" ~ name ~
            "\nExec=true\nIcon=" ~ (i == 2 ? "missing-icon" :
                i == 0 ? "test-app" : iconPath) ~ "\n");
    }

    auto font = TTF_OpenFont("liberation-sans.ttf", 18);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);
    auto window = new Launcher(SDL_FRect(0, 0, 560, 380), "Launcher test", font);
    scope(exit) destroy(window);
    assert(!exists(launcherConfigPath()));
    assert(window.entries.length == 5);
    assert(window.icon_list.entries.length == 5);
    assert(window.icon_list.selectedIndex == 0);
    assert(window.icon_list.placeholders[2].visible);
    assert(window.icon_list.icons[0].texture !is null);
    assert(window.searchHint.visible);
    assert(window.searchHint.text_placement == Label.TextPlacement.StartCenter);
    assert(window.searchHint.text_x == window.text_input.rect.x +
        window.text_input.computedStyle().padding_left);
    assert(window.searchHint.text_y == window.searchHint.rect.y +
        (window.searchHint.rect.h - window.searchHint.FONT_HEIGHT) / 2);
    foreach (i; 0 .. window.icon_list.entries.length) {
        auto row = window.icon_list.lists[i];
        auto icon = window.icon_list.icons[i];
        auto label = window.icon_list.labels[i];
        assert(label.text_placement == Label.TextPlacement.StartCenter);
        assert(window.icon_list.placeholders[i].text_placement ==
            Label.TextPlacement.Center);
        assert(icon.rect.x == row.rect.x + 14);
        assert(label.text_x == label.rect.x);
        assert(label.text_y == label.rect.y +
            (label.rect.h - label.FONT_HEIGHT) / 2);
    }
    assert(window.rect.h == 380);
    mkdirRecurse("test-output");
    saveLauncher(window, "launcher-midnight");
    checkPixel(window, 8, 100, 0x17, 0x1b, 0x27);
    auto firstIcon = window.icon_list.icons[0].rect;
    checkPixel(window, cast(int)(firstIcon.x + firstIcon.w / 2),
        cast(int)(firstIcon.y + firstIcon.h / 2), 0xff, 0xbf, 0x5c);

    SDL_Event key = SDL_Event();
    key.type = SDL_EVENT_KEY_DOWN;
    key.key.key = SDLK_DOWN;
    window.handleEvent(&key);
    assert(window.icon_list.selectedIndex == 1);
    window.text_input.setValue("editor");
    assert(window.icon_list.entries.length == 1);
    assert(window.icon_list.entries[0].name == "Gamma Editor");
    assert(!window.searchHint.visible);
    assert(window.rect.h == 148);
    window.text_input.setValue("does not exist");
    assert(window.icon_list.entries.length == 0);
    assert(!window.icon_list.visible);
    assert(window.rect.h == 74);
    saveLauncher(window, "launcher-empty");
    window.text_input.setValue("");
    assert(window.searchHint.visible);
    assert(window.rect.h == 380);
    key.key.key = SDLK_F2;
    window.handleEvent(&key);
    assert(window.themeIndex == 1);
    assert(readText(launcherConfigPath()) == "theme=daylight\n");
    saveLauncher(window, "launcher-daylight");
    checkPixel(window, 8, 100, 0xf5, 0xf2, 0xea);

    window.text_input.setValue(">");
    assert(window.commandList.visible && !window.icon_list.visible);
    assert(window.commandIds.length == 5);
    assert(window.commandList.selectedIndex == 0);
    assert(window.rect.h == 350);
    saveLauncher(window, "launcher-commands");
    key.key.key = SDLK_DOWN;
    window.handleEvent(&key);
    assert(window.commandList.selectedIndex == 1);

    window.text_input.setValue("> theme forest");
    assert(window.commandIds.length == 1);
    assert(window.rect.h == 142);
    key.key.key = SDLK_RETURN;
    window.handleEvent(&key);
    assert(window.themeIndex == 2);
    assert(readText(launcherConfigPath()) == "theme=forest\n");
    assert(window.text_input.text == "");
    assert(!window.quit);

    string launchedCommand;
    window.runBash = (string command) { launchedCommand = command; };
    window.text_input.setValue("! echo hello && pwd");
    assert(window.feedback.visible && window.feedback.text == "Run in Bash");
    assert(window.rect.h == 132);
    saveLauncher(window, "launcher-bash");
    window.handleEvent(&key);
    assert(launchedCommand == "echo hello && pwd" && window.quit);
    window.quit = false;

    window.text_input.setValue("= 2 * (3 + 4)");
    assert(window.feedback.visible && window.feedback.text == "14");
    assert(window.rect.h == 132);
    saveLauncher(window, "launcher-math");
    window.handleEvent(&key);
    assert(!window.quit);
    window.text_input.setValue("= 1 / 0");
    assert(window.feedback.text == "Invalid expression");

    string openedUrl;
    window.openUrl = (string url) { openedUrl = url; };
    window.text_input.setValue("? C++ & D");
    assert(window.feedback.visible && window.feedback.text == "Search in browser");
    window.handleEvent(&key);
    assert(openedUrl == "https://duckduckgo.com/?q=C%2B%2B%20%26%20D");
    assert(window.quit);
    window.quit = false;

    window.text_input.setValue("> theme sunset");
    SDL_Event click = SDL_Event();
    click.type = SDL_EVENT_MOUSE_BUTTON_UP;
    click.button.x = 100;
    click.button.y = 95;
    window.handleEvent(&click);
    assert(window.themeIndex == 3);
    assert(readText(launcherConfigPath()) == "theme=sunset\n");
    assert(window.text_input.text == "");

    auto restored = new Launcher(SDL_FRect(0, 0, 560, 380), "Restored launcher", font);
    scope(exit) destroy(restored);
    assert(restored.themeIndex == 3);
    write(launcherConfigPath(), "theme=unknown\n");
    assert(loadLauncherTheme() == 0);

    window.text_input.setValue("> exit");
    window.handleEvent(&key);
    assert(window.quit);
}
