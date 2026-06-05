# MPD Local Lyrics

[English](README.md) | [简体中文](README.zh-CN.md)

A Noctalia bar plugin that displays synced local LRC lyrics for MPD. It is based on `Lyrics Fetch/Bar Display`, but reads local `.lrc` files instead of fetching lyrics from lrclib.net.

## Features

- Shows synced local `.lrc` lyrics in the Noctalia bar.
- Connects directly to MPD over a Unix socket.
- Supports configurable music directory, lyric extensions, font, width, scrolling, and hide behavior.
- Opens Noctalia's media player panel anchored to this lyric widget.

## Requirements

- Noctalia Shell `3.6.0` or newer
- `python3`
- MPD configured with a Unix socket, for example:

```conf
bind_to_address "/run/user/1000/mpd/socket"
```

## Usage

Expected default file layout:

```text
~/Music/Album/Song.flac
~/Music/Album/Song.lrc
```

Install into the Noctalia plugins directory:

```bash
mkdir -p ~/.config/noctalia/plugins
git clone https://github.com/<your-username>/mpd-local-lyrics.git ~/.config/noctalia/plugins/mpd-local-lyrics
chmod +x ~/.config/noctalia/plugins/mpd-local-lyrics/scripts/read-local-lrc.sh
```

Restart or reload Noctalia, then enable **MPD Local Lyrics** in plugin settings.

Main settings:

- `mpdSocketPath`: defaults to `$XDG_RUNTIME_DIR/mpd/socket`.
- `musicDirectory`: defaults to `$HOME/Music`.
- `lyricExtensions`: defaults to `.lrc,.LRC`.
- `textVerticalOffset`: adjusts lyric/icon vertical alignment.

## Attribution

Based on Noctalia's **Lyrics Fetch/Bar Display** by Pever3ll:

```text
https://github.com/noctalia-dev/noctalia-plugins/tree/main/lyrics-fetch
```

## AI Development Notice

This project was developed with AI assistance. Code and behavior were reviewed and adjusted during development for the author's local MPD/Noctalia setup.

## License

GPL-3.0-only. See `LICENSE`.
