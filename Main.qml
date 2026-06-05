import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    property string currentTitle: ""
    property string currentPlayer: ""
    property string currentArtist: ""
    property string currentAlbum: ""
    property string currentUrl: ""
    property real currentPosition: 0
    property string currentStatus: "Stopped"

    property string tempTitle: ""
    property string tempPlayer: ""
    property string tempArtist: ""
    property string tempAlbum: ""
    property string tempUrl: ""

    property var songLyrics: []
    property int songIndex: -2
    property int lyricInterval: 0
    property bool isLoading: false
    property bool hasLyrics: false
    property string lastLyric: ""

    property string playerName: pluginApi?.pluginSettings?.playerName ?? "mpd"
    property string musicDirectory: pluginApi?.pluginSettings?.musicDirectory ?? "$HOME/Music"
    property string lyricExtensions: pluginApi?.pluginSettings?.lyricExtensions ?? ".lrc,.LRC"
    property int updateInterval: pluginApi?.pluginSettings?.updateInterval ?? 250
    property bool hideWhenPaused: pluginApi?.pluginSettings?.hideWhenPaused ?? false
    property bool hideWhenEmpty: pluginApi?.pluginSettings?.hideWhenEmpty ?? true

    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("scripts/read-local-lrc.sh").toString().replace(/^file:\/\//, ""))
    readonly property string emptyGlyph: "​"

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

    function playerctlArgs(args) {
        var command = ["playerctl"];
        if (playerName && playerName.trim() !== "")
            command.push("--player", playerName.trim());
        return command.concat(args);
    }

    function sameTrack(player, artist, title, album, url) {
        return player === currentPlayer
            && artist === currentArtist
            && title === currentTitle
            && album === currentAlbum
            && url === currentUrl;
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

    function getLyricIndex() {
        const pos = root.currentPosition;
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
            lastLyric = currentPosition >= songLyrics[0].time ? songLyrics[0].lyric : "";
            lyricInterval = 0;
            return;
        }

        var index = getLyricIndex();
        if (index < 0) {
            lastLyric = "";
            songIndex = index;
            lyricInterval = Math.max(0, (songLyrics[0].time - currentPosition) * 1000);
            return;
        }

        songIndex = index;
        lastLyric = songLyrics[index]?.lyric ?? "";

        if (index + 1 < songLyrics.length)
            lyricInterval = Math.max(0, (songLyrics[index + 1].time - currentPosition) * 1000);
        else
            lyricInterval = 0;
    }

    Process {
        id: songDetailsProc
        command: root.playerctlArgs(["metadata", "--format", "{{ playerName }}:::{{ status }}:::{{ xesam:artist }}:::{{ xesam:title }}:::{{ album }}:::{{ xesam:url }}", "-F"])
        running: true

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(":::");
                const player = parts[0] || "";
                const status = parts[1] || "";
                const artist = parts[2] || "";
                const title = parts[3] || "";
                const album = parts[4] || "";
                const url = parts.slice(5).join(":::") || "";

                if (!status || !player || (!title && !url))
                    return;

                if (sameTrack(player, artist, title, album, url)) {
                    root.currentStatus = status;
                    if (status === "Playing") {
                        positionTimer.restart();
                    } else if (status === "Paused") {
                        positionTimer.stop();
                    } else if (status === "Stopped") {
                        positionTimer.stop();
                        root.lastLyric = "";
                    }
                    return;
                }

                root.isLoading = true;
                root.hasLyrics = false;
                root.lastLyric = "";
                root.songLyrics = [];
                root.songIndex = -2;
                root.lyricInterval = 0;
                root.tempArtist = artist;
                root.tempPlayer = player;
                root.tempTitle = title;
                root.tempAlbum = album;
                root.tempUrl = url;
                root.currentStatus = status;
                fetchLyricProc.running = true;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.currentStatus = "Stopped";
                root.hasLyrics = false;
                root.lastLyric = "";
                songDetailsProc.running = true;
            }
        }
    }

    Timer {
        id: positionTimer
        interval: root.updateInterval
        repeat: true
        running: root.currentStatus === "Playing"
        onTriggered: {
            if (!songPositionProc.running)
                songPositionProc.running = true;
        }
    }

    Process {
        id: songPositionProc
        command: root.playerctlArgs(["position"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var pos = parseFloat(this.text.trim());
                if (!isNaN(pos)) {
                    root.currentPosition = pos;
                    root.updateCurrentLyric();
                }
                songPositionProc.running = false;
            }
        }
    }

    Process {
        id: fetchLyricProc
        command: [root.helperPath, root.musicDirectory, root.lyricExtensions, root.tempUrl, root.tempTitle, root.tempArtist]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text;
                const parsed = root.parseLyrics(output);

                root.currentArtist = root.tempArtist;
                root.currentPlayer = root.tempPlayer;
                root.currentTitle = root.tempTitle;
                root.currentAlbum = root.tempAlbum;
                root.currentUrl = root.tempUrl;
                root.songLyrics = parsed;
                root.hasLyrics = parsed.length > 0;
                root.isLoading = false;
                root.songIndex = -2;
                root.lastLyric = "";

                if (!root.hasLyrics)
                    Logger.e("MpdLocalLyrics", "No local synced lyrics found for", root.currentArtist, root.currentTitle);

                if (!songPositionProc.running)
                    songPositionProc.running = true;
                fetchLyricProc.running = false;
            }
        }
    }
}
