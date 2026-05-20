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

DesktopEntry[] findInEntries(DesktopEntry[] entries, string search, int limit=5) {
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

    // Index entries
    // Search

    // auto find_result = execute(["bash", "-c", "find "~ICON_DIRECTORY_SEARCH]);
    // if (find_result.status != 0) {
    //     writeln("Find error");
    // }
    // auto iconfiles = find_result.output.strip().split('\n');
    //
    // string finalwidget;
    // // Generate yuck
    // finalwidget ~= `(box :active true :class "launcher-list" :orientation "v" :space-evenly false :spacing 5 `;
    // foreach(i, entry; entries) {
    //     finalwidget ~= `(box :class "launcher-element" :height 24 :orientation "h" :space-evenly false :spacing 10`;
    //     //if (i == 0) finalwidget ~= ` :class "launcher-first"`;
    //     auto iconpath = iconfiles.find!(e => e.endsWith(entry.icon~".png"));
    //     if (iconpath.length != 0)
    //         finalwidget ~= `   (image :image-width 24 :image-height 24 :path "`~iconpath[0]~`")`;
    //     finalwidget ~= `   (input :class "launcher-el-input" :onaccept 'hyprctl dispatch exec "`~entry.exec~`" && eww close launcher' :value "`~entry.name~`")`;
    //     //finalwidget ~= `   (checkbox :active true :class "launcher-check" :onchecked 'hyprctl dispatch exec "`~entry.exec~`" && eww close launcher')`;
    //     finalwidget ~= `)`;
    // }
    // finalwidget ~= `)`;
    // //writeln(finalwidget);
    // auto result = execute(["eww", "update", `launcher_body=`~finalwidget~``]);
    // if (result.status != 0) {
    //     writeln(result);
    // }
