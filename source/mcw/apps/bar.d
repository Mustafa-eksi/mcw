module mcw.apps.bar;

import std.algorithm : min, max;
import std.conv : to;
import std.datetime : Clock, SysTime;
import std.file : FileException, isFile, remove, tempDir;
import std.math : sqrt;
import std.path : buildPath;
import std.process : execute;
import std.string : toStringz, startsWith;
import std.uri : decode;
import std.uuid : randomUUID;
import core.sys.posix.unistd : getpid;

import bindbc.sdl;
import mcw.bar_services;
import mcw.window;
import mcw.widgets;

private enum bg = SDL_Color(22, 27, 37, 255);
private enum panelBg = SDL_Color(31, 38, 52, 255);
private enum accent = SDL_Color(101, 178, 227, 255);
private enum muted = SDL_Color(171, 185, 204, 255);

private bool regularFile(string path) {
    try return isFile(path);
    catch (FileException) return false;
}

private string iconPath(string name) {
    if (name.startsWith("/") && regularFile(name)) return name;
    foreach (theme; ["breeze-dark", "breeze", "hicolor"])
        foreach (group; ["actions", "status", "devices", "apps"])
            foreach (size; ["22", "16", "32", "48", "scalable"])
                foreach (ext; [".svg", ".png"]) {
                    auto path = buildPath("/usr/share/icons", theme, group,
                        size, name ~ ext);
                    if (regularFile(path)) return path;
                }
    return "";
}

private class IconButton : Button {
    SDL_Texture *iconTexture;
    string iconName;
    string fallback;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font,
            string icon, string fallback) {
        super(rect, renderer, font, fallback);
        this.fallback = fallback;
        setIcon(icon);
    }

    void setIcon(string name) {
        if (name == iconName) return;
        iconName = name;
        releaseIcon();
        auto path = iconPath(name);
        if (path.length) {
            auto surface = IMG_Load(path.toStringz);
            if (surface !is null) {
                iconTexture = SDL_CreateTextureFromSurface(renderer, surface);
                SDL_DestroySurface(surface);
            }
        }
        setText(iconTexture is null ? fallback : "");
    }

    void releaseIcon() {
        if (iconTexture !is null) SDL_DestroyTexture(iconTexture);
        iconTexture = null;
    }

    override void draw() {
        super.draw();
        if (!visible || iconTexture is null) return;
        float size = min(22.0f, min(rect.w, rect.h) - 8);
        SDL_FRect target = SDL_FRect(rect.x + (rect.w - size) / 2,
            rect.y + (rect.h - size) / 2, size, size);
        SDL_RenderTexture(renderer, iconTexture, null, &target);
    }

    ~this() { releaseIcon(); }
}

private class RoundedArt : Image {
    int radius;
    SDL_Color surrounding;

    this(SDL_FRect rect, SDL_Renderer *renderer, SDL_Texture *texture,
            int radius, SDL_Color surrounding) {
        super(rect, renderer, texture, Image.Fit.Cover);
        this.radius = radius;
        this.surrounding = surrounding;
    }

    override void draw() {
        super.draw();
        if (!visible || texture is null) return;
        SDL_SetRenderDrawColor(renderer, surrounding.tupleof);
        foreach (row; 0 .. radius) {
            float dy = radius - row - 0.5f;
            int inset = cast(int)(radius - sqrt(radius * radius - dy * dy));
            if (!inset) continue;
            float left = rect.x, right = rect.x + rect.w - 1;
            float top = rect.y + row, bottom = rect.y + rect.h - row - 1;
            SDL_RenderLine(renderer, left, top, left + inset - 1, top);
            SDL_RenderLine(renderer, right - inset + 1, top, right, top);
            SDL_RenderLine(renderer, left, bottom, left + inset - 1, bottom);
            SDL_RenderLine(renderer, right - inset + 1, bottom, right, bottom);
        }
    }
}

