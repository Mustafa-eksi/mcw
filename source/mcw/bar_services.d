module mcw.bar_services;

import std.algorithm : min, max;
import std.conv : to;
import std.file : isFile;
import std.json : JSONValue, JSONType, parseJSON;
import std.process : execute, spawnProcess, Pid, kill, wait;
import core.sys.posix.signal : SIGTERM;
import std.string : indexOf, split, startsWith, strip;

struct BarDesktop { string id, name; }
struct BarTrayItem { string service, path, title, icon; }
struct BarMedia {
    string service, title, artist, art;
    long position, length;
    bool playing, canSeek;
}

struct BarState {
    BarDesktop[] desktops;
    string currentDesktop;
    BarMedia media;
    BarTrayItem[] tray;
    int volume = -1, brightness = -1;
    string profile;
}

private JSONValue emptyJSON() { return JSONValue(null); }

private JSONValue value(JSONValue node) {
    while (node.type == JSONType.object && "data" in node.object)
        node = node.object["data"];
    return node;
}

private string asString(JSONValue node) {
    node = value(node);
    if (node.type == JSONType.string) return node.str;
    if (node.type == JSONType.array && node.array.length == 1)
        return asString(node.array[0]);
    return "";
}

private long asLong(JSONValue node, long fallback = 0) {
    node = value(node);
    try {
        if (node.type == JSONType.integer) return node.integer;
        if (node.type == JSONType.string) return to!long(node.str);
        if (node.type == JSONType.array && node.array.length == 1)
            return asLong(node.array[0], fallback);
    } catch (Exception) {}
    return fallback;
}

private bool asBool(JSONValue node) {
    node = value(node);
    return node.type == JSONType.true_ || asString(node) == "true";
}

private JSONValue findKey(JSONValue node, string key) {
    node = value(node);
    if (node.type == JSONType.object) {
        if (auto found = key in node.object) return *found;
        foreach (name, child; node.object) {
            auto found = findKey(child, key);
            if (found.type != JSONType.null_) return found;
        }
    } else if (node.type == JSONType.array) {
        foreach (i; 0 .. node.array.length - (node.array.length % 2)) {
            if (i % 2 == 0 && asString(node.array[i]) == key)
                return node.array[i + 1];
        }
        foreach (child; node.array) {
            auto found = findKey(child, key);
            if (found.type != JSONType.null_) return found;
        }
    }
    return emptyJSON();
}

private void collectDesktops(JSONValue node, ref BarDesktop[] result) {
    node = value(node);
    if (node.type != JSONType.array) return;
    if (node.array.length >= 3 && value(node.array[0]).type == JSONType.integer &&
            asString(node.array[1]).length && asString(node.array[2]).length) {
        result ~= BarDesktop(asString(node.array[1]), asString(node.array[2]));
        return;
    }
    foreach (child; node.array) collectDesktops(child, result);
}

private string[] strings(JSONValue node) {
    string[] result;
    node = value(node);
    if (node.type != JSONType.array) return result;
    foreach (child; node.array) {
        auto s = asString(child);
        if (s.length) result ~= s;
    }
    return result;
}

class BarServices {
    BarState state;
    string error;
    private Pid inhibitor;
    private bool inhibited;

    // Argument arrays are passed directly to the process API; nothing is run in a shell.
    string command(string[] args) {
        try {
            auto result = execute(args);
            return result.status == 0 ? result.output.strip() : "";
        } catch (Exception) { return ""; }
    }

    bool action(string[] args) {
        try {
            auto result = execute(args);
            if (result.status == 0) { error = ""; return true; }
            error = result.output.strip();
        } catch (Exception e) { error = e.msg; }
        if (!error.length) error = args[0] ~ " failed";
        return false;
    }

    private JSONValue bus(string[] args) {
        auto output = command(["busctl", "--user", "--json=short", "--no-pager"] ~ args);
        if (!output.length) return emptyJSON();
        try return parseJSON(output);
        catch (Exception) return emptyJSON();
    }

    private JSONValue property(string service, string path, string iface, string name) {
        return bus(["get-property", service, path, iface, name]);
    }

    private bool busAction(string[] args) {
        return action(["busctl", "--user", "--quiet", "--timeout=2"] ~ args);
    }

