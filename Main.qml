import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    property string currentTitle: ""
    property string currentArtist: ""
    property string currentAlbum: ""
    property string currentFile: ""
    property string currentLyricPath: ""
    property string currentLyricSignature: ""
    property real currentPosition: 0
    property real currentPositionSyncedAt: 0
    property string currentStatus: "Stopped"

    property string tempTitle: ""
    property string tempArtist: ""
    property string tempAlbum: ""
    property string tempFile: ""

    property var songLyrics: []
    property int songIndex: -2
    property int lyricInterval: 0
    property bool isLoading: false
    property bool hasLyrics: false
    property string lastLyric: ""

    property bool mpdRequestInFlight: false
    property real mpdRequestStartedAt: 0
    property var mpdResponseLines: []

    property string mpdSocketPath: pluginApi?.pluginSettings?.mpdSocketPath ?? "$XDG_RUNTIME_DIR/mpd/socket"
    property string musicDirectory: pluginApi?.pluginSettings?.musicDirectory ?? "$HOME/Music"
    property string lyricExtensions: pluginApi?.pluginSettings?.lyricExtensions ?? ".lrc,.LRC"
    property int updateInterval: pluginApi?.pluginSettings?.updateInterval ?? 250
    property int lyricWatchInterval: pluginApi?.pluginSettings?.lyricWatchInterval ?? 1000
    property bool hideWhenPaused: pluginApi?.pluginSettings?.hideWhenPaused ?? false
    property bool hideWhenEmpty: pluginApi?.pluginSettings?.hideWhenEmpty ?? true

    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("scripts/read-local-lrc.sh").toString().replace(/^file:\/\//, ""))
    readonly property string emptyGlyph: "​"
    readonly property string expandedMpdSocketPath: expandPath(mpdSocketPath)

    onExpandedMpdSocketPathChanged: mpdReconnectTimer.restart()
    Component.onCompleted: mpdReconnectTimer.restart()

    property string currentLyric: {
        if (currentStatus === "Stopped" || currentStatus === "")
            return hideWhenEmpty ? "" : pluginApi?.tr("lyrics.stopped")
        if (currentStatus === "Paused")
            return hideWhenPaused ? "" : pluginApi?.tr("lyrics.paused")
        if (isLoading)
            return pluginApi?.tr("lyrics.loading")
        if (!hasLyrics)
            return hideWhenEmpty ? "" : pluginApi?.tr("lyrics.no-local")
        if (lastLyric !== "")
            return lastLyric
        return emptyGlyph
    }

    function expandPath(path) {
        if (!path)
            return "";

        var expanded = path;
        const home = Quickshell.env("HOME") || "";
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR") || "";

        if (expanded === "~")
            expanded = home;
        else if (expanded.indexOf("~/") === 0)
            expanded = home + expanded.slice(1);

        if (expanded.indexOf("$HOME") === 0)
            expanded = home + expanded.slice(5);
        if (expanded.indexOf("$XDG_RUNTIME_DIR") === 0)
            expanded = runtimeDir + expanded.slice(16);

        return expanded;
    }

    function baseName(path) {
        if (!path)
            return "";
        var name = path.split("/").pop();
        var dot = name.lastIndexOf(".");
        return dot > 0 ? name.slice(0, dot) : name;
    }

    function lyricLookupArgs(file, title) {
        return [musicDirectory, lyricExtensions, file, title];
    }

    function lyricMetadataFromLine(line) {
        if (!line)
            return { "signature": "", "path": "" };

        var cleanLine = line.replace(/\r$/, "");
        var parts = cleanLine.split("\t");
        if (parts[0] === "#MPD_LOCAL_LYRICS")
            parts.shift();
        if (parts.length < 3)
            return { "signature": "", "path": "" };

        return {
            "signature": parts[0] + ":" + parts[1],
            "path": parts.slice(2).join("\t")
        };
    }

    function lyricPayload(output) {
        var lines = output.split(/\r?\n/);
        var metadata = { "signature": "", "path": "" };

        if (lines.length > 0 && lines[0].indexOf("#MPD_LOCAL_LYRICS\t") === 0) {
            metadata = lyricMetadataFromLine(lines[0]);
            lines.shift();
        }

        return {
            "metadata": metadata,
            "lyrics": lines.join("\n")
        };
    }

    function requestLyrics(artist, title, album, file, showLoading) {
        if (fetchLyricProc.running && !showLoading)
            return;
        if (fetchLyricProc.running)
            fetchLyricProc.running = false;

        if (showLoading) {
            isLoading = true;
            hasLyrics = false;
            lastLyric = "";
            songLyrics = [];
            songIndex = -2;
            lyricInterval = 0;
            currentLyricPath = "";
            currentLyricSignature = "";
        }

        tempArtist = artist;
        tempTitle = title;
        tempAlbum = album;
        tempFile = file;
        fetchLyricProc.running = true;
    }

    function parseTime(minutes, seconds, fraction) {
        var frac = fraction || "0";
        while (frac.length < 3)
            frac += "0";
        return parseInt(minutes, 10) * 60 + parseInt(seconds, 10) + parseInt(frac.slice(0, 3), 10) / 1000;
    }

    function parseLyrics(lyrics) {
        var parsed = [];
        var lines = lyrics.split(/\r?\n/);
        var timeRe = /\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]/g;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var matches = [];
            var match;
            timeRe.lastIndex = 0;
            while ((match = timeRe.exec(line)) !== null) {
                matches.push({
                    "time": parseTime(match[1], match[2], match[3]),
                    "raw": match[0]
                });
            }
            if (matches.length === 0)
                continue;

            var text = line.replace(timeRe, "").replace(/<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>/g, "").trim();
            for (var j = 0; j < matches.length; j++)
                parsed.push({ "time": matches[j].time, "lyric": text });
        }

        parsed.sort((a, b) => a.time - b.time);
        return parsed;
    }

    function estimatedPosition() {
        if (currentStatus !== "Playing" || currentPositionSyncedAt <= 0)
            return currentPosition;

        return currentPosition + Math.max(0, Date.now() - currentPositionSyncedAt) / 1000;
    }

    function getLyricIndex() {
        const pos = root.estimatedPosition();
        const lyrics = root.songLyrics;
        var start = 0;
        var len = lyrics.length;

        if (len <= 1)
            return -2;
        if (pos > lyrics[len - 1].time || pos < 0)
            return len - 1;
        if (pos < lyrics[0].time)
            return -1;

        while (true) {
            if (len == 1)
                return start;
            const len2 = Math.floor(len / 2);
            if (pos < lyrics[start + len2].time) {
                len = len2;
            } else {
                len -= len2;
                start += len2;
            }
        }
    }

    function updateCurrentLyric() {
        if (!hasLyrics || songLyrics.length === 0) {
            lastLyric = "";
            lyricInterval = 0;
            return;
        }

        if (songLyrics.length === 1) {
            lastLyric = estimatedPosition() >= songLyrics[0].time ? songLyrics[0].lyric : "";
            lyricInterval = 0;
            return;
        }

        var index = getLyricIndex();
        if (index < 0) {
            if (songIndex !== index || lastLyric !== "") {
                lastLyric = "";
                songIndex = index;
                lyricInterval = 0;
            }
            return;
        }

        if (index === songIndex)
            return;

        songIndex = index;
        lastLyric = songLyrics[index]?.lyric ?? "";

        if (index + 1 < songLyrics.length)
            lyricInterval = Math.max(0, (songLyrics[index + 1].time - songLyrics[index].time) * 1000);
        else
            lyricInterval = 0;
    }

    function resetPlaybackState() {
        currentStatus = "Stopped";
        currentFile = "";
        currentTitle = "";
        currentArtist = "";
        currentAlbum = "";
        currentPosition = 0;
        currentPositionSyncedAt = 0;
        currentLyricPath = "";
        currentLyricSignature = "";
        songLyrics = [];
        hasLyrics = false;
        isLoading = false;
        songIndex = -2;
        lastLyric = "";
        lyricInterval = 0;
    }

    function parseMpdFields(lines) {
        var fields = {};
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var index = line.indexOf(": ");
            if (index <= 0)
                continue;

            fields[line.slice(0, index)] = line.slice(index + 2);
        }
        return fields;
    }

    function statusFromMpdState(state) {
        if (state === "play")
            return "Playing";
        if (state === "pause")
            return "Paused";
        return "Stopped";
    }

    function elapsedFromMpdFields(fields) {
        var elapsed = parseFloat(fields["elapsed"] || "");
        if (!isNaN(elapsed))
            return elapsed;

        var time = fields["time"] || "";
        var sep = time.indexOf(":");
        if (sep > 0) {
            elapsed = parseFloat(time.slice(0, sep));
            if (!isNaN(elapsed))
                return elapsed;
        }

        return NaN;
    }

    function syncPosition(position, status) {
        if (isNaN(position))
            return;

        currentPosition = position;
        currentPositionSyncedAt = status === "Playing" ? Date.now() : 0;
        updateCurrentLyric();
    }

    function applyMpdResponse(lines) {
        var fields = parseMpdFields(lines);
        var status = statusFromMpdState(fields["state"] || "");
        var file = fields["file"] || "";
        var elapsed = elapsedFromMpdFields(fields);

        if (status === "Stopped" || file === "") {
            resetPlaybackState();
            return;
        }

        var title = fields["Title"] || fields["title"] || fields["Name"] || baseName(file);
        var artist = fields["Artist"] || fields["artist"] || "";
        var album = fields["Album"] || fields["album"] || "";
        var changedTrack = file !== currentFile;

        currentStatus = status;
        currentTitle = title;
        currentArtist = artist;
        currentAlbum = album;

        if (changedTrack) {
            currentFile = file;
            currentPosition = isNaN(elapsed) ? 0 : elapsed;
            currentPositionSyncedAt = status === "Playing" ? Date.now() : 0;
            requestLyrics(artist, title, album, file, true);
        } else {
            syncPosition(elapsed, status);
        }
    }

    function requestMpdState() {
        if (mpdSocket.path === "" || !mpdSocket.connected)
            return;

        if (mpdRequestInFlight && Date.now() - mpdRequestStartedAt < 2000)
            return;

        mpdRequestInFlight = true;
        mpdRequestStartedAt = Date.now();
        mpdResponseLines = [];
        mpdSocket.write("command_list_begin\nstatus\ncurrentsong\ncommand_list_end\n");
        mpdSocket.flush();
    }

    function reconnectMpdSocket() {
        if (expandedMpdSocketPath === "")
            return;

        mpdSocket.connected = false;
        mpdSocket.connected = true;
    }

    function handleMpdLine(data) {
        var line = data.replace(/\r$/, "");
        if (line === "")
            return;

        if (line.indexOf("OK MPD") === 0) {
            mpdRequestInFlight = false;
            mpdResponseLines = [];
            requestMpdState();
            return;
        }

        if (line.indexOf("ACK ") === 0) {
            Logger.e("MpdLocalLyrics", "MPD error:", line);
            mpdRequestInFlight = false;
            mpdResponseLines = [];
            return;
        }

        if (line === "OK") {
            var lines = mpdResponseLines;
            mpdRequestInFlight = false;
            mpdResponseLines = [];
            applyMpdResponse(lines);
            return;
        }

        mpdResponseLines = mpdResponseLines.concat([line]);
    }

    Socket {
        id: mpdSocket
        path: root.expandedMpdSocketPath
        connected: false

        parser: SplitParser {
            onRead: data => root.handleMpdLine(data)
        }

        onConnectionStateChanged: {
            if (!connected) {
                root.mpdRequestInFlight = false;
                root.mpdResponseLines = [];
            }
        }

        onError: error => {
            Logger.e("MpdLocalLyrics", "MPD socket error:", error, "path:", root.expandedMpdSocketPath);
            root.mpdRequestInFlight = false;
        }
    }

    Timer {
        id: syncTimer
        interval: root.updateInterval
        repeat: true
        running: root.expandedMpdSocketPath !== ""
        onTriggered: {
            root.updateCurrentLyric();
            root.requestMpdState();
        }
    }

    Timer {
        id: mpdReconnectTimer
        interval: 2000
        repeat: true
        running: root.expandedMpdSocketPath !== "" && !mpdSocket.connected
        triggeredOnStart: true
        onTriggered: root.reconnectMpdSocket()
    }

    Process {
        id: fetchLyricProc
        command: [root.helperPath, "--with-metadata"].concat(root.lyricLookupArgs(root.tempFile, root.tempTitle))
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const payload = root.lyricPayload(this.text);
                const parsed = root.parseLyrics(payload.lyrics);

                root.currentArtist = root.tempArtist;
                root.currentTitle = root.tempTitle;
                root.currentAlbum = root.tempAlbum;
                root.currentFile = root.tempFile;
                root.currentLyricPath = payload.metadata.path;
                root.currentLyricSignature = payload.metadata.signature;
                root.songLyrics = parsed;
                root.hasLyrics = parsed.length > 0;
                root.isLoading = false;
                root.songIndex = -2;
                root.lastLyric = "";

                if (!root.hasLyrics)
                    Logger.e("MpdLocalLyrics", "No local synced lyrics found for", root.currentArtist, root.currentTitle);

                root.updateCurrentLyric();
                fetchLyricProc.running = false;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                fetchLyricProc.running = false;
            }
        }
    }

    Timer {
        id: lyricFileWatchTimer
        interval: root.lyricWatchInterval
        repeat: true
        running: root.currentFile !== "" && root.currentStatus !== "Stopped"
        onTriggered: {
            if (!lyricMetadataProc.running && !fetchLyricProc.running)
                lyricMetadataProc.running = true;
        }
    }

    Process {
        id: lyricMetadataProc
        command: root.currentLyricPath !== ""
            ? ["stat", "-c", "%Y\t%s\t%n", root.currentLyricPath]
            : [root.helperPath, "--metadata"].concat(root.lyricLookupArgs(root.currentFile, root.currentTitle))
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const metadata = root.lyricMetadataFromLine(this.text.trim());
                lyricMetadataProc.running = false;

                if (metadata.signature === "") {
                    if (root.currentLyricSignature !== "" || root.hasLyrics)
                        root.requestLyrics(root.currentArtist, root.currentTitle, root.currentAlbum, root.currentFile, false);
                    return;
                }
                if (metadata.signature === root.currentLyricSignature && metadata.path === root.currentLyricPath)
                    return;

                root.requestLyrics(root.currentArtist, root.currentTitle, root.currentAlbum, root.currentFile, false);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                lyricMetadataProc.running = false;
            }
        }
    }
}