private void fillRoundedRect(SDL_Renderer *renderer, SDL_FRect area,
        int radius, SDL_Color color) {
    SDL_SetRenderDrawColor(renderer, color.tupleof);
    foreach (row; 0 .. cast(int)area.h) {
        int inset;
        if (row < radius || row >= area.h - radius) {
            float dy = row < radius ? radius - row - 0.5f :
                row - (area.h - radius) + 0.5f;
            inset = cast(int)(radius - sqrt(radius * radius - dy * dy));
        }
        SDL_RenderLine(renderer, area.x + inset, area.y + row,
            area.x + area.w - inset - 1, area.y + row);
    }
}

private class TrayButton : Button {
    SDL_Texture *iconTexture;
    string iconName;

    this(SDL_FRect rect, SDL_Renderer *renderer, TTF_Font *font) {
        super(rect, renderer, font, "·");
    }

    void setIcon(string name) {
        if (name == iconName) return;
        iconName = name;
        releaseIcon();
        if (!name.length) return;
        string path;
        if (name.startsWith("/") && regularFile(name)) path = name;
        if (!path.length) foreach (theme; ["breeze", "breeze-dark", "hicolor"]) {
            foreach (group; ["status", "apps", "devices"]) {
                foreach (size; ["22", "32", "16", "48", "scalable"]) {
                    foreach (ext; [".svg", ".png"]) {
                        auto candidate = buildPath("/usr/share/icons", theme,
                            group, size, name ~ ext);
                        if (regularFile(candidate)) { path = candidate; break; }
                    }
                    if (path.length) break;
                }
                if (path.length) break;
            }
            if (path.length) break;
        }
        if (path.length) {
            auto surface = IMG_Load(path.toStringz);
            if (surface !is null) {
                iconTexture = SDL_CreateTextureFromSurface(renderer, surface);
                SDL_DestroySurface(surface);
            }
        }
    }


    void releaseIcon() {
        if (iconTexture !is null) SDL_DestroyTexture(iconTexture);
        iconTexture = null;
    }

    override void draw() {
        super.draw();
        if (visible && iconTexture !is null) {
            SDL_FRect target = SDL_FRect(rect.x + 3, rect.y + 4, rect.w - 6, rect.h - 8);
            SDL_RenderTexture(renderer, iconTexture, null, &target);
        }
    }

    ~this() { releaseIcon(); }
}

private class CommitSlider : Slider {
    void delegate(double) onCommit;

    this(SDL_FRect rect, SDL_Renderer *renderer, double initial = 0) {
        super(rect, renderer, 0, 100, initial);
        focusable = true;
        style.track_color = SDL_Color(75, 90, 109, 255);
        style.thumb_color = accent;
    }

    override void handleEvent(SDL_Event *event) {
        if (event is null) return;
        bool commit = (event.type == SDL_EVENT_MOUSE_BUTTON_UP && dragging) ||
            (event.type == SDL_EVENT_KEY_DOWN && focused &&
                (event.key.key == SDLK_LEFT || event.key.key == SDLK_RIGHT ||
                 event.key.key == SDLK_HOME || event.key.key == SDLK_END));
        super.handleEvent(event);
        if (commit && onCommit !is null) onCommit(value);
    }

    override void draw() {
        if (!visible) return;
        this.Widget.draw();
        auto s = computedStyle();
        auto track = s.has_track_color ? s.track_color : SDL_Color(75, 90, 109, 255);
        auto thumb = s.has_thumb_color ? s.thumb_color : accent;
        fillRoundedRect(renderer, SDL_FRect(rect.x, rect.y + rect.h / 2 - 2,
            rect.w, 4), 2, track);
        float x = rect.x + cast(float)((value - minimum) / (maximum - minimum)) * rect.w;
        fillRoundedRect(renderer, SDL_FRect(x - 4, rect.y, 8, rect.h), 4, thumb);
    }
}