    void refresh() {
        BarState next;
        next.desktops = state.desktops;
        next.currentDesktop = state.currentDesktop;
        auto count = asLong(property("org.kde.KWin", "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager", "count"));
        auto desktopData = property("org.kde.KWin", "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager", "desktops");
        BarDesktop[] desktops;
        collectDesktops(desktopData, desktops);
        if (desktops.length) next.desktops = desktops;
        else if (count > 0 && count <= 20) {
            next.desktops.length = 0;
            foreach (i; 0 .. cast(int)count)
                next.desktops ~= BarDesktop("", to!string(i + 1));
        }
        auto current = asString(property("org.kde.KWin", "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager", "current"));
        if (current.length) next.currentDesktop = current;

        auto names = command(["busctl", "--user", "--no-pager", "--no-legend", "list"]);
        string player;
        string playingPlayer;
        foreach (line; names.split('\n')) {
            auto fields = line.split();
            if (fields.length && fields[0].startsWith("org.mpris.MediaPlayer2.")) {
                if (!player.length) player = fields[0];
                auto status = asString(property(fields[0], "/org/mpris/MediaPlayer2",
                    "org.mpris.MediaPlayer2.Player", "PlaybackStatus"));
                if (status == "Playing") { playingPlayer = fields[0]; break; }
            }
        }
        if (playingPlayer.length) player = playingPlayer;
        if (player.length) {
            enum path = "/org/mpris/MediaPlayer2";
            enum iface = "org.mpris.MediaPlayer2.Player";
            next.media.service = player;
            auto metadata = property(player, path, iface, "Metadata");
            next.media.title = asString(findKey(metadata, "xesam:title"));
            auto artists = strings(findKey(metadata, "xesam:artist"));
            if (artists.length) next.media.artist = artists[0];
            next.media.art = asString(findKey(metadata, "mpris:artUrl"));
            next.media.length = asLong(findKey(metadata, "mpris:length"));
            next.media.position = asLong(property(player, path, iface, "Position"));
            next.media.playing = asString(property(player, path, iface,
                "PlaybackStatus")) == "Playing";
            next.media.canSeek = asBool(property(player, path, iface, "CanSeek"));
        }

        auto items = strings(property("org.kde.StatusNotifierWatcher",
            "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
            "RegisteredStatusNotifierItems"));
        foreach (item; items) {
            auto slash = item.indexOf('/');
            if (slash <= 0) continue;
            BarTrayItem entry;
            entry.service = item[0 .. slash];
            entry.path = item[slash .. $];
            entry.title = asString(property(entry.service, entry.path,
                "org.kde.StatusNotifierItem", "Title"));
            entry.icon = asString(property(entry.service, entry.path,
                "org.kde.StatusNotifierItem", "IconName"));
            next.tray ~= entry;
            if (next.tray.length == 6) break;
        }

        auto volumeText = command(["pactl", "get-sink-volume", "@DEFAULT_SINK@"]);
        auto percent = volumeText.indexOf('%');
        if (percent > 0) {
            auto start = percent;
            while (start > 0 && volumeText[start - 1] >= '0' &&
                    volumeText[start - 1] <= '9') start--;
            try next.volume = to!int(volumeText[start .. percent]);
            catch (Exception) {}
        }
        auto brightness = property("org.kde.ScreenBrightness",
            "/org/kde/ScreenBrightness/display0",
            "org.kde.ScreenBrightness.Display", "Brightness");
        auto brightnessMax = property("org.kde.ScreenBrightness",
            "/org/kde/ScreenBrightness/display0",
            "org.kde.ScreenBrightness.Display", "MaxBrightness");
        auto maxValue = asLong(brightnessMax);
        if (maxValue > 0) next.brightness = cast(int)(100 * asLong(brightness) / maxValue);
        next.profile = command(["powerprofilesctl", "get"]);
        state = next;
    }

    bool switchDesktop(int index) {
        if (index < 0 || index >= state.desktops.length) return false;
        auto id = state.desktops[index].id;
        if (id.length)
            return busAction(["set-property", "org.kde.KWin", "/VirtualDesktopManager",
                "org.kde.KWin.VirtualDesktopManager", "current", "s", id]);
        return action(["qdbus6", "org.kde.KWin", "/KWin",
            "org.kde.KWin.setCurrentDesktop", to!string(index + 1)]);
    }

