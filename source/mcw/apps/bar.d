module mcw.apps.bar;

import std.algorithm : min, max;
import std.conv : to;
import std.datetime : Clock, SysTime, dur;
import std.file : FileException, isFile, remove, tempDir;
import std.math : sqrt;
import std.path : buildPath;
import std.process : execute;
import std.string : toStringz, startsWith;
import std.uri : decode;
import std.uuid : randomUUID;
import core.sys.posix.unistd : getpid;
import core.thread : Thread;

import bindbc.sdl;
import mcw.bar_services;
import mcw.window;
import mcw.widgets;

private enum bg = SDL_Color(22, 27, 37, 255);
private enum panelBg = SDL_Color(31, 38, 52, 255);
private enum accent = SDL_Color(101, 178, 227, 255);
private enum muted = SDL_Color(171, 185, 204, 255);

private enum DeviceOperation { wifiList, wifiPower, wifiConnect,
    bluetoothList, bluetoothPower, bluetoothConnect }

private struct DeviceRequest {
    DeviceOperation operation;
    bool option;
    BarWifiNetwork network;
    BarBluetoothDevice device;
}

// The worker only calls BarServices. Widgets and SDL windows stay on the UI thread.
private class DeviceJob {
    BarServices services;
    DeviceRequest request;
    Thread thread;
    BarWifiNetwork[] wifi;
    BarBluetoothDevice[] bluetooth;
    bool succeeded;
    string error;
    private bool finished;

    this(BarServices services, DeviceRequest request) {
        this.services = services;
        this.request = request;
        thread = new Thread(&run);
        thread.start();
    }

    private void run() {
        try {
            services.error = "";
            final switch (request.operation) {
            case DeviceOperation.wifiList:
                wifi = services.wifiNetworks(request.option);
                succeeded = true;
                break;
            case DeviceOperation.wifiPower:
                succeeded = services.setWifiEnabled(request.option);
                break;
            case DeviceOperation.wifiConnect:
                succeeded = services.connectWifi(request.network);
                break;
            case DeviceOperation.bluetoothList:
                bluetooth = services.bluetoothDevices(request.option);
                succeeded = true;
                break;
            case DeviceOperation.bluetoothPower:
                succeeded = services.setBluetoothEnabled(request.option);
                break;
            case DeviceOperation.bluetoothConnect:
                succeeded = services.connectBluetooth(request.device);
                break;
            }
            error = services.error;
        } catch (Exception e) {
            succeeded = false;
            error = e.msg;
        }
        synchronized (this) { finished = true; }
    }

    bool done() { synchronized (this) return finished; }
    void join() { thread.join(); }
}

private class StatusJob {
    BarState state;
    uint deviceGeneration;
    Thread thread;
    private bool finished;
    bool succeeded;

    this(BarState previous, uint deviceGeneration) {
        this.state = previous;
        this.deviceGeneration = deviceGeneration;
        thread = new Thread(&run);
        thread.start();
    }

    private void run() {
        try {
            auto reader = new BarServices();
            reader.state = state;
            reader.refresh();
            state = reader.state;
            destroy(reader);
            succeeded = true;
        } catch (Exception) {}
        synchronized (this) { finished = true; }
    }

