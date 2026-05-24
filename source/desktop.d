import std.stdio : writeln;
import std.process : execute;
import std.file : dirEntries, SpanMode, read;
import std.string: split, startsWith, strip, toLower, endsWith, join;
import std.algorithm.mutation : remove;
import std.algorithm.searching : find, canFind;
import std.range : front, empty, takeExactly, back;
import std.conv : to;
import std.string : toStringz;

import bindbc.sdl;

struct DesktopEntry {
    char[] name;
    char[] exec;
    char[] icon;
    SDL_Texture *icon_texture;
    string filepath;

    this(string _filepath) {
        filepath = _filepath;
        char[] filecontent = cast(char[])read(filepath);
        auto lines = filecontent.split('\n');

        auto names = lines.remove!((line) => !line.startsWith("Name="));
        if (names.length == 0) return;
        name = names[0].split("=")[1];

        auto execs = lines.remove!(line => !line.startsWith("Exec="));
        if (execs.length == 0) return;
        exec = execs[0].split("=")[1];
        exec = exec.split(" ").remove!(a => a.startsWith("%")).join(" ");

        auto icons = lines.remove!(line => !line.startsWith("Icon="));
        if (icons.length == 0) return;
        icon = icons[0].split("=")[1];
    }
}

const DESKTOP_ENTRY_DIRECTORY = "/usr/share/applications";
const ICON_DIRECTORY_SEARCH = "/usr/share/icons/hicolor/ -type f";
// const ICON_DIRECTORY_SEARCH = "/usr/share/icons/hicolor/*/apps/*.png";

DesktopEntry[] indexEntries(SDL_Renderer *renderer) {
    DesktopEntry[] entries;
    auto find_result = execute(["bash", "-c", "find "~ICON_DIRECTORY_SEARCH]);
    if (find_result.status != 0) {
        writeln("Find error");
    }
    auto iconfiles = find_result.output.strip().split('\n');
    foreach(string desktop_entry; dirEntries(DESKTOP_ENTRY_DIRECTORY, SpanMode.shallow)) {
        if (desktop_entry.endsWith(".desktop")) {
            entries[entries.length++] = DesktopEntry(desktop_entry);
            auto entry = entries[entries.length.to!int-1];
            auto iconpath = iconfiles.find!(e =>
                    e.split('/').back.startsWith(entry.icon));
            if (!iconpath.empty)
                entries[entries.length.to!int-1].icon_texture =
                    SDL_CreateTextureFromSurface(renderer, IMG_Load(iconpath[0].toStringz));
        }
    }
    return entries;
}

DesktopEntry[] findInEntries(DesktopEntry[] entries, string search, int limit=4) {
    DesktopEntry[] filtered = [];
    foreach (entry; entries) {
        if (filtered.length > limit)
            break;
        if (entry.name.toLower.startsWith(search.toLower))
            filtered ~= entry;
    }
    return filtered;
}

string generateList(ref DesktopEntry[] entries) {
    string output;
    foreach (entry; entries) {
        output ~= entry.name ~ '\n';
    }
    return output;
}