    bool mediaAction(string method) {
        if (!state.media.service.length) return false;
        return busAction(["call", state.media.service, "/org/mpris/MediaPlayer2",
            "org.mpris.MediaPlayer2.Player", method]);
    }

    bool seek(double fraction) {
        if (!state.media.service.length || !state.media.canSeek || state.media.length <= 0)
            return false;
        long offset = cast(long)(max(0.0, min(1.0, fraction)) * state.media.length) -
            state.media.position;
        return busAction(["call", state.media.service, "/org/mpris/MediaPlayer2",
            "org.mpris.MediaPlayer2.Player", "Seek", "x", to!string(offset)]);
    }

    bool activateTray(BarTrayItem item, bool context = false) {
        return busAction(["call", item.service, item.path,
            "org.kde.StatusNotifierItem", context ? "ContextMenu" : "Activate",
            "ii", "0", "0"]);
    }

    bool setVolume(int percent) {
        return action(["pactl", "set-sink-volume", "@DEFAULT_SINK@",
            to!string(max(0, min(100, percent))) ~ "%"]);
    }

    bool setBrightness(int percent) {
        auto maxValue = asLong(property("org.kde.ScreenBrightness",
            "/org/kde/ScreenBrightness/display0",
            "org.kde.ScreenBrightness.Display", "MaxBrightness"));
        if (maxValue <= 0) { error = "Brightness control unavailable"; return false; }
        return busAction(["call", "org.kde.ScreenBrightness",
            "/org/kde/ScreenBrightness/display0",
            "org.kde.ScreenBrightness.Display", "SetBrightness", "iu",
            to!string(maxValue * max(0, min(100, percent)) / 100), "0"]);
    }

    bool togglePowerSave() {
        return action(["powerprofilesctl", "set",
            state.profile == "power-saver" ? "balanced" : "power-saver"]);
    }

    bool toggleInhibit() {
        if (inhibited) {
            kill(inhibitor, SIGTERM);
            wait(inhibitor);
            inhibited = false;
            error = "";
            return true;
        }
        try {
            inhibitor = spawnProcess(["kde-inhibit", "--power", "--screenSaver",
                "sleep", "infinity"]);
            inhibited = true;
            error = "";
            return true;
        } catch (Exception e) { error = e.msg; return false; }
    }

    bool sleepInhibited() { return inhibited; }

    bool openBluetooth() {
        try { spawnProcess(["kcmshell6", "kcm_bluetooth"]); error = ""; return true; }
        catch (Exception e) { error = e.msg; return false; }
    }

    bool sessionAction(string kind) {
        if (kind == "sleep") return action(["systemctl", "suspend"]);
        string method;
        switch (kind) {
        case "poweroff": method = "promptShutDown"; break;
        case "restart": method = "promptReboot"; break;
        case "logout": method = "promptLogout"; break;
        default: return false;
        }
        return action(["qdbus6", "org.kde.LogoutPrompt", "/LogoutPrompt",
            "org.kde.LogoutPrompt." ~ method]);
    }

    ~this() {
        if (inhibited) { kill(inhibitor, SIGTERM); wait(inhibitor); }
    }
}

unittest {
    auto desktops = parseJSON(`{"type":"a(iss)","data":[[0,"desktop-a","Work"],[1,"desktop-b","Chat"]]}`);
    BarDesktop[] parsed;
    collectDesktops(desktops, parsed);
    assert(parsed.length == 2);
    assert(parsed[0].id == "desktop-a" && parsed[1].name == "Chat");

    auto metadata = parseJSON(`{"type":"a{sv}","data":["xesam:title",{"type":"v","data":{"type":"s","data":"Song"}},"mpris:length",{"type":"x","data":125000000},"xesam:artist",{"type":"as","data":["Artist"]}]}`);
    assert(asString(findKey(metadata, "xesam:title")) == "Song");
    assert(asLong(findKey(metadata, "mpris:length")) == 125000000);
    assert(strings(findKey(metadata, "xesam:artist"))[0] == "Artist");
    assert(asLong(parseJSON(`{"type":"i","data":72}`)) == 72);
}