    bool done() { synchronized (this) return finished; }
    void join() { thread.join(); }
}

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
    Window trayMenuWindow;
    Canvas bar;
    Canvas controls;
    Canvas mediaPanel;
    Canvas trayMenuPanel;
    TTF_Font *font;
    Button[] desktops;
    TrayButton[] trayButtons;
    BarTrayItem[] trayItems;
    Button artButton;
    IconButton previous, playPause, next, compactPlay, controlButton, powerButton,
        saveButton, inhibitButton, bluetoothButton, wifiButton, wifiBack,
        wifiRefresh, bluetoothBack, bluetoothRefresh, bluetoothSettings,
        volumeIcon, brightnessIcon;
    IconButton[4] powerActions;
    Button wifiToggle, wifiPrevious, wifiNext;
    Button[5] wifiRows;
    Label wifiHeading, wifiEmpty;
    BarWifiNetwork[] wifiNetworks;
    size_t wifiPage;
    Button bluetoothToggle, bluetoothPrevious, bluetoothNext;
    Button[5] bluetoothRows;
    Label bluetoothHeading, bluetoothEmpty;
    BarBluetoothDevice[] bluetoothDevices;
    size_t bluetoothPage;
    Label clockLabel, trackLabel, popupTrackLabel, timeLabel, volumeLabel,
        brightnessLabel, controlsHeading, statusLabel;
    Image artwork, bigArtwork;
    CommitSlider seekSlider, volumeSlider, brightnessSlider;
    SDL_Texture *artTexture, popupArtTexture;
    string artUrl;
    string downloadedArtPath;
    BarTrayItem trayMenuItem;
    int[] trayMenuPath;
    bool controlsOpen, mediaOpen, powerOpen, trayMenuOpen, wifiOpen, bluetoothOpen;
    bool wifiLoading, bluetoothLoading, deviceQueued;
    DeviceRequest queuedDevice;
    DeviceJob deviceJob;
    StatusJob statusJob;
    uint deviceGeneration;
    uint idleTicks;
    SysTime lastMediaTick;

    this(SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title, true);
        this.font = font;
        services = new BarServices();
        lastMediaTick = Clock.currTime();
        SDL_SetWindowBordered(window, false);
        SDL_SetWindowAlwaysOnTop(window, true);
        SDL_SetWindowResizable(window, false);
        SDL_SetWindowPosition(window, 0, 0);

        bar = new Canvas(rect, renderer);
        bar.style.background_color = bg;
        bar.style.border_radius = 22;
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
        artwork = new RoundedArt(SDL_FRect(0, 0, 36, 36), renderer, null, 18, bg);
        artwork.style.background_color = SDL_Color(48, 57, 73, 255);
        artwork.style.border_radius = 18;
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
            button.style.border_radius = 100;
            button.onActivate = trayButtonAction(index);
            bar.addAnchored(button);
            trayButtons ~= button;
        }
        controlButton = makeIconButton(renderer, "configure", "Settings");
        controlButton.onActivate = () { toggleControls(); };
        bar.addAnchored(controlButton);

        mediaWindow = new Window(SDL_FRect(0, 0, 340, 360), "MCW media", true);
        SDL_SetWindowBordered(mediaWindow.window, false);
        SDL_SetWindowAlwaysOnTop(mediaWindow.window, true);
        SDL_SetWindowResizable(mediaWindow.window, false);
        mediaPanel = new Canvas(SDL_FRect(0, 0, 340, 360), mediaWindow.renderer);
        mediaPanel.style.background_color = panelBg;
        mediaPanel.style.border_radius = 26;
        mediaWindow.widget = mediaPanel;
        popupTrackLabel = makeLabel(mediaWindow.renderer, "No media playing", muted);
        place(mediaPanel, popupTrackLabel, 20, 4, 300, 20);
        bigArtwork = new RoundedArt(SDL_FRect(50, 27, 240, 240),
            mediaWindow.renderer, null, 24, panelBg);
        bigArtwork.style.background_color = SDL_Color(48, 57, 73, 255);
        bigArtwork.style.border_radius = 24;
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

        controlWindow = new Window(SDL_FRect(0, 0, 348, 185), "MCW controls", true);
        SDL_SetWindowBordered(controlWindow.window, false);
        SDL_SetWindowAlwaysOnTop(controlWindow.window, true);
        SDL_SetWindowResizable(controlWindow.window, false);
        controls = new Canvas(SDL_FRect(0, 0, 348, 185), controlWindow.renderer);
        controls.style.background_color = panelBg;
        controls.style.border_radius = 26;
        controlWindow.widget = controls;
        createControls();
        trayMenuWindow = new Window(SDL_FRect(0, 0, 240, 40), "MCW tray menu", true);
        SDL_SetWindowBordered(trayMenuWindow.window, false);
        SDL_SetWindowAlwaysOnTop(trayMenuWindow.window, true);
        SDL_SetWindowResizable(trayMenuWindow.window, false);
        trayMenuPanel = new Canvas(SDL_FRect(0, 0, 240, 40), trayMenuWindow.renderer);
        trayMenuPanel.style.background_color = panelBg;
        trayMenuPanel.style.border_radius = 16;
        trayMenuWindow.widget = trayMenuPanel;
        layout();
        updateState();
    }

    ~this() {
        if (deviceJob !is null) deviceJob.join();
        if (statusJob !is null) statusJob.join();
        if (artTexture !is null) SDL_DestroyTexture(artTexture);
        if (popupArtTexture !is null) SDL_DestroyTexture(popupArtTexture);
        foreach (button; trayButtons) button.releaseIcon();
        foreach (button; [previous, playPause, next, compactPlay,
                controlButton, powerButton, saveButton, inhibitButton,
                bluetoothButton, wifiButton, wifiBack, wifiRefresh,
                bluetoothBack, bluetoothRefresh, bluetoothSettings,
                volumeIcon, brightnessIcon])
            button.releaseIcon();
        foreach (button; powerActions) button.releaseIcon();
        if (downloadedArtPath.length) {
            try remove(downloadedArtPath);
            catch (Exception) {}
        }
        destroy(controlWindow);
        destroy(mediaWindow);
        destroy(trayMenuWindow);
        destroy(services);
    }

    private Button makeButton(SDL_Renderer *target, string caption) {
        auto button = new Button(SDL_FRect(0, 0, 35, 32), target, font, caption);
        button.style.background_color = SDL_Color(43, 54, 70, 255);
        button.style.hover_color = SDL_Color(66, 91, 118, 255);
        button.style.pressed_color = SDL_Color(48, 122, 171, 255);
        button.style.focused_border_color = accent;
        button.style.border_radius = 100;
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
        button.style.border_radius = 100;
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
        controlsHeading = makeLabel(controlWindow.renderer, "Quick controls", accent);
        place(controls, controlsHeading, 18, 10, 278, 28);
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
        place(controls, saveButton, 18, 133, 52, 38);
        inhibitButton = makeIconButton(controlWindow.renderer,
            "system-suspend-inhibited", "Do not sleep");
        inhibitButton.onActivate = () {
            if (!services.toggleInhibit()) showError();
            updateState();
        };
        place(controls, inhibitButton, 78, 133, 52, 38);
        bluetoothButton = makeIconButton(controlWindow.renderer,
            "network-bluetooth", "Bluetooth devices");
        bluetoothButton.onActivate = () { toggleBluetoothMenu(); };
        place(controls, bluetoothButton, 138, 133, 52, 38);
        wifiButton = makeIconButton(controlWindow.renderer,
            "network-wireless", "Wi-Fi networks");
        wifiButton.onActivate = () { toggleWifiMenu(); };
        place(controls, wifiButton, 198, 133, 52, 38);
        powerButton = makeIconButton(controlWindow.renderer,
            "system-shutdown", "Power and session");
        powerButton.onActivate = () { togglePowerMenu(); };
        place(controls, powerButton, 264, 133, 66, 38);
        statusLabel = makeLabel(controlWindow.renderer, "", SDL_Color(238, 166, 144, 255));
        statusLabel.text_placement = Label.TextPlacement.StartCenter;
        place(controls, statusLabel, 18, 10, 278, 28);
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
            place(controls, button, 18 + i * 82, 181, 66, 38);
            button.visible = false;
            powerActions[i] = button;
        }

        wifiHeading = makeLabel(controlWindow.renderer, "Wi-Fi networks", accent);
        place(controls, wifiHeading, 18, 181, 190, 30);
        wifiBack = makeIconButton(controlWindow.renderer, "go-previous", "Back");
        wifiBack.onActivate = () { toggleWifiMenu(); };
        place(controls, wifiBack, 218, 181, 44, 30);
        wifiRefresh = makeIconButton(controlWindow.renderer, "view-refresh", "Refresh");
        wifiRefresh.onActivate = () { refreshWifiMenu(true); };
        place(controls, wifiRefresh, 272, 181, 58, 30);
        wifiToggle = makeButton(controlWindow.renderer, "Turn Wi-Fi on");
        wifiToggle.onActivate = () {
            requestDevice(DeviceRequest(DeviceOperation.wifiPower,
                !services.state.wifiEnabled));
        };
        place(controls, wifiToggle, 18, 215, 312, 32);
        wifiEmpty = makeLabel(controlWindow.renderer, "No networks found", muted);
        place(controls, wifiEmpty, 18, 252, 312, 30);
        foreach (i; 0 .. wifiRows.length) {
            auto row = makeButton(controlWindow.renderer, "");
            row.text_placement = Label.TextPlacement.StartCenter;
            row.style.padding_left = 12;
            row.onActivate = wifiRowAction(i);
            place(controls, row, 18, 252 + i * 34, 312, 30);
            wifiRows[i] = row;
        }
        wifiPrevious = makeButton(controlWindow.renderer, "‹  Previous");
        wifiPrevious.onActivate = () {
            if (wifiPage > 0) { wifiPage--; renderWifiMenu(); }
        };
        place(controls, wifiPrevious, 18, 422, 150, 30);
        wifiNext = makeButton(controlWindow.renderer, "Next  ›");
        wifiNext.onActivate = () {
            if ((wifiPage + 1) * wifiRows.length < wifiNetworks.length) {
                wifiPage++;
                renderWifiMenu();
            }
        };
        place(controls, wifiNext, 180, 422, 150, 30);
        setWifiMenuVisible(false);

        bluetoothHeading = makeLabel(controlWindow.renderer, "Bluetooth devices", accent);
        place(controls, bluetoothHeading, 18, 181, 145, 30);
        bluetoothSettings = makeIconButton(controlWindow.renderer,
            "configure", "Bluetooth settings");
        bluetoothSettings.onActivate = () {
            if (!services.openBluetooth()) showError();
            else closeControls();
        };
        place(controls, bluetoothSettings, 168, 181, 40, 30);
        bluetoothBack = makeIconButton(controlWindow.renderer, "go-previous", "Back");
        bluetoothBack.onActivate = () { toggleBluetoothMenu(); };
        place(controls, bluetoothBack, 218, 181, 44, 30);
        bluetoothRefresh = makeIconButton(controlWindow.renderer, "view-refresh", "Scan");
        bluetoothRefresh.onActivate = () { refreshBluetoothMenu(true); };
        place(controls, bluetoothRefresh, 272, 181, 58, 30);
        bluetoothToggle = makeButton(controlWindow.renderer, "Turn Bluetooth on");
        bluetoothToggle.onActivate = () {
            requestDevice(DeviceRequest(DeviceOperation.bluetoothPower,
                !services.state.bluetoothEnabled));
        };
        place(controls, bluetoothToggle, 18, 215, 312, 32);
        bluetoothEmpty = makeLabel(controlWindow.renderer, "No devices found", muted);
        place(controls, bluetoothEmpty, 18, 252, 312, 30);
        foreach (i; 0 .. bluetoothRows.length) {
            auto row = makeButton(controlWindow.renderer, "");
            row.text_placement = Label.TextPlacement.StartCenter;
            row.style.padding_left = 12;
            row.onActivate = bluetoothRowAction(i);
            place(controls, row, 18, 252 + i * 34, 312, 30);
            bluetoothRows[i] = row;
        }
        bluetoothPrevious = makeButton(controlWindow.renderer, "‹  Previous");
        bluetoothPrevious.onActivate = () {
            if (bluetoothPage > 0) { bluetoothPage--; renderBluetoothMenu(); }
        };
        place(controls, bluetoothPrevious, 18, 422, 150, 30);
        bluetoothNext = makeButton(controlWindow.renderer, "Next  ›");
        bluetoothNext.onActivate = () {
            if ((bluetoothPage + 1) * bluetoothRows.length < bluetoothDevices.length) {
                bluetoothPage++;
                renderBluetoothMenu();
            }
        };
        place(controls, bluetoothNext, 180, 422, 150, 30);
        setBluetoothMenuVisible(false);
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
        controlsHeading.visible = false;
        statusLabel.visible = true;
    }

    private void clearError() {
        controlsHeading.visible = true;
        statusLabel.visible = false;
    }

    private void delegate() trayButtonAction(size_t index) {
        return () {
            if (index >= trayItems.length) return;
            if (trayItems[index].itemIsMenu)
                openTrayMenu(trayItems[index], trayButtons[index].rect.x);
            else if (!services.activateTray(trayItems[index])) showError();
        };
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

    private void updateState(bool refresh = true) {
        if (deviceJob !is null) return;
        if (refresh) services.refresh();
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
        saveButton.style.background_color = state.profile == "power-saver" ? accent :
            SDL_Color(43, 54, 70, 255);
        inhibitButton.style.background_color = services.sleepInhibited() ? accent :
            SDL_Color(43, 54, 70, 255);
        wifiButton.setIcon(state.wifiEnabled ? "network-wireless" :
            "network-wireless-disconnected");
        wifiButton.style.background_color = wifiOpen || state.wifiEnabled ? accent :
            SDL_Color(43, 54, 70, 255);
        bluetoothButton.style.background_color = bluetoothOpen ||
            state.bluetoothEnabled ? accent : SDL_Color(43, 54, 70, 255);
        if (wifiOpen) renderWifiMenu();
        if (bluetoothOpen) renderBluetoothMenu();
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
        if (trayMenuOpen) closeTrayMenu();
        mediaOpen = true;
        positionMedia();
        SDL_ShowWindow(mediaWindow.window);
        updateState(false);
        mediaWindow.draw();
    }

    private void closeMedia() {
        mediaOpen = false;
        SDL_HideWindow(mediaWindow.window);
    }

    private void toggleControls() {
        if (controlsOpen) { closeControls(); return; }
        if (mediaOpen) closeMedia();
        if (trayMenuOpen) closeTrayMenu();
        controlsOpen = true;
        positionControls();
        SDL_ShowWindow(controlWindow.window);
        updateState(false);
        controlWindow.draw();
    }

    private void closeControls() {
        controlsOpen = false;
        powerOpen = false;
        wifiOpen = false;
        bluetoothOpen = false;
        foreach (button; powerActions) button.visible = false;
        setWifiMenuVisible(false);
        setBluetoothMenuVisible(false);
        clearError();
        SDL_SetWindowSize(controlWindow.window, 348, 185);
        controls.rect = SDL_FRect(0, 0, 348, 185);
        SDL_HideWindow(controlWindow.window);
    }

    private void togglePowerMenu() {
        clearError();
        if (wifiOpen) {
            wifiOpen = false;
            setWifiMenuVisible(false);
        }
        if (bluetoothOpen) {
            bluetoothOpen = false;
            setBluetoothMenuVisible(false);
        }
        powerOpen = !powerOpen;
        foreach (button; powerActions) button.visible = powerOpen;
        int height = powerOpen ? 233 : 185;
        SDL_SetWindowSize(controlWindow.window, 348, height);
        controls.rect = SDL_FRect(0, 0, 348, height);
        controlWindow.draw();
    }

    private void requestDevice(DeviceRequest request) {
        deviceGeneration++;
        bool wifiRequest = request.operation == DeviceOperation.wifiList ||
            request.operation == DeviceOperation.wifiPower ||
            request.operation == DeviceOperation.wifiConnect;
        if (wifiRequest) {
            wifiLoading = true;
            if (wifiOpen) renderWifiMenu();
        } else {
            bluetoothLoading = true;
            if (bluetoothOpen) renderBluetoothMenu();
        }
        if (deviceJob !is null) {
            // Keep the latest request; scans and device actions must not access
            // the same service object concurrently.
            if (deviceQueued) {
                bool oldWifi = queuedDevice.operation == DeviceOperation.wifiList ||
                    queuedDevice.operation == DeviceOperation.wifiPower ||
                    queuedDevice.operation == DeviceOperation.wifiConnect;
                if (oldWifi && !wifiRequest) wifiLoading = false;
                if (!oldWifi && wifiRequest) bluetoothLoading = false;
            }
            queuedDevice = request;
            deviceQueued = true;
            return;
        }
        deviceJob = new DeviceJob(services, request);
    }

    private void finishDeviceJob() {
        if (deviceJob is null || !deviceJob.done()) return;
        auto job = deviceJob;
        job.join();
        deviceJob = null;
        auto request = job.request;
        bool wifiRequest = request.operation == DeviceOperation.wifiList ||
            request.operation == DeviceOperation.wifiPower ||
            request.operation == DeviceOperation.wifiConnect;
        if (job.error.length) services.error = job.error;
        else services.error = "";
        DeviceRequest followup;
        bool refreshAfter;
        final switch (request.operation) {
        case DeviceOperation.wifiList:
            wifiNetworks = job.wifi;
            wifiPage = 0;
            wifiLoading = false;
            break;
        case DeviceOperation.wifiPower:
            if (job.succeeded) {
                services.state.wifiEnabled = request.option;
                if (!request.option) wifiNetworks = null;
                else {
                    followup = DeviceRequest(DeviceOperation.wifiList, true);
                    refreshAfter = wifiOpen;
                }
            }
            wifiLoading = false;
            break;
        case DeviceOperation.wifiConnect:
            wifiLoading = false;
            followup = DeviceRequest(DeviceOperation.wifiList, false);
            refreshAfter = job.succeeded && wifiOpen;
            break;
        case DeviceOperation.bluetoothList:
            bluetoothDevices = job.bluetooth;
            bluetoothPage = 0;
            bluetoothLoading = false;
            break;
        case DeviceOperation.bluetoothPower:
            if (job.succeeded) {
                services.state.bluetoothEnabled = request.option;
                if (!request.option) bluetoothDevices = null;
                else {
                    followup = DeviceRequest(DeviceOperation.bluetoothList, true);
                    refreshAfter = bluetoothOpen;
                }
            }
            bluetoothLoading = false;
            break;
        case DeviceOperation.bluetoothConnect:
            bluetoothLoading = false;
            followup = DeviceRequest(DeviceOperation.bluetoothList, false);
            refreshAfter = job.succeeded && bluetoothOpen;
            break;
        }
        if (wifiRequest && wifiOpen) {
            if (job.succeeded && !job.error.length) clearError();
            else if (!job.succeeded || job.error.length) showError();
            renderWifiMenu();
        } else if (!wifiRequest && bluetoothOpen) {
            if (job.succeeded && !job.error.length) clearError();
            else if (!job.succeeded || job.error.length) showError();
            renderBluetoothMenu();
        }
        updateState(false);
        if (deviceQueued) {
            auto next = queuedDevice;
            deviceQueued = false;
            requestDevice(next);
        } else if (refreshAfter) requestDevice(followup);
    }

    private void setWifiMenuVisible(bool visible) {
        foreach (child; [cast(Widget)wifiHeading, wifiBack, wifiRefresh,
                wifiToggle, wifiEmpty, wifiPrevious, wifiNext])
            child.visible = visible;
        foreach (row; wifiRows) row.visible = visible;
    }

    private void renderWifiMenu() {
        if (!wifiOpen) return;
        setWifiMenuVisible(true);
        wifiToggle.enabled = services.state.wifiAvailable && !wifiLoading;
        wifiToggle.setText(services.state.wifiEnabled ? "Turn Wi-Fi off" :
            "Turn Wi-Fi on");
        wifiRefresh.enabled = services.state.wifiEnabled && !wifiLoading;
        size_t start = wifiPage * wifiRows.length;
        if (start >= wifiNetworks.length) { wifiPage = 0; start = 0; }
        auto count = min(wifiRows.length, wifiNetworks.length - start);
        foreach (i, row; wifiRows) {
            row.visible = !wifiLoading && services.state.wifiEnabled && i < count;
            if (!row.visible) continue;
            auto network = wifiNetworks[start + i];
            auto security = network.security.length && network.security != "--" ?
                "  •  secured" : "";
            row.setText((network.connected ? "✓  " : "") ~ network.ssid ~
                security ~ "  " ~ to!string(network.signal) ~ "%");
            row.enabled = !network.connected;
            row.style.background_color = network.connected ? accent :
                SDL_Color(43, 54, 70, 255);
        }
        wifiEmpty.visible = wifiLoading || !services.state.wifiEnabled || !wifiNetworks.length;
        wifiEmpty.setText(wifiLoading ? "Loading networks…" :
            !services.state.wifiAvailable ?
            "NetworkManager unavailable" : !services.state.wifiEnabled ?
            "Wi-Fi is off" : "No networks found");
        bool pages = !wifiLoading && wifiNetworks.length > wifiRows.length;
        wifiPrevious.visible = pages;
        wifiNext.visible = pages;
        wifiPrevious.enabled = wifiPage > 0;
        wifiNext.enabled = (wifiPage + 1) * wifiRows.length < wifiNetworks.length;
        int height = pages ? 460 :
            262 + cast(int)max(1, count) * 34;
        SDL_SetWindowSize(controlWindow.window, 348, height);
        controls.rect = SDL_FRect(0, 0, 348, height);
        controlWindow.draw();
    }

    private void refreshWifiMenu(bool rescan) {
        requestDevice(DeviceRequest(DeviceOperation.wifiList, rescan));
    }

    private void delegate() wifiRowAction(size_t index) {
        return () {
            auto at = wifiPage * wifiRows.length + index;
            if (at >= wifiNetworks.length) return;
            DeviceRequest request;
            request.operation = DeviceOperation.wifiConnect;
            request.network = wifiNetworks[at];
            requestDevice(request);
        };
    }

    private void toggleWifiMenu() {
        clearError();
        if (wifiOpen) {
            wifiOpen = false;
            setWifiMenuVisible(false);
            SDL_SetWindowSize(controlWindow.window, 348, 185);
            controls.rect = SDL_FRect(0, 0, 348, 185);
        } else {
            powerOpen = false;
            foreach (button; powerActions) button.visible = false;
            if (bluetoothOpen) {
                bluetoothOpen = false;
                setBluetoothMenuVisible(false);
            }
            wifiOpen = true;
            refreshWifiMenu(true);
        }
        controlWindow.draw();
    }

    private void setBluetoothMenuVisible(bool visible) {
        foreach (child; [cast(Widget)bluetoothHeading, bluetoothBack,
                bluetoothRefresh, bluetoothSettings, bluetoothToggle, bluetoothEmpty,
                bluetoothPrevious, bluetoothNext])
            child.visible = visible;
        foreach (row; bluetoothRows) row.visible = visible;
    }

    private void renderBluetoothMenu() {
        if (!bluetoothOpen) return;
        setBluetoothMenuVisible(true);
        bluetoothToggle.enabled = services.state.bluetoothAvailable && !bluetoothLoading;
        bluetoothToggle.setText(services.state.bluetoothEnabled ?
            "Turn Bluetooth off" : "Turn Bluetooth on");
        bluetoothRefresh.enabled = services.state.bluetoothEnabled && !bluetoothLoading;
        size_t start = bluetoothPage * bluetoothRows.length;
        if (start >= bluetoothDevices.length) { bluetoothPage = 0; start = 0; }
        auto count = min(bluetoothRows.length, bluetoothDevices.length - start);
        foreach (i, row; bluetoothRows) {
            row.visible = !bluetoothLoading && services.state.bluetoothEnabled && i < count;
            if (!row.visible) continue;
            auto device = bluetoothDevices[start + i];
            row.setText((device.connected ? "✓  " : "") ~ device.name ~
                (device.connected ? "  •  Disconnect" :
                    device.paired ? "  •  Connect" : "  •  Pair"));
            row.style.background_color = device.connected ? accent :
                SDL_Color(43, 54, 70, 255);
        }
        bluetoothEmpty.visible = bluetoothLoading || !services.state.bluetoothEnabled ||
            !bluetoothDevices.length;
        bluetoothEmpty.setText(bluetoothLoading ? "Loading devices…" :
            !services.state.bluetoothAvailable ?
            "No Bluetooth adapter" : !services.state.bluetoothEnabled ?
            "Bluetooth is off" : "No devices found. Scan to search.");
        bool pages = !bluetoothLoading && bluetoothDevices.length > bluetoothRows.length;
        bluetoothPrevious.visible = pages;
        bluetoothNext.visible = pages;
        bluetoothPrevious.enabled = bluetoothPage > 0;
        bluetoothNext.enabled =
            (bluetoothPage + 1) * bluetoothRows.length < bluetoothDevices.length;
        int height = pages ? 460 : 262 + cast(int)max(1, count) * 34;
        SDL_SetWindowSize(controlWindow.window, 348, height);
        controls.rect = SDL_FRect(0, 0, 348, height);
        controlWindow.draw();
    }

    private void refreshBluetoothMenu(bool rescan) {
        requestDevice(DeviceRequest(DeviceOperation.bluetoothList, rescan));
    }

    private void delegate() bluetoothRowAction(size_t index) {
        return () {
            auto at = bluetoothPage * bluetoothRows.length + index;
            if (at >= bluetoothDevices.length) return;
            DeviceRequest request;
            request.operation = DeviceOperation.bluetoothConnect;
            request.device = bluetoothDevices[at];
            requestDevice(request);
        };
    }

    private void toggleBluetoothMenu() {
        clearError();
        if (bluetoothOpen) {
            bluetoothOpen = false;
            setBluetoothMenuVisible(false);
            SDL_SetWindowSize(controlWindow.window, 348, 185);
            controls.rect = SDL_FRect(0, 0, 348, 185);
        } else {
            powerOpen = false;
            foreach (button; powerActions) button.visible = false;
            if (wifiOpen) {
                wifiOpen = false;
                setWifiMenuVisible(false);
            }
            bluetoothOpen = true;
            refreshBluetoothMenu(true);
        }
        controlWindow.draw();
    }

    private void closeTrayMenu() {
        trayMenuOpen = false;
        trayMenuPath.length = 0;
        SDL_HideWindow(trayMenuWindow.window);
    }

    private Button trayMenuRow(string text, int y, bool enabled = true) {
        auto button = new Button(SDL_FRect(8, y, 224, 30),
            trayMenuWindow.renderer, font, text);
        button.text_placement = Label.TextPlacement.StartCenter;
        button.style.padding_left = 10;
        button.style.background_color = SDL_Color(0, 0, 0, 0);
        button.style.hover_color = SDL_Color(55, 69, 88, 255);
        button.style.border_radius = 10;
        button.text_color = enabled ? SDL_Color(236, 241, 247, 255) : muted;
        button.enabled = enabled;
        place(trayMenuPanel, button, 8, y, 224, 30);
        return button;
    }

    private void delegate() trayMenuAction(int id, bool submenu) {
        return () {
            if (submenu) {
                trayMenuPath ~= id;
                if (!rebuildTrayMenu(id)) {
                    trayMenuPath.length--;
                    showError();
                }
                trayMenuWindow.draw();
            } else {
                bool succeeded = services.activateTrayMenu(trayMenuItem, id);
                closeTrayMenu();
                if (!succeeded) showError();
            }
        };
    }

    private bool rebuildTrayMenu(int parentId) {
        auto entries = services.trayMenu(trayMenuItem, parentId);
        if (entries is null) return false;
        while (trayMenuPanel.children.length) trayMenuPanel.removeChild(0);
        int height = 16 + (trayMenuPath.length ? 32 : 0);
        foreach (entry; entries) height += entry.separator ? 10 : 32;
        height = max(24, height);
        SDL_SetWindowSize(trayMenuWindow.window, 240, height);
        trayMenuPanel.rect = SDL_FRect(0, 0, 240, height);
        int y = 8;
        if (trayMenuPath.length) {
            auto back = trayMenuRow("‹  Back", y);
            back.onActivate = () {
                trayMenuPath.length--;
                rebuildTrayMenu(trayMenuPath.length ? trayMenuPath[$ - 1] : 0);
                trayMenuWindow.draw();
            };
            y += 32;
        }
        foreach (entry; entries) {
            if (entry.separator) {
                auto line = new Widget(SDL_FRect(16, y + 4, 208, 1),
                    trayMenuWindow.renderer);
                line.style.background_color = SDL_Color(75, 90, 109, 255);
                line.focusable = false;
                line.enabled = false;
                place(trayMenuPanel, line, 16, y + 4, 208, 1);
                y += 10;
                continue;
            }
            auto caption = (entry.checked ? "✓  " : "") ~ entry.label ~
                (entry.submenu ? "  ›" : "");
            auto button = trayMenuRow(caption, y, entry.enabled);
            button.onActivate = trayMenuAction(entry.id, entry.submenu);
            y += 32;
        }
        return true;
    }

    private void openTrayMenu(BarTrayItem item, float anchorX) {
        if (trayMenuOpen) closeTrayMenu();
        if (item.menu.length == 0 || item.menu == "/NO_DBUSMENU") {
            if (!services.activateTray(item, true)) showError();
            return;
        }
        if (controlsOpen) closeControls();
        if (mediaOpen) closeMedia();
        trayMenuItem = item;
        trayMenuPath.length = 0;
        if (!rebuildTrayMenu(0)) { showError(); return; }
        int x, y;
        SDL_GetWindowPosition(window, &x, &y);
        SDL_SetWindowPosition(trayMenuWindow.window,
            max(0, x + cast(int)anchorX + 28 - 240), y + cast(int)rect.h);
        trayMenuOpen = true;
        SDL_ShowWindow(trayMenuWindow.window);
        trayMenuWindow.draw();
    }

    override void handleEvent(SDL_Event *event) {
        if (event is null) return;
        const barId = SDL_GetWindowID(window);
        const controlsId = SDL_GetWindowID(controlWindow.window);
        const mediaId = SDL_GetWindowID(mediaWindow.window);
        const trayMenuId = SDL_GetWindowID(trayMenuWindow.window);
        if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED &&
                event.window.windowID == barId) {
            quit = true;
            return;
        }
        if (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE) {
            if (trayMenuOpen) closeTrayMenu();
            if (mediaOpen) closeMedia();
            if (controlsOpen) closeControls();
            return;
        }
        if (event.type >= SDL_EVENT_WINDOW_FIRST &&
                event.type <= SDL_EVENT_WINDOW_LAST) {
            auto id = event.window.windowID;
            if (id == trayMenuId) {
                if (trayMenuOpen) {
                    if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED) closeTrayMenu();
                    else trayMenuWindow.handleEvent(event);
                }
                return;
            }
            if (id == mediaId) {
                if (mediaOpen) {
                    if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED) closeMedia();
                    else mediaWindow.handleEvent(event);
                }
                return;
            }
            if (id == controlsId) {
                if (controlsOpen) {
                    if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED) closeControls();
                    else controlWindow.handleEvent(event);
                }
                return;
            }
            if (id != barId) return;
        }
        if (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN ||
                event.type == SDL_EVENT_MOUSE_BUTTON_UP ||
                event.type == SDL_EVENT_MOUSE_MOTION || event.type == SDL_EVENT_KEY_DOWN ||
                event.type == SDL_EVENT_KEY_UP || event.type == SDL_EVENT_MOUSE_WHEEL) {
            uint windowId = event.type == SDL_EVENT_MOUSE_MOTION ? event.motion.windowID :
                event.type == SDL_EVENT_MOUSE_BUTTON_DOWN || event.type == SDL_EVENT_MOUSE_BUTTON_UP ?
                event.button.windowID : event.type == SDL_EVENT_MOUSE_WHEEL ?
                event.wheel.windowID : event.key.windowID;
            if (windowId == mediaId) {
                if (mediaOpen) {
                    mediaWindow.handleEvent(event);
                    mediaWindow.draw();
                }
                return;
            }
            if (windowId == trayMenuId) {
                if (trayMenuOpen) {
                    trayMenuWindow.handleEvent(event);
                    if (trayMenuOpen) trayMenuWindow.draw();
                }
                return;
            }
            if (windowId == controlsId) {
                if (controlsOpen) {
                    controlWindow.handleEvent(event);
                    if (controlsOpen) controlWindow.draw();
                }
                return;
            }
            if (windowId != barId) return;
        }
        if ((event.type == SDL_EVENT_MOUSE_BUTTON_DOWN ||
                event.type == SDL_EVENT_MOUSE_BUTTON_UP) &&
                event.button.button == SDL_BUTTON_RIGHT) {
            foreach (i, button; trayButtons) if (button.visible &&
                    button.contains(event.button.x, event.button.y)) {
                if (event.type == SDL_EVENT_MOUSE_BUTTON_UP)
                    openTrayMenu(trayItems[i], button.rect.x);
                return;
            }
        }
        if (trayMenuOpen && event.type == SDL_EVENT_MOUSE_BUTTON_DOWN &&
                event.button.windowID == barId) closeTrayMenu();
        super.handleEvent(event);
        if (event.type == SDL_EVENT_WINDOW_RESIZED &&
                event.window.windowID == barId) layout();
    }

    override int idleTimeoutMs() {
        return deviceJob !is null || statusJob !is null ? 50 : 1_000;
    }

    override bool onIdle() {
        bool repaint;
        if (deviceJob !is null && deviceJob.done()) {
            finishDeviceJob();
            repaint = true;
        }
        if (statusJob !is null && statusJob.done()) {
            auto completed = statusJob;
            completed.join();
            statusJob = null;
            if (completed.succeeded &&
                    completed.deviceGeneration == deviceGeneration &&
                    deviceJob is null) {
                services.state = completed.state;
                updateState(false);
                repaint = true;
            }
        }
        if (deviceJob is null && statusJob is null && ++idleTicks % 3 == 0)
            statusJob = new StatusJob(services.state, deviceGeneration);
        auto now = Clock.currTime();
        if (now - lastMediaTick >= dur!"seconds"(1)) {
            lastMediaTick = now;
            repaint = true;
            if (services.state.media.playing && services.state.media.length > 0) {
                auto media = &services.state.media;
                media.position = min(media.position + 1_000_000, media.length);
                timeLabel.setText(stamp(media.position) ~ "/" ~ stamp(media.length));
                if (!seekSlider.dragging)
                    seekSlider.setValue(100.0 * media.position / media.length);
            }
        }
        if (repaint) {
            if (controlsOpen) controlWindow.draw();
            if (mediaOpen) mediaWindow.draw();
            if (trayMenuOpen) trayMenuWindow.draw();
        }
        return repaint;
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
