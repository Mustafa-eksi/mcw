module mcw.tests.bar_window;

import std.algorithm : canFind;
import std.file : mkdirRecurse;
import std.path : buildPath;
import std.string : toStringz;
import std.datetime : dur;
import core.thread : Thread;
import core.sync.semaphore : Semaphore;

import bindbc.sdl;
import bindbc.loader : LoadMsg;
import mcw.apps.bar;
import mcw.bar_services : BarServices, BarTrayItem, BarTrayMenuEntry,
    BarWifiNetwork, BarBluetoothDevice;

private class FakeTrayServices : BarServices {
    int parentId = -1;
    int clickedId = -1;

    override BarTrayMenuEntry[] trayMenu(BarTrayItem item, int parentId = 0) {
        this.parentId = parentId;
        BarTrayMenuEntry entry;
        if (parentId == 0) {
            entry.id = 7;
            entry.label = "Open";
            auto open = entry;
            entry.id = 9;
            entry.label = "More";
            entry.submenu = true;
            return [open, entry];
        }
        entry.id = 11;
        entry.label = "Nested action";
        return [entry];
    }

    override bool activateTrayMenu(BarTrayItem item, int id) {
        clickedId = id;
        return true;
    }
}

private class FakeWifiServices : BarServices {
    string connectedSsid;
    bool scanned;

    this() { state.wifiAvailable = true; }
    override void refresh() {}
    override BarWifiNetwork[] wifiNetworks(bool rescan = false) {
        scanned = rescan;
        if (!state.wifiEnabled) return null;
        BarWifiNetwork[] result;
        foreach (i; 0 .. 6)
            result ~= BarWifiNetwork("Network " ~ cast(char)('A' + i),
                "WPA2", 90 - cast(int)i * 10, false);
        return result;
    }
    override bool setWifiEnabled(bool enabled) {
        state.wifiEnabled = enabled;
        return true;
    }
    override bool connectWifi(BarWifiNetwork network) {
        connectedSsid = network.ssid;
        return true;
    }
}

private class FakeBluetoothServices : BarServices {
    string selectedAddress;
    bool scanned, connected;
    bool settingsOpened;

    this() { state.bluetoothAvailable = true; }
    override void refresh() {}
    override BarBluetoothDevice[] bluetoothDevices(bool rescan = false) {
        scanned = rescan;
        if (!state.bluetoothEnabled) return null;
        BarBluetoothDevice[] result;
        foreach (i; 0 .. 6)
            result ~= BarBluetoothDevice("AA:BB:CC:DD:EE:0" ~ cast(char)('0' + i),
                "Device " ~ cast(char)('A' + i), i == 0, connected && i == 0);
        return result;
    }
    override bool setBluetoothEnabled(bool enabled) {
        state.bluetoothEnabled = enabled;
        return true;
    }
    override bool connectBluetooth(BarBluetoothDevice device) {
        selectedAddress = device.address;
        connected = !device.connected;
        return true;
    }
    override bool openBluetooth() {
        settingsOpened = true;
        return true;
    }
}

private class BlockingWifiServices : BarServices {
    Semaphore releaseScan;
    this() {
        state.wifiAvailable = true;
        state.wifiEnabled = true;
        releaseScan = new Semaphore();
    }
    override void refresh() {}
    override BarWifiNetwork[] wifiNetworks(bool rescan = false) {
        releaseScan.wait();
        return [BarWifiNetwork("Delayed network", "WPA2", 80, false)];
    }
}

private SDL_Event mouse(uint type, uint windowId, float x, float y) {
    SDL_Event event = SDL_Event();
    event.type = type;
    event.button.windowID = windowId;
    event.button.button = SDL_BUTTON_LEFT;
    event.button.x = x;
    event.button.y = y;
    return event;
}