class BarWindow : Window {
    BarServices services;
    Window controlWindow;
    Window mediaWindow;
    Canvas bar;
    Canvas controls;
    Canvas mediaPanel;
    TTF_Font *font;
    Button[] desktops;
    TrayButton[] trayButtons;
    BarTrayItem[] trayItems;
    Button artButton;
    IconButton previous, playPause, next, compactPlay, controlButton, powerButton,
        saveButton, inhibitButton, bluetoothButton, volumeIcon, brightnessIcon;
    IconButton[4] powerActions;
    Label clockLabel, trackLabel, popupTrackLabel, timeLabel, volumeLabel, brightnessLabel, profileLabel, statusLabel;
    Image artwork, bigArtwork;
    CommitSlider seekSlider, volumeSlider, brightnessSlider;
    SDL_Texture *artTexture, popupArtTexture;
    string artUrl;
    string downloadedArtPath;
    string hoveredHint;
    bool controlsOpen, mediaOpen, powerOpen;
    uint idleTicks;

    this(SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title);
        this.font = font;
        services = new BarServices();
        SDL_SetWindowBordered(window, false);
        SDL_SetWindowAlwaysOnTop(window, true);
        SDL_SetWindowResizable(window, false);
        SDL_SetWindowPosition(window, 0, 0);

        bar = new Canvas(rect, renderer);
        bar.style.background_color = bg;
        bar.style.border_radius = 8;
        widget = bar;

        foreach (i; 0 .. 8) {
            auto index = i;
            auto button = makeButton(renderer, to!string(i + 1));
            button.onActivate = () {
                if (services.switchDesktop(index)) updateState();
                else showError();
            };
            bar.addAnchored(button);
            desktops ~= button;
        }
        artwork = new RoundedArt(SDL_FRect(0, 0, 36, 36), renderer, null, 7, bg);
        artwork.style.background_color = SDL_Color(48, 57, 73, 255);
        artwork.style.border_radius = 7;
        bar.addAnchored(artwork);
        artButton = new Button(SDL_FRect(0, 0, 36, 36), renderer, font, "");
        artButton.style.focused_border_color = accent;
        artButton.onActivate = () { toggleMedia(); };
        bar.addAnchored(artButton);
        trackLabel = makeLabel(renderer, "No media playing", muted);
        trackLabel.text_placement = Label.TextPlacement.StartCenter;
        bar.addAnchored(trackLabel);
        compactPlay = makeIconButton(renderer, "media-playback-start", ">");
        compactPlay.onActivate = () { mediaAction("PlayPause"); };
        bar.addAnchored(compactPlay);
        clockLabel = makeLabel(renderer, "--:--", SDL_Color(236, 241, 247, 255));
        bar.addAnchored(clockLabel);
        foreach (i; 0 .. 6) {
            auto index = i;
            auto button = new TrayButton(SDL_FRect(0, 0, 28, 30), renderer, font);
            button.style.background_color = SDL_Color(43, 54, 70, 255);
            button.style.hover_color = SDL_Color(66, 91, 118, 255);
            button.style.border_radius = 7;
            button.onActivate = () {
                if (index < trayItems.length && !services.activateTray(trayItems[index]))
                    showError();
            };
            bar.addAnchored(button);
            trayButtons ~= button;
        }
        controlButton = makeIconButton(renderer, "configure", "Settings");
        controlButton.onActivate = () { toggleControls(); };
        bar.addAnchored(controlButton);

        mediaWindow = new Window(SDL_FRect(0, 0, 340, 360), "MCW media");
        SDL_SetWindowBordered(mediaWindow.window, false);
        SDL_SetWindowAlwaysOnTop(mediaWindow.window, true);
        SDL_SetWindowResizable(mediaWindow.window, false);
        mediaPanel = new Canvas(SDL_FRect(0, 0, 340, 360), mediaWindow.renderer);
        mediaPanel.style.background_color = panelBg;
        mediaPanel.style.border_radius = 12;
        mediaWindow.widget = mediaPanel;
        popupTrackLabel = makeLabel(mediaWindow.renderer, "No media playing", muted);
        place(mediaPanel, popupTrackLabel, 20, 4, 300, 20);
        bigArtwork = new RoundedArt(SDL_FRect(50, 27, 240, 240),
            mediaWindow.renderer, null, 12, panelBg);
        bigArtwork.style.background_color = SDL_Color(48, 57, 73, 255);
        bigArtwork.style.border_radius = 12;
        mediaPanel.addAnchored(bigArtwork);
        seekSlider = new CommitSlider(SDL_FRect(20, 279, 300, 10), mediaWindow.renderer);
        seekSlider.onCommit = (double percent) {
            if (!services.seek(percent / 100)) showError();
            else updateState();
        };
        mediaPanel.addAnchored(seekSlider);
        timeLabel = makeLabel(mediaWindow.renderer, "--:-- / --:--", muted);
        place(mediaPanel, timeLabel, 20, 291, 300, 20);
        previous = makeIconButton(mediaWindow.renderer, "media-skip-backward", "|<");
        playPause = makeIconButton(mediaWindow.renderer, "media-playback-start", ">");
        next = makeIconButton(mediaWindow.renderer, "media-skip-forward", ">|");
        previous.onActivate = () { mediaAction("Previous"); };
        playPause.onActivate = () { mediaAction("PlayPause"); };
        next.onActivate = () { mediaAction("Next"); };
        place(mediaPanel, previous, 75, 318, 56, 32);
        place(mediaPanel, playPause, 142, 318, 56, 32);
        place(mediaPanel, next, 209, 318, 56, 32);

