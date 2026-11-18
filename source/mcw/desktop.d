module mcw.desktop;

import std.algorithm : sort;
import std.file : dirEntries, exists, isFile, readText, SpanMode;
import std.path : baseName, buildPath, extension, isAbsolute, stripExtension;
import std.process : environment;
import std.string : indexOf, join, split, startsWith, strip, toLower, toStringz;

import bindbc.sdl;

struct DesktopEntry {
    char[] name;
    char[] exec;
    char[] icon;
    SDL_Texture *icon_texture;
    string filepath;
    bool hidden;

    this(string path) {
        filepath = path;
        bool inDesktopEntry;
        foreach (rawLine; readText(path).split('\n')) {
            auto line = rawLine.strip();
            if (line.startsWith("[")) {
                inDesktopEntry = line == "[Desktop Entry]";
                continue;
            }
            if (!inDesktopEntry) continue;
            auto separator = line.indexOf('=');
            if (separator < 0) continue;
            auto key = line[0 .. separator];
            auto value = line[separator + 1 .. $].strip();
            switch (key) {
            case "Name": name = value.dup; break;
            case "Exec": exec = value.dup; break;
            case "Icon": icon = value.dup; break;
            case "Hidden":
            case "NoDisplay": hidden = hidden || value == "true"; break;
            case "Type": hidden = hidden || value != "Application"; break;
            default: break;
            }
        }
        exec = exec.idup.split(' ').filterFieldCodes().join(" ").dup;
    }
}

private string[] filterFieldCodes(string[] words) {
    string[] result;
    foreach (word; words)
        if (word.length && !word.startsWith("%")) result ~= word;
    return result;
}

private string[] dataDirectories() {
    auto home = environment.get("HOME", "");
    auto dataHome = environment.get("XDG_DATA_HOME",
        home.length ? buildPath(home, ".local", "share") : "");
    string[] directories;
    if (dataHome.length) directories ~= dataHome;
    foreach (path; environment.get("XDG_DATA_DIRS",
            "/usr/local/share:/usr/share").split(':'))
        if (path.length) directories ~= path;
    return directories;
}

private string[] iconDirectories() {
    string[] directories;
    auto home = environment.get("HOME", "");
    if (home.length) directories ~= buildPath(home, ".icons");
    foreach (data; dataDirectories()) directories ~= buildPath(data, "icons");
    foreach (data; dataDirectories()) directories ~= buildPath(data, "pixmaps");
    return directories;
}

private struct IconCandidate {
    string path;
    int score;
}

private IconCandidate[string] indexIcons(string[] roots) {
    IconCandidate[string] candidates;
    foreach (root; roots) {
        if (!exists(root)) continue;
        foreach (entry; dirEntries(root, SpanMode.depth)) {
            if (!entry.isFile) continue;
            auto path = entry.name;
            auto ext = extension(path).toLower();
            int formatScore;
            switch (ext) {
            case ".png": formatScore = 30; break;
            case ".svg": formatScore = 20; break;
            case ".xpm": formatScore = 10; break;
            default: continue;
            }
            auto name = stripExtension(baseName(path));
            int sizeScore = path.indexOf("/48x48/") >= 0 ? 8 :
                path.indexOf("/64x64/") >= 0 ? 7 :
                path.indexOf("/scalable/") >= 0 ? 6 :
                path.indexOf("/32x32/") >= 0 ? 5 :
                path.indexOf("/128x128/") >= 0 ? 4 : 0;
            int score = formatScore + sizeScore;
            auto previous = name in candidates;
            if (previous is null || score > previous.score)
                candidates[name] = IconCandidate(path, score);
        }
    }
    return candidates;
}

private string iconKey(string name) {
    switch (extension(name).toLower()) {
    case ".png":
    case ".svg":
    case ".xpm": return stripExtension(name);
    default: return name;
    }
}

string resolveIconPath(string iconName, string[] roots) {
    if (!iconName.length) return "";
    if (isAbsolute(iconName)) return isFile(iconName) ? iconName : "";
    auto candidates = indexIcons(roots);
    auto match = iconKey(iconName) in candidates;
    return match is null ? "" : match.path;
}

DesktopEntry[] indexEntries(SDL_Renderer *renderer) {
    DesktopEntry[] entries;
    string[string] seen;
    auto icons = indexIcons(iconDirectories());
    foreach (data; dataDirectories()) {
        auto applicationDir = buildPath(data, "applications");
        if (!exists(applicationDir)) continue;
        foreach (file; dirEntries(applicationDir, "*.desktop", SpanMode.shallow)) {
            auto id = baseName(file.name);
            if (id in seen) continue;
            seen[id] = file.name;
            DesktopEntry entry;
            try entry = DesktopEntry(file.name);
            catch (Exception) { continue; }
            if (entry.hidden || !entry.name.length || !entry.exec.length) continue;
            string iconPath;
            auto iconName = entry.icon.idup;
            if (isAbsolute(iconName)) {
                if (isFile(iconName)) iconPath = iconName;
            } else if (auto match = iconKey(iconName) in icons) iconPath = match.path;
            if (iconPath.length) {
                auto surface = IMG_Load(iconPath.toStringz);
                if (surface !is null) {
                    entry.icon_texture = SDL_CreateTextureFromSurface(renderer, surface);
                    SDL_DestroySurface(surface);
                }
            }
            entries ~= entry;
        }
    }
    entries.sort!((a, b) => a.name.toLower() < b.name.toLower());
    return entries;
}

DesktopEntry[] findInEntries(DesktopEntry[] entries, string search, int limit = 5) {
    DesktopEntry[] filtered;
    auto needle = search.toLower();
    foreach (entry; entries) {
        if (filtered.length >= limit) break;
        if (entry.name.idup.toLower().indexOf(needle) >= 0) filtered ~= entry;
    }
    return filtered;
}

string generateList(ref DesktopEntry[] entries) {
    string output;
    foreach (entry; entries) output ~= entry.name.idup ~ '\n';
    return output;
}