private void waitForDevices(BarWindow bar) {
    foreach (i; 0 .. 400) {
        if (bar.deviceJob is null && !bar.deviceQueued) return;
        Thread.sleep(dur!"msecs"(5));
        bar.onIdle();
    }
    assert(false, "Device operation did not complete");
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
    auto font = TTF_OpenFont("liberation-sans.ttf", 15);
    assert(font !is null);
    scope(exit) TTF_CloseFont(font);

    auto bar = new BarWindow(SDL_FRect(0, 0, 1280, 44), "Bar test", font);
    scope(exit) destroy(bar);
    assert(bar.desktops.length == 8);
    assert(bar.trayButtons.length == 6);
    assert(bar.seekSlider.rect.w > 0);
    assert(bar.seekSlider.renderer == bar.mediaWindow.renderer);
    assert(bar.timeLabel.renderer == bar.mediaWindow.renderer);
    assert(bar.previous.renderer == bar.mediaWindow.renderer);
    assert(bar.mediaPanel.rect.w == 340 && bar.mediaPanel.rect.h == 360);
    assert((SDL_GetWindowFlags(bar.window) & SDL_WINDOW_TRANSPARENT) != 0);
    assert((SDL_GetWindowFlags(bar.mediaWindow.window) & SDL_WINDOW_TRANSPARENT) != 0);
    assert((SDL_GetWindowFlags(bar.controlWindow.window) & SDL_WINDOW_TRANSPARENT) != 0);
    assert(bar.bigArtwork.rect.w == 240 && bar.bigArtwork.rect.h == 240);
    assert(bar.bigArtwork.rect.y + bar.bigArtwork.rect.h < bar.seekSlider.rect.y);
    assert(bar.seekSlider.rect.y < bar.previous.rect.y);
    assert(bar.artwork.rect.x + bar.artwork.rect.w <= bar.trackLabel.rect.x);
    assert(bar.artwork.rect.x > bar.clockLabel.rect.x + bar.clockLabel.rect.w);
    assert(bar.compactPlay.rect.x + bar.compactPlay.rect.w < bar.controlButton.rect.x);
    assert(bar.clockLabel.rect.x + bar.clockLabel.rect.w / 2 == 640);
    assert(bar.controlButton.text.length == 0);
    assert(bar.compactPlay.text.length == 0);
    assert(bar.previous.text.length == 0);
    assert(bar.controlButton.style.border_radius >= bar.controlButton.rect.h / 2);
    assert(bar.mediaPanel.style.border_radius == 26);

    // A changing tray count must not leave fixed blank slots before Settings.
    bar.trayItems.length = 2;
    SDL_Event resized = SDL_Event();
    resized.type = SDL_EVENT_WINDOW_RESIZED;
    resized.window.windowID = SDL_GetWindowID(bar.window);
    resized.window.data1 = 1280;
    resized.window.data2 = 44;
    bar.handleEvent(&resized);
    assert(bar.compactPlay.rect.x + bar.compactPlay.rect.w <
        bar.trayButtons[0].rect.x);
    assert(bar.trayButtons[1].rect.x + bar.trayButtons[1].rect.w ==
        bar.controlButton.rect.x - 5);
    bar.trayItems.length = 0;
    bar.handleEvent(&resized);

    bar.draw();
    auto surface = SDL_RenderReadPixels(bar.renderer, null);
    assert(surface !is null);
    ubyte r, g, b, a;
    assert(SDL_ReadSurfacePixel(surface, 315, 20, &r, &g, &b, &a));
    assert(r == 22 && g == 27 && b == 37);
    mkdirRecurse("test-output");
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar.bmp").toStringz));
    SDL_DestroySurface(surface);

    auto barId = SDL_GetWindowID(bar.window);
    auto down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId,
        bar.artwork.rect.x + 18, 20);
    auto up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId,
        bar.artwork.rect.x + 18, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.mediaOpen);
    bar.mediaWindow.draw();
    surface = SDL_RenderReadPixels(bar.mediaWindow.renderer, null);
    assert(surface !is null);
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar-media.bmp").toStringz));
    SDL_DestroySurface(surface);
    SDL_Event escape = SDL_Event();
    escape.type = SDL_EVENT_KEY_DOWN;
    escape.key.key = SDLK_ESCAPE;
    escape.key.windowID = SDL_GetWindowID(bar.mediaWindow.window);
    bar.handleEvent(&escape);
    assert(!bar.mediaOpen && !bar.quit);

    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId,
        bar.controlButton.rect.x + 16, 20);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId,
        bar.controlButton.rect.x + 16, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.controlsOpen);
    assert(bar.controls.rect.h == 185);
    assert(bar.controlsHeading.visible);

    auto panelId = SDL_GetWindowID(bar.controlWindow.window);
    bar.controlWindow.draw();
    surface = SDL_RenderReadPixels(bar.controlWindow.renderer, null);
    assert(surface !is null);
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar-controls-compact.bmp").toStringz));
    SDL_DestroySurface(surface);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 297, 152);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 297, 152);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.powerOpen);
    foreach (button; bar.powerActions) assert(button.visible);
    assert(bar.controls.rect.h == 233);
    bar.controlWindow.draw();
    surface = SDL_RenderReadPixels(bar.controlWindow.renderer, null);
    assert(surface !is null);
    assert(SDL_ReadSurfacePixel(surface, 264, 133, &r, &g, &b, &a));
    assert(r == 31 && g == 38 && b == 52);
    assert(SDL_ReadSurfacePixel(surface, 271, 134, &r, &g, &b, &a));
    assert(r == 31 && g == 38 && b == 52);
    assert(SDL_ReadSurfacePixel(surface, 289, 134, &r, &g, &b, &a));
    assert(r == 43 && g == 54 && b == 70);
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar-controls.bmp").toStringz));
    SDL_DestroySurface(surface);

    escape.key.windowID = panelId;
    bar.handleEvent(&escape);
    assert(!bar.controlsOpen && !bar.quit);
    escape.key.windowID = barId;
    bar.handleEvent(&escape);
    assert(!bar.quit);

    auto oldServices = bar.services;
    auto fake = new FakeTrayServices();
    bar.services = fake;
    destroy(oldServices);
    BarTrayItem trayItem;
    trayItem.service = ":1.50";
    trayItem.path = "/StatusNotifierItem";
    trayItem.menu = "/MenuBar";
    bar.trayItems = [trayItem];
    bar.trayButtons[0].visible = true;
    bar.handleEvent(&resized);
    auto trayX = bar.trayButtons[0].rect.x + 14;
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId, trayX, 20);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId, trayX, 20);
    down.button.button = SDL_BUTTON_RIGHT;
    up.button.button = SDL_BUTTON_RIGHT;
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.trayMenuOpen && fake.parentId == 0);
    bar.trayMenuWindow.draw();
    surface = SDL_RenderReadPixels(bar.trayMenuWindow.renderer, null);
    assert(surface !is null);
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar-tray-menu.bmp").toStringz));
    SDL_DestroySurface(surface);
    auto trayMenuId = SDL_GetWindowID(bar.trayMenuWindow.window);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, trayMenuId, 40, 55);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, trayMenuId, 40, 55);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.trayMenuOpen && fake.parentId == 9);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, trayMenuId, 40, 20);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, trayMenuId, 40, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.trayMenuOpen && fake.parentId == 0);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(!bar.trayMenuOpen && fake.clickedId == 7);
    trayItem.itemIsMenu = true;
    bar.trayItems[0] = trayItem;
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId, trayX, 20);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId, trayX, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.trayMenuOpen);
    bar.handleEvent(&escape);
    assert(!bar.trayMenuOpen && !bar.quit);

    oldServices = bar.services;
    auto wifi = new FakeWifiServices();
    bar.services = wifi;
    destroy(oldServices);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId,
        bar.controlButton.rect.x + 16, 20);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId,
        bar.controlButton.rect.x + 16, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.controlsOpen);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 222, 151);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 222, 151);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.wifiOpen && !bar.powerOpen);
    waitForDevices(bar);
    assert(bar.wifiEmpty.text == "Wi-Fi is off");
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 100, 230);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 100, 230);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    waitForDevices(bar);
    assert(wifi.state.wifiEnabled && wifi.scanned);
    assert(bar.wifiRows[0].visible && bar.wifiNext.visible);
    bar.controlWindow.draw();
    surface = SDL_RenderReadPixels(bar.controlWindow.renderer, null);
    assert(surface !is null);
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar-wifi-menu.bmp").toStringz));
    SDL_DestroySurface(surface);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 235, 435);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 235, 435);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.wifiPage == 1 && bar.wifiRows[0].text.canFind("Network F"));
    assert(bar.wifiRows[0].visible && bar.wifiRows[0].enabled);
    assert(bar.wifiRows[0].rect.y <= 265 &&
        265 < bar.wifiRows[0].rect.y + bar.wifiRows[0].rect.h);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 80, 265);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 80, 265);
    bar.handleEvent(&down);
    assert(bar.wifiRows[0].pressed);
    bar.handleEvent(&up);
    waitForDevices(bar);
    assert(!bar.wifiRows[0].pressed);
    assert(wifi.connectedSsid == "Network F", wifi.connectedSsid);
    escape.key.windowID = panelId;
    bar.handleEvent(&escape);
    assert(!bar.controlsOpen && !bar.quit);

    oldServices = bar.services;
    auto bluetooth = new FakeBluetoothServices();
    bar.services = bluetooth;
    destroy(oldServices);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId,
        bar.controlButton.rect.x + 16, 20);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId,
        bar.controlButton.rect.x + 16, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 162, 151);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 162, 151);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.bluetoothOpen && !bar.wifiOpen);
    waitForDevices(bar);
    assert(bar.bluetoothEmpty.text == "Bluetooth is off");
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 100, 230);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 100, 230);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    waitForDevices(bar);
    assert(bluetooth.state.bluetoothEnabled && bluetooth.scanned);
    assert(bar.bluetoothRows[0].visible && bar.bluetoothNext.visible);
    bar.controlWindow.draw();
    surface = SDL_RenderReadPixels(bar.controlWindow.renderer, null);
    assert(surface !is null);
    assert(SDL_SaveBMP(surface, buildPath("test-output", "bar-bluetooth-menu.bmp").toStringz));
    SDL_DestroySurface(surface);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 80, 265);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 80, 265);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    waitForDevices(bar);
    assert(bluetooth.selectedAddress == "AA:BB:CC:DD:EE:00" && bluetooth.connected);
    assert(bar.bluetoothRows[0].text.canFind("Disconnect"));
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    waitForDevices(bar);
    assert(!bluetooth.connected);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 80, 299);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 80, 299);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    waitForDevices(bar);
    assert(bluetooth.selectedAddress == "AA:BB:CC:DD:EE:01");
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 100, 230);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 100, 230);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    waitForDevices(bar);
    assert(!bluetooth.state.bluetoothEnabled);
    assert(bar.bluetoothEmpty.text == "Bluetooth is off");
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 188, 196);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 188, 196);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bluetooth.settingsOpened && !bar.controlsOpen);
    SDL_Event popupResize = SDL_Event();
    popupResize.type = SDL_EVENT_WINDOW_RESIZED;
    popupResize.window.windowID = panelId;
    popupResize.window.data1 = 348;
    popupResize.window.data2 = 185;
    bar.handleEvent(&popupResize);
    assert(bar.rect.w == 1280 && bar.rect.h == 44);
    assert(bar.widget.rect.w == 1280 && bar.widget.rect.h == 44);
    assert(bar.clockLabel.rect.x + bar.clockLabel.rect.w / 2 == 640);
    bar.draw();
    surface = SDL_RenderReadPixels(bar.renderer, null);
    assert(surface !is null);
    assert(SDL_ReadSurfacePixel(surface, 900, 20, &r, &g, &b, &a));
    assert(r == 22 && g == 27 && b == 37);
    SDL_DestroySurface(surface);
    escape.key.windowID = panelId;
    bar.handleEvent(&escape);
    assert(!bar.controlsOpen && !bar.quit);

    // A blocked scan must leave the bar able to draw and handle clicks.
    oldServices = bar.services;
    auto blocking = new BlockingWifiServices();
    bar.services = blocking;
    destroy(oldServices);
    auto watchdog = new Thread(() {
        Thread.sleep(dur!"msecs"(250));
        blocking.releaseScan.notify();
    });
    watchdog.start();
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, barId,
        bar.controlButton.rect.x + 16, 20);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, barId,
        bar.controlButton.rect.x + 16, 20);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    down = mouse(SDL_EVENT_MOUSE_BUTTON_DOWN, panelId, 222, 151);
    up = mouse(SDL_EVENT_MOUSE_BUTTON_UP, panelId, 222, 151);
    bar.handleEvent(&down);
    bar.handleEvent(&up);
    assert(bar.wifiOpen && bar.wifiLoading && bar.deviceJob !is null);
    bar.draw();
    assert(bar.rect.w == 1280);
    waitForDevices(bar);
    watchdog.join();
    assert(bar.wifiRows[0].visible &&
        bar.wifiRows[0].text.canFind("Delayed network"));
}
