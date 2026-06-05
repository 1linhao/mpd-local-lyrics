import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System

ColumnLayout {
    id: root
    property var pluginApi: null

    property string draftMpdSocketPath: pluginApi?.pluginSettings?.mpdSocketPath ?? "$XDG_RUNTIME_DIR/mpd/socket"
    property string draftMusicDirectory: pluginApi?.pluginSettings?.musicDirectory ?? "$HOME/Music"
    property string draftLyricExtensions: pluginApi?.pluginSettings?.lyricExtensions ?? ".lrc,.LRC"
    property int draftUpdateInterval: pluginApi?.pluginSettings?.updateInterval ?? 250
    property int draftWidth: pluginApi?.pluginSettings?.widgetWidth ?? 300
    property int draftSpeed: pluginApi?.pluginSettings?.scrollSpeed ?? 70
    property string draftMode: pluginApi?.pluginSettings?.scrollMode ?? "always"
    property int draftFontSize: pluginApi?.pluginSettings?.fontSize ?? 10
    property int draftTextVerticalOffset: pluginApi?.pluginSettings?.textVerticalOffset ?? -2
    property bool draftHideWhenEmpty: pluginApi?.pluginSettings?.hideWhenEmpty ?? true
    property string draftFontFamily: pluginApi?.pluginSettings?.fontFamily ?? "Inter"
    property bool draftAdaptScrollSpeed: pluginApi?.pluginSettings?.adaptScrollSpeed ?? true
    property bool draftHideWhenPaused: pluginApi?.pluginSettings?.hideWhenPaused ?? false
    property string draftVerticalRotationDirection: {
        const savedDirection = pluginApi?.pluginSettings?.verticalRotationDirection;
        if (savedDirection === "auto" || savedDirection === "cw" || savedDirection === "ccw")
            return savedDirection;
        return "auto";
    }

    readonly property bool isBarVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

    spacing: Style.marginM

    function saveSettings() {
        if (pluginApi) {
            pluginApi.pluginSettings.mpdSocketPath = draftMpdSocketPath;
            pluginApi.pluginSettings.musicDirectory = draftMusicDirectory;
            pluginApi.pluginSettings.lyricExtensions = draftLyricExtensions;
            pluginApi.pluginSettings.updateInterval = draftUpdateInterval;
            pluginApi.pluginSettings.widgetWidth = draftWidth;
            pluginApi.pluginSettings.scrollSpeed = draftSpeed;
            pluginApi.pluginSettings.scrollMode = draftMode;
            pluginApi.pluginSettings.adaptScrollSpeed = draftAdaptScrollSpeed;
            pluginApi.pluginSettings.hideWhenPaused = draftHideWhenPaused;
            pluginApi.pluginSettings.verticalRotationDirection = draftVerticalRotationDirection;
            pluginApi.pluginSettings.fontSize = draftFontSize;
            pluginApi.pluginSettings.textVerticalOffset = draftTextVerticalOffset;
            pluginApi.pluginSettings.hideWhenEmpty = draftHideWhenEmpty;
            pluginApi.pluginSettings.fontFamily = draftFontFamily;
            pluginApi.saveSettings();
        }
    }

    NTextInput {
        label: pluginApi?.tr("settings.mpd-socket-path")
        description: pluginApi?.tr("settings.mpd-socket-path-desc")
        Layout.fillWidth: true
        text: draftMpdSocketPath
        onTextChanged: draftMpdSocketPath = text
    }

    NTextInput {
        label: pluginApi?.tr("settings.music-directory")
        description: pluginApi?.tr("settings.music-directory-desc")
        Layout.fillWidth: true
        text: draftMusicDirectory
        onTextChanged: draftMusicDirectory = text
    }

    NTextInput {
        label: pluginApi?.tr("settings.lyric-extensions")
        description: pluginApi?.tr("settings.lyric-extensions-desc")
        Layout.fillWidth: true
        text: draftLyricExtensions
        onTextChanged: draftLyricExtensions = text
    }

    NDivider {
        Layout.fillWidth: true
    }

    NSearchableComboBox {
        label: pluginApi?.tr("settings.font.title")
        description: pluginApi?.tr("settings.font.desc")
        Layout.fillWidth: true
        model: FontService.availableFonts
        currentKey: draftFontFamily
        placeholder: pluginApi?.tr("settings.font.placeholder")
        searchPlaceholder: pluginApi?.tr("settings.font.search-placeholder")
        popupHeight: 300
        onSelected: key => draftFontFamily = key
    }

    NLabel {
        label: pluginApi?.tr("settings.font.size")
        description: pluginApi?.tr("settings.font.size-desc")
    }

    RowLayout {
        Layout.fillWidth: true
        NSlider {
            Layout.fillWidth: true
            from: 8
            to: 32
            value: draftFontSize
            onValueChanged: draftFontSize = value
        }
        NText {
            text: Math.round(draftFontSize) + "pt"
        }
    }

    NLabel {
        label: pluginApi?.tr("settings.text-vertical-offset")
    }
    RowLayout {
        Layout.fillWidth: true
        NSlider {
            Layout.fillWidth: true
            from: -6
            to: 6
            value: draftTextVerticalOffset
            onValueChanged: draftTextVerticalOffset = value
        }
        NText {
            text: Math.round(draftTextVerticalOffset) + "px"
        }
    }

    NLabel {
        label: pluginApi?.tr("settings.width")
    }
    RowLayout {
        Layout.fillWidth: true
        NSlider {
            Layout.fillWidth: true
            from: 100
            to: 500
            value: draftWidth
            onValueChanged: draftWidth = value
        }
        NText {
            text: Math.round(draftWidth) + "px"
        }
    }

    NLabel {
        label: pluginApi?.tr("settings.scroll.speed")
    }
    RowLayout {
        Layout.fillWidth: true
        NSlider {
            Layout.fillWidth: true
            from: 10
            to: 200
            value: draftSpeed
            onValueChanged: draftSpeed = value
        }
        NText {
            text: Math.round(draftSpeed) + " px/s"
        }
    }

    NLabel {
        label: pluginApi?.tr("settings.update-interval")
    }
    RowLayout {
        Layout.fillWidth: true
        NSlider {
            Layout.fillWidth: true
            from: 100
            to: 1000
            value: draftUpdateInterval
            onValueChanged: draftUpdateInterval = value
        }
        NText {
            text: Math.round(draftUpdateInterval) + " ms"
        }
    }

    NComboBox {
        label: pluginApi?.tr("settings.scroll.mode.title")
        Layout.fillWidth: true
        model: [
            {
                name: pluginApi?.tr("settings.scroll.mode.always"),
                key: "always"
            },
            {
                name: pluginApi?.tr("settings.scroll.mode.hover"),
                key: "hover"
            },
            {
                name: pluginApi?.tr("settings.scroll.mode.never"),
                key: "none"
            }
        ]
        currentKey: draftMode
        onSelected: key => draftMode = key
    }

    NToggle {
        label: pluginApi?.tr("settings.scroll.adapt")
        description: pluginApi?.tr("settings.scroll.adapt-desc")
        checked: draftAdaptScrollSpeed
        onToggled: newState => draftAdaptScrollSpeed = newState
    }

    NToggle {
        label: pluginApi?.tr("settings.hide-when-empty")
        checked: draftHideWhenEmpty
        onToggled: newState => draftHideWhenEmpty = newState
    }

    NComboBox {
        visible: root.isBarVertical
        label: pluginApi?.tr("settings.vertical-rotation.title")
        description: pluginApi?.tr("settings.vertical-rotation.description")
        Layout.fillWidth: true
        model: [
            {
                name: pluginApi?.tr("settings.vertical-rotation.auto"),
                key: "auto"
            },
            {
                name: pluginApi?.tr("settings.vertical-rotation.ccw"),
                key: "ccw"
            },
            {
                name: pluginApi?.tr("settings.vertical-rotation.cw"),
                key: "cw"
            }
        ]
        currentKey: draftVerticalRotationDirection
        onSelected: key => draftVerticalRotationDirection = key
    }

    NToggle {
        label: pluginApi?.tr("settings.hide-when-paused")
        checked: draftHideWhenPaused
        onToggled: newState => draftHideWhenPaused = newState
    }
}
