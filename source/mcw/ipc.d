module mcw.ipc;

import core.sync.semaphore : Semaphore;
import core.sys.posix.sys.stat : S_ISSOCK, umask;
import core.thread : Thread;
import std.datetime : dur, MonoTime;
import std.file : exists, getLinkAttributes, remove;
import std.path : buildPath;
import std.process : environment;
import std.socket : AddressFamily, Socket, SocketException, SocketSet,
    SocketType, UnixAddress;
import std.string : indexOf, strip;

import bindbc.sdl;

string ipcPath() {
    auto runtime = environment.get("XDG_RUNTIME_DIR", "");
    if (!runtime.length) throw new Exception("XDG_RUNTIME_DIR is not set");
    auto session = environment.get("WAYLAND_DISPLAY", "");
    if (!session.length) session = environment.get("DISPLAY", "");
    if (!session.length) session = environment.get("XDG_SESSION_ID", "default");
    char[] key;
    foreach (ch; session)
        key ~= (ch >= 'a' && ch <= 'z') ||
            (ch >= 'A' && ch <= 'Z') ||
            (ch >= '0' && ch <= '9') || ch == '-' || ch == '_' ? ch : '_';
    return buildPath(runtime, "mcw-" ~ key.idup ~ ".sock");
}

private string readLine(Socket socket, int timeoutSeconds) {
    string line;
    char[512] buffer;
    auto deadline = MonoTime.currTime + dur!"seconds"(timeoutSeconds);
    while (line.length < 512) {
        auto remaining = deadline - MonoTime.currTime;
        if (remaining <= dur!"seconds"(0))
            throw new Exception("IPC response timed out");
        auto ready = new SocketSet();
        ready.add(socket);
        if (Socket.select(ready, null, null, remaining) == 0)
            throw new Exception("IPC response timed out");
        auto count = socket.receive(buffer[]);
        if (count <= 0) throw new Exception("Connection closed before newline");
        line ~= buffer[0 .. cast(size_t) count];
        auto end = line.indexOf('\n');
        if (end >= 0) {
            if (end > 512) throw new Exception("IPC message is too long");
            return line[0 .. end].strip();
        }
    }
    throw new Exception("IPC message is too long");
}

private void writeLine(Socket socket, string line) {
    auto message = line ~ "\n";
    size_t sent;
    while (sent < message.length) {
        auto count = socket.send(message[sent .. $]);
        if (count <= 0) throw new Exception("Could not send IPC message");
        sent += cast(size_t) count;
    }
}

string sendCommand(string command) {
    auto socket = new Socket(AddressFamily.UNIX, SocketType.STREAM);
    scope(exit) socket.close();
    socket.connect(new UnixAddress(ipcPath()));
    writeLine(socket, "v1 " ~ command);
    return readLine(socket, 30);
}

class IpcRequest {
    string command;
    string response;
    Semaphore done;

    this(string command) {
        this.command = command;
        done = new Semaphore();
    }
}

class IpcServer {
    private string path;
    private Socket listener;
    private Thread thread;
    private IpcRequest[] pending;
    private bool stopping;
    private bool bound;
    uint eventType;

    this() { path = ipcPath(); }

    void start() {
        if (exists(path)) {
            if (!S_ISSOCK(getLinkAttributes(path)))
                throw new Exception("Refusing to replace non-socket IPC path");
            auto probe = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            try {
                probe.connect(new UnixAddress(path));
                throw new Exception("MCW daemon is already running");
            } catch (SocketException) {
                remove(path);
            } finally {
                probe.close();
            }
        }
        listener = new Socket(AddressFamily.UNIX, SocketType.STREAM);
        // Restrict the socket to this user (POSIX umask 0077).
        auto oldMask = umask(0x3f);
        try listener.bind(new UnixAddress(path));
        finally umask(oldMask);
        bound = true;
        listener.listen(8);
        eventType = SDL_RegisterEvents(1);
        if (eventType == uint.max) throw new Exception("Could not register IPC event");
        thread = new Thread(&serve);
        thread.start();
    }

    private bool isStopping() {
        synchronized (this) return stopping;
    }

    private void serve() {
        while (!isStopping()) {
            try {
                auto ready = new SocketSet();
                ready.add(listener);
                if (Socket.select(ready, null, null, dur!"msecs"(100)) == 0)
                    continue;
                if (isStopping()) break;
                auto client = listener.accept();
                scope(exit) client.close();
                string command;
                try command = readLine(client, 2);
                catch (Exception) {
                    writeLine(client, "ERR invalid request");
                    continue;
                }
                auto request = new IpcRequest(command);
                synchronized (this) pending ~= request;
                SDL_Event wake = SDL_Event.init;
                wake.type = eventType;
                if (!SDL_PushEvent(&wake)) {
                    synchronized (this) pending.length = 0;
                    writeLine(client, "ERR event queue unavailable");
                    continue;
                }
                request.done.wait();
                writeLine(client, request.response);
            } catch (Exception) {
                if (!isStopping()) continue;
            }
        }
    }

    IpcRequest take() {
        synchronized (this) {
            if (!pending.length) return null;
            auto request = pending[0];
            pending = pending[1 .. $];
            return request;
        }
    }

    void complete(IpcRequest request, string response) {
        request.response = response;
        request.done.notify();
    }

    void stop() {
        synchronized (this) {
            stopping = true;
            foreach (request; pending) complete(request, "ERR daemon stopped");
            pending.length = 0;
        }
        if (thread !is null) thread.join();
        if (listener !is null) listener.close();
        if (bound && exists(path)) remove(path);
    }
}
