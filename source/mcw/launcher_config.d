module mcw.launcher_config;

import std.file : mkdirRecurse, readText, write;
import std.path : buildPath, dirName, isAbsolute;
import std.process : environment;
import std.string : splitLines, startsWith, strip;

enum string[4] launcherThemeNames = ["midnight", "daylight", "forest", "sunset"];

string launcherConfigPath() {
    auto configHome = environment.get("XDG_CONFIG_HOME", "");
    if (!configHome.isAbsolute) {
        auto home = environment.get("HOME", "");
        if (!home.isAbsolute) return "";
        configHome = buildPath(home, ".config");
    }
    return buildPath(configHome, "mcw", "launcher.conf");
}

int loadLauncherTheme() {
    auto path = launcherConfigPath();
    if (!path.length) return 0;
    try {
        foreach (line; readText(path).splitLines()) {
            auto setting = line.strip();
            if (!setting.startsWith("theme=")) continue;
            auto value = setting[6 .. $].strip();
            foreach (i, name; launcherThemeNames)
                if (value == name) return cast(int)i;
            return 0;
        }
    } catch (Exception) {
        // A missing or unreadable config uses the default theme.
    }
    return 0;
}

void saveLauncherTheme(int index) {
    if (index < 0 || index >= launcherThemeNames.length) return;
    auto path = launcherConfigPath();
    if (!path.length) return;
    mkdirRecurse(dirName(path));
    write(path, "theme=" ~ launcherThemeNames[index] ~ "\n");
}
