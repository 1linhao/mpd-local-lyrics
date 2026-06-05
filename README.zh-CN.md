# MPD Local Lyrics

[English](README.md) | [简体中文](README.zh-CN.md)

一个用于 Noctalia 状态栏的 MPD 本地同步歌词插件。它基于 `Lyrics Fetch/Bar Display`，但不从 lrclib.net 获取歌词，而是读取本地 `.lrc` 文件。

## 特性

- 在 Noctalia 状态栏显示本地同步 `.lrc` 歌词。
- 使用 `playerctl` 获取 MPRIS 元数据和播放进度。
- 当 MPD 返回相对路径时，回退到 `mpc --format '%file%' current`。
- 支持配置音乐目录、歌词扩展名、字体、宽度、滚动和隐藏行为。
- 点击歌词部件时，在该部件位置锚定打开 Noctalia 媒体播放器面板。

## 依赖

- Noctalia Shell `3.6.0` 或更新版本
- `playerctl`
- `mpc`
- `python3`
- MPD 的 MPRIS 支持，例如 `mpd-mpris`

## 使用

默认期望的文件结构：

```text
~/Music/Album/Song.flac
~/Music/Album/Song.lrc
```

安装到 Noctalia 插件目录：

```bash
mkdir -p ~/.config/noctalia/plugins
git clone https://github.com/<your-username>/mpd-local-lyrics.git ~/.config/noctalia/plugins/mpd-local-lyrics
chmod +x ~/.config/noctalia/plugins/mpd-local-lyrics/scripts/read-local-lrc.sh
```

重启或重载 Noctalia，然后在插件设置里启用 **MPD Local Lyrics**。

主要设置项：

- `playerName`：默认是 `mpd`。
- `musicDirectory`：默认是 `$HOME/Music`。
- `lyricExtensions`：默认是 `.lrc,.LRC`。
- `textVerticalOffset`：调整歌词和图标的垂直位置。

## 来源

基于 Pever3ll 的 Noctalia 插件 **Lyrics Fetch/Bar Display**：

```text
https://github.com/noctalia-dev/noctalia-plugins/tree/main/lyrics-fetch
```

## AI 开发声明

本项目在 AI 辅助下开发。代码和行为已在开发过程中根据作者的本地 MPD/Noctalia 使用环境进行检查和调整。

## 许可证

GPL-3.0-only。见 `LICENSE`。