        controlWindow = new Window(SDL_FRect(0, 0, 348, 210), "MCW controls");
        SDL_SetWindowBordered(controlWindow.window, false);
        SDL_SetWindowAlwaysOnTop(controlWindow.window, true);
        SDL_SetWindowResizable(controlWindow.window, false);
        controls = new Canvas(SDL_FRect(0, 0, 348, 210), controlWindow.renderer);
        controls.style.background_color = panelBg;
        controls.style.border_radius = 12;
        controlWindow.widget = controls;
        createControls();
        layout();
        updateState();
    }

    ~this() {
        if (artTexture !is null) SDL_DestroyTexture(artTexture);
        if (popupArtTexture !is null) SDL_DestroyTexture(popupArtTexture);
        foreach (button; trayButtons) button.releaseIcon();
        foreach (button; [previous, playPause, next, compactPlay,
                controlButton, powerButton, saveButton, inhibitButton,
                bluetoothButton, volumeIcon, brightnessIcon])
            button.releaseIcon();
        foreach (button; powerActions) button.releaseIcon();
        if (downloadedArtPath.length) {
            try remove(downloadedArtPath);
            catch (Exception) {}
        }
        destroy(controlWindow);
        destroy(mediaWindow);
        destroy(services);
    }

    private Button makeButton(SDL_Renderer *target, string caption) {
        auto button = new Button(SDL_FRect(0, 0, 35, 32), target, font, caption);
        button.style.background_color = SDL_Color(43, 54, 70, 255);
        button.style.hover_color = SDL_Color(66, 91, 118, 255);
        button.style.pressed_color = SDL_Color(48, 122, 171, 255);
        button.style.focused_border_color = accent;
        button.style.border_radius = 7;
        button.text_color = SDL_Color(236, 241, 247, 255);
        return button;
    }

    private IconButton makeIconButton(SDL_Renderer *target, string icon,
            string fallback) {
        auto button = new IconButton(SDL_FRect(0, 0, 35, 32), target,
            font, icon, fallback);
        button.style.background_color = SDL_Color(43, 54, 70, 255);
        button.style.hover_color = SDL_Color(66, 91, 118, 255);
        button.style.pressed_color = SDL_Color(48, 122, 171, 255);
        button.style.focused_border_color = accent;
        button.style.border_radius = 7;
        button.text_color = SDL_Color(236, 241, 247, 255);
        return button;
    }

    private Label makeLabel(SDL_Renderer *target, string caption, SDL_Color color) {
        auto label = new Label(SDL_FRect(0, 0, 100, 25), target, font, caption);
        label.text_color = color;
        return label;
    }

    private void place(Canvas root, Widget child, float x, float y,
            float w, float h) {
        child.rect = SDL_FRect(x, y, w, h);
        root.addAnchored(child);
    }

    private void createControls() {
        auto heading = makeLabel(controlWindow.renderer, "Quick controls", accent);
        place(controls, heading, 18, 10, 220, 28);
        auto closeButton = makeIconButton(controlWindow.renderer, "window-close", "Close");
        closeButton.onActivate = () { closeControls(); };
        place(controls, closeButton, 306, 10, 30, 30);

        volumeIcon = makeIconButton(controlWindow.renderer, "audio-volume-high", "Volume");
        volumeIcon.enabled = false;
        place(controls, volumeIcon, 18, 50, 30, 30);
        volumeLabel = makeLabel(controlWindow.renderer, "--%", muted);
        volumeLabel.text_placement = Label.TextPlacement.StartCenter;
        place(controls, volumeLabel, 56, 50, 50, 30);
        volumeSlider = new CommitSlider(SDL_FRect(0, 0, 1, 1),
            controlWindow.renderer);
        volumeSlider.onCommit = (double level) {
            if (!services.setVolume(cast(int)level)) showError();
            updateState();
        };
        place(controls, volumeSlider, 114, 58, 214, 14);

        brightnessIcon = makeIconButton(controlWindow.renderer, "brightness-high", "Brightness");
        brightnessIcon.enabled = false;
        place(controls, brightnessIcon, 18, 89, 30, 30);
        brightnessLabel = makeLabel(controlWindow.renderer, "--%", muted);
        brightnessLabel.text_placement = Label.TextPlacement.StartCenter;
        place(controls, brightnessLabel, 56, 89, 50, 30);
        brightnessSlider = new CommitSlider(SDL_FRect(0, 0, 1, 1),
            controlWindow.renderer);
        brightnessSlider.onCommit = (double level) {
            if (!services.setBrightness(cast(int)level)) showError();
            updateState();
        };
        place(controls, brightnessSlider, 114, 97, 214, 14);

        saveButton = makeIconButton(controlWindow.renderer,
            "battery-profile-powersave", "Power save");
        saveButton.onActivate = () {
            if (!services.togglePowerSave()) showError();
            updateState();
        };
        place(controls, saveButton, 18, 133, 66, 38);
        inhibitButton = makeIconButton(controlWindow.renderer,
            "system-suspend-inhibited", "Do not sleep");
        inhibitButton.onActivate = () {
            if (!services.toggleInhibit()) showError();
            updateState();
        };
        place(controls, inhibitButton, 100, 133, 66, 38);
        profileLabel = makeLabel(controlWindow.renderer, "Profile: unavailable", muted);
        profileLabel.text_placement = Label.TextPlacement.StartCenter;
        place(controls, profileLabel, 18, 181, 310, 20);

        bluetoothButton = makeIconButton(controlWindow.renderer,
            "network-bluetooth", "Bluetooth settings");
        bluetoothButton.onActivate = () {
            if (!services.openBluetooth()) showError();
            else closeControls();
        };
        place(controls, bluetoothButton, 182, 133, 66, 38);
        powerButton = makeIconButton(controlWindow.renderer,
            "system-shutdown", "Power and session");
        powerButton.onActivate = () { togglePowerMenu(); };
        place(controls, powerButton, 264, 133, 66, 38);
        statusLabel = makeLabel(controlWindow.renderer, "", SDL_Color(238, 166, 144, 255));
        statusLabel.text_placement = Label.TextPlacement.StartCenter;
        place(controls, statusLabel, 18, 181, 310, 20);
        statusLabel.visible = false;

        string[4] names = ["Power off", "Log off", "Restart", "Sleep"];
        string[4] kinds = ["poweroff", "logout", "restart", "sleep"];
        string[4] icons = ["system-shutdown", "system-log-out", "view-refresh", "system-suspend"];
        foreach (i; 0 .. 4) {
            auto kind = kinds[i];
            auto button = makeIconButton(controlWindow.renderer, icons[i], names[i]);
            button.onActivate = () {
                if (!services.sessionAction(kind)) showError();
                else closeControls();
            };
            place(controls, button, 18 + i * 82, 211, 66, 38);
            button.visible = false;
            powerActions[i] = button;
        }
    }

    private void layout() {
        auto width = rect.w;
        foreach (i, button; desktops)
            button.rect = SDL_FRect(7 + i * 38, 7, 34, 30);
        clockLabel.rect = SDL_FRect((width - 76) / 2, 6, 76, 31);
        controlButton.rect = SDL_FRect(width - 39, 7, 32, 30);
        auto trayCount = min(trayButtons.length, trayItems.length);
        float trayStart = controlButton.rect.x - 5 -
            (trayCount ? (cast(float)trayCount * 31 - 3) : 0);
        foreach (i, button; trayButtons)
            button.rect = SDL_FRect(trayStart + i * 31, 7, 28, 30);
        float mediaRight = trayStart - 8;
        float mediaW = max(84.0f, min(226.0f,
            mediaRight - (clockLabel.rect.x + clockLabel.rect.w + 16)));
        float mediaX = mediaRight - mediaW;
        artwork.rect = SDL_FRect(mediaX, 4, 36, 36);
        artButton.rect = artwork.rect;
        trackLabel.rect = SDL_FRect(mediaX + 44, 7, max(0.0f, mediaW - 82), 30);
        compactPlay.rect = SDL_FRect(mediaX + mediaW - 34, 7, 32, 30);
    }

    private void showError() {
        statusLabel.setText(services.error.length ? services.error : "Action unavailable");
        profileLabel.visible = false;
        statusLabel.visible = true;
    }

    private void mediaAction(string method) {
        if (!services.mediaAction(method)) showError();
        updateState();
    }

    private static string stamp(long microseconds) {
        if (microseconds < 0) microseconds = 0;
        long seconds = microseconds / 1_000_000;
        return to!string(seconds / 60) ~ ":" ~
            (seconds % 60 < 10 ? "0" : "") ~ to!string(seconds % 60);
    }

    private void loadArt(string url) {
        if (url == artUrl) return;
        artUrl = url;
        if (artTexture !is null) SDL_DestroyTexture(artTexture);
        if (popupArtTexture !is null) SDL_DestroyTexture(popupArtTexture);
        artTexture = null;
        popupArtTexture = null;
        if (downloadedArtPath.length) {
            try remove(downloadedArtPath);
            catch (Exception) {}
            downloadedArtPath = "";
        }
        string path;
        if (url.startsWith("file://")) path = decode(url[7 .. $]);
        else if (url.startsWith("http://") || url.startsWith("https://")) {
            path = buildPath(tempDir(), "mcw-bar-art-" ~ to!string(getpid()));
            try {
                auto result = execute(["curl", "--location", "--silent", "--fail",
                    "--max-time", "3", "--output", path, url]);
                if (result.status != 0) {
                    try { if (regularFile(path)) remove(path); }
                    catch (Exception) {}
                    path = "";
                }
                else downloadedArtPath = path;
            } catch (Exception) { path = ""; }
        }
        if (path.length && regularFile(path)) {
            auto surface = IMG_Load(path.toStringz);
            if (surface !is null) {
                artTexture = SDL_CreateTextureFromSurface(renderer, surface);
                popupArtTexture = SDL_CreateTextureFromSurface(mediaWindow.renderer, surface);
                SDL_DestroySurface(surface);
            }
        }
        artwork.texture = artTexture;
        bigArtwork.texture = popupArtTexture;
    }

    private void updateState() {
        services.refresh();
        auto state = services.state;
        foreach (i, button; desktops) {
            button.visible = i < state.desktops.length;
            if (!button.visible) continue;
            button.setText(to!string(i + 1));
            button.style.background_color = state.desktops[i].id.length &&
                state.desktops[i].id == state.currentDesktop ? accent :
                SDL_Color(43, 54, 70, 255);
        }
        auto track = state.media.title.length ?
            (state.media.artist.length ? state.media.artist ~ " - " : "") ~
                state.media.title : "No media playing";
        trackLabel.setText(track);
        popupTrackLabel.setText(track);
        playPause.setIcon(state.media.playing ? "media-playback-pause" :
            "media-playback-start");
        compactPlay.setIcon(state.media.playing ? "media-playback-pause" :
            "media-playback-start");
        foreach (button; [previous, playPause, next]) button.enabled =
            state.media.service.length != 0;
        compactPlay.enabled = state.media.service.length != 0;
        loadArt(state.media.art);
        timeLabel.setText(state.media.length > 0 ?
            stamp(state.media.position) ~ "/" ~ stamp(state.media.length) : "--:--");
        seekSlider.enabled = state.media.canSeek && state.media.length > 0;
        if (!seekSlider.dragging)
            seekSlider.setValue(state.media.length > 0 ?
                100.0 * state.media.position / state.media.length : 0);
        trayItems = state.tray;
        foreach (i, button; trayButtons) {
            button.visible = i < trayItems.length;
            if (button.visible) {
                auto title = trayItems[i].title;
                button.setIcon(trayItems[i].icon);
                button.setText(button.iconTexture is null ?
                    (title.length && title[0] < 128 ? title[0 .. 1] : "·") : "");
            }
        }
        layout();
        if (mediaOpen) positionMedia();
        volumeLabel.setText(state.volume >= 0 ? to!string(state.volume) ~ "%" : "--%");
        volumeSlider.enabled = state.volume >= 0;
        if (!volumeSlider.dragging && state.volume >= 0) volumeSlider.setValue(state.volume);
        brightnessLabel.setText(state.brightness >= 0 ?
            to!string(state.brightness) ~ "%" : "--%");
        brightnessSlider.enabled = state.brightness >= 0;
        if (!brightnessSlider.dragging && state.brightness >= 0)
            brightnessSlider.setValue(state.brightness);
        profileLabel.setText(hoveredHint.length ? hoveredHint :
            "Profile: " ~ (state.profile.length ? state.profile : "unavailable"));
        saveButton.style.background_color = state.profile == "power-saver" ? accent :
            SDL_Color(43, 54, 70, 255);
        inhibitButton.style.background_color = services.sleepInhibited() ? accent :
            SDL_Color(43, 54, 70, 255);
    }

    private void updateClock() {
        auto now = Clock.currTime();
        auto hour = now.hour;
        auto minute = now.minute;
        clockLabel.setText((hour < 10 ? "0" : "") ~ to!string(hour) ~ ":" ~
            (minute < 10 ? "0" : "") ~ to!string(minute));
    }

    private void positionControls() {
        int x, y;
        SDL_GetWindowPosition(window, &x, &y);
        SDL_SetWindowPosition(controlWindow.window, x + cast(int)rect.w - 348,
            y + cast(int)rect.h);
    }

    private void positionMedia() {
        int x, y;
        SDL_GetWindowPosition(window, &x, &y);
        SDL_SetWindowPosition(mediaWindow.window,
            x + cast(int)min(artwork.rect.x, rect.w - 345),
            y + cast(int)rect.h);
    }

    private void toggleMedia() {
        if (mediaOpen) { closeMedia(); return; }
        if (controlsOpen) closeControls();
        mediaOpen = true;
        positionMedia();
        SDL_ShowWindow(mediaWindow.window);
        updateState();
        mediaWindow.draw();
    }

    private void closeMedia() {
        mediaOpen = false;
        SDL_HideWindow(mediaWindow.window);
    }

    private void toggleControls() {
        if (controlsOpen) { closeControls(); return; }
        if (mediaOpen) closeMedia();
        controlsOpen = true;
        positionControls();
        SDL_ShowWindow(controlWindow.window);
        updateState();
        controlWindow.draw();
    }

    private void closeControls() {
        controlsOpen = false;
        hoveredHint = "";
        powerOpen = false;
        foreach (button; powerActions) button.visible = false;
        profileLabel.visible = true;
        statusLabel.visible = false;
        SDL_SetWindowSize(controlWindow.window, 348, 210);
        controls.rect = SDL_FRect(0, 0, 348, 210);
        SDL_HideWindow(controlWindow.window);
    }

    private void togglePowerMenu() {
        powerOpen = !powerOpen;
        foreach (button; powerActions) button.visible = powerOpen;
        int height = powerOpen ? 260 : 210;
        SDL_SetWindowSize(controlWindow.window, 348, height);
        controls.rect = SDL_FRect(0, 0, 348, height);
        controlWindow.draw();
    }

    override void handleEvent(SDL_Event *event) {
        if (event is null) return;
        if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED &&
                event.window.windowID == SDL_GetWindowID(window)) {
            quit = true;
            return;
        }
        if (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE) {
            if (mediaOpen) closeMedia();
            if (controlsOpen) closeControls();
            return;
        }
        if (mediaOpen && event.type >= SDL_EVENT_WINDOW_FIRST &&
                event.type <= SDL_EVENT_WINDOW_LAST &&
                event.window.windowID == SDL_GetWindowID(mediaWindow.window)) {
            if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED) closeMedia();
            else mediaWindow.handleEvent(event);
            return;
        }
        if (controlsOpen && event.type >= SDL_EVENT_WINDOW_FIRST &&
                event.type <= SDL_EVENT_WINDOW_LAST &&
                event.window.windowID == SDL_GetWindowID(controlWindow.window)) {
            if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED) closeControls();
            else {
                if (event.type == SDL_EVENT_WINDOW_MOUSE_LEAVE) {
                    hoveredHint = "";
                    profileLabel.setText("Profile: " ~
                        (services.state.profile.length ? services.state.profile : "unavailable"));
                }
                controlWindow.handleEvent(event);
            }
            return;
        }
        if ((controlsOpen || mediaOpen) && (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN ||
                event.type == SDL_EVENT_MOUSE_BUTTON_UP ||
                event.type == SDL_EVENT_MOUSE_MOTION || event.type == SDL_EVENT_KEY_DOWN ||
                event.type == SDL_EVENT_KEY_UP || event.type == SDL_EVENT_MOUSE_WHEEL)) {
            uint windowId = event.type == SDL_EVENT_MOUSE_MOTION ? event.motion.windowID :
                event.type == SDL_EVENT_MOUSE_BUTTON_DOWN || event.type == SDL_EVENT_MOUSE_BUTTON_UP ?
                event.button.windowID : event.type == SDL_EVENT_MOUSE_WHEEL ?
                event.wheel.windowID : event.key.windowID;
            if (mediaOpen && windowId == SDL_GetWindowID(mediaWindow.window)) {
                mediaWindow.handleEvent(event);
                mediaWindow.draw();
                return;
            }
            if (windowId == SDL_GetWindowID(controlWindow.window)) {
                controlWindow.handleEvent(event);
                if (event.type == SDL_EVENT_MOUSE_MOTION && !statusLabel.visible) {
                    hoveredHint = "";
                    foreach (child; controls.children) {
                        auto icon = cast(IconButton)child;
                        if (icon !is null && icon.enabled && icon.hovered) {
                            hoveredHint = icon.fallback;
                            break;
                        }
                    }
                    profileLabel.setText(hoveredHint.length ? hoveredHint :
                        "Profile: " ~ (services.state.profile.length ?
                            services.state.profile : "unavailable"));
                }
                controlWindow.draw();
                return;
            }
        }
        if (event.type == SDL_EVENT_MOUSE_BUTTON_UP &&
                event.button.button == SDL_BUTTON_RIGHT) {
            foreach (i, button; trayButtons) if (button.visible &&
                    button.contains(event.button.x, event.button.y)) {
                if (!services.activateTray(trayItems[i], true)) showError();
                return;
            }
        }
        super.handleEvent(event);
        if (event.type == SDL_EVENT_WINDOW_RESIZED) layout();
    }

    override int idleTimeoutMs() { return 1_000; }

    override bool onIdle() {
        if (++idleTicks % 3 == 0) updateState();
        else if (services.state.media.playing && services.state.media.length > 0) {
            auto media = &services.state.media;
            media.position = min(media.position + 1_000_000, media.length);
            timeLabel.setText(stamp(media.position) ~ "/" ~ stamp(media.length));
            if (!seekSlider.dragging)
                seekSlider.setValue(100.0 * media.position / media.length);
        }
        if (controlsOpen) controlWindow.draw();
        if (mediaOpen) mediaWindow.draw();
        return true;
    }

    override void draw() {
        updateClock();
        super.draw();
    }
}

unittest {
    assert(!regularFile(buildPath(tempDir(),
        "mcw-bar-missing-" ~ randomUUID().toString())));
    assert(regularFile("liberation-sans.ttf"));
}
