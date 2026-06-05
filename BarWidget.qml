import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var backend: pluginApi?.mainInstance
    property string lyricText: backend?.currentLyric || ""
    property int lyricInterval: backend?.lyricInterval

    property int widgetWidth: pluginApi?.pluginSettings?.widgetWidth ?? 215
    property int scrollSpeed: pluginApi?.pluginSettings?.scrollSpeed ?? 70
    property string scrollMode: pluginApi?.pluginSettings?.scrollMode ?? "always"
    property int customFontSize: pluginApi?.pluginSettings?.fontSize ?? 10
    property int textVerticalOffset: pluginApi?.pluginSettings?.textVerticalOffset ?? -2
    property bool hideWhenEmpty: pluginApi?.pluginSettings?.hideWhenEmpty ?? true
    property string customFontFamily: pluginApi?.pluginSettings?.fontFamily ?? Settings.data.ui.fontDefault
    property bool adaptScrollSpeed: pluginApi?.pluginSettings?.adaptScrollSpeed ?? true
    property string verticalRotationDirectionSetting: pluginApi?.pluginSettings?.verticalRotationDirection ?? "auto"
    property string verticalRotationDirection: {
        if (verticalRotationDirectionSetting === "cw" || verticalRotationDirectionSetting === "ccw")
            return verticalRotationDirectionSetting;
        return barPosition === "left" ? "cw" : "ccw";
    }

    visible: !hideWhenEmpty || (lyricText !== "")

    property bool hovered: false
    property real scaling: 1.0

    readonly property int iconSize: Math.round(18 * scaling)
    readonly property string barPosition: Settings.data.bar.position
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property string verticalTooltipSide: barPosition === "left" ? "right" : "left"
    readonly property real capsuleThickness: Style.capsuleHeight
    readonly property string emptyGlyph: "​"
    readonly property string displayLyricText: lyricText === emptyGlyph ? "" : lyricText
    readonly property bool hasDisplayLyric: displayLyricText !== ""
    readonly property int compactSize: Math.round(iconSize + Style.marginS * 2 * scaling)
    readonly property real stableTextMaxWidth: {
        if (isVertical)
            return Math.max(20, widgetWidth - Style.marginS * 2 * scaling);
        return Math.max(20, widgetWidth - iconSize - Style.marginS * 3 * scaling - Style.margin2XXS);
    }
    readonly property real lyricContentWidth: isVertical ? verticalLyricScrollText.contentWidth : lyricScrollText.contentWidth
    readonly property real dynamicWidgetWidth: isVertical ? capsuleThickness : Math.min(calculateContentWidth(), widgetWidth)
    readonly property real dynamicWidgetHeight: isVertical ? (hasDisplayLyric ? widgetWidth : compactSize) : Style.capsuleHeight
    readonly property real effectiveScrollSpeed: {
        if (!adaptScrollSpeed)
            return scrollSpeed;
        if (lyricInterval <= 0)
            return scrollSpeed;

        const distance = lyricContentWidth - stableTextMaxWidth + 50;
        if (distance <= 0)
            return scrollSpeed;

        return Math.max(1, (distance / lyricInterval) * 1250);
    }
    readonly property int mappedScrollMode: {
        if (scrollMode === "always")
            return NScrollText.ScrollMode.Always;
        if (scrollMode === "hover")
            return NScrollText.ScrollMode.Hover;
        return NScrollText.ScrollMode.Never;
    }

    function calculateContentWidth() {
        if (!hasDisplayLyric)
            return compactSize;

        var contentWidth = 0;
        contentWidth += iconSize;
        contentWidth += Style.marginS * scaling;
        contentWidth += lyricScrollText.measuredWidth;
        contentWidth += Style.margin2XXS;
        contentWidth += Style.marginS * 2 * scaling;

        return Math.max(compactSize, Math.ceil(contentWidth));
    }

    implicitWidth: visible ? root.dynamicWidgetWidth : 0
    implicitHeight: visible ? root.dynamicWidgetHeight : 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.InOutCubic
        }
    }

    Rectangle {
        id: container
        x: 0
        y: Style.pixelAlignCenter(parent.height, height)

        width: root.dynamicWidgetWidth
        height: root.dynamicWidgetHeight

        radius: Style.radiusM
        color: Style.capsuleColor
        border.width: Style.capsuleBorderWidth
        border.color: Style.capsuleBorderColor
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Style.animationNormal
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Style.animationNormal
                easing.type: Easing.InOutCubic
            }
        }

        Item {
            id: mainContainer
            anchors.fill: parent
            anchors.leftMargin: isVertical ? 0 : Style.marginS * scaling
            anchors.rightMargin: isVertical ? 0 : Style.marginS * scaling

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.marginS * scaling
                visible: !isVertical

                Item {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: iconSize
                    Layout.preferredHeight: iconSize

                    NIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: root.textVerticalOffset
                        width: iconSize
                        height: iconSize
                        icon: "music"
                        color: root.hovered ? Color.mPrimary : Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeL * scaling
                    }
                }

                NScrollText {
                    id: lyricScrollText
                    text: root.displayLyricText
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: root.capsuleThickness
                    visible: root.hasDisplayLyric

                    maxWidth: {
                        const availableWidth = mainContainer.width - root.iconSize - Style.marginS * root.scaling - Style.margin2XXS;
                        return Math.max(20, availableWidth);
                    }
                    scrollMode: root.mappedScrollMode
                    forcedHover: root.hovered
                    fadeExtent: 0.1
                    fadeCornerRadius: Style.radiusM
                    fadeRoundLeftCorners: false
                    waitBeforeScrolling: 700
                    scrollCycleDuration: Math.max(1000, ((root.lyricContentWidth + 50) / Math.max(1, root.effectiveScrollSpeed)) * 1000)
                    transform: Translate {
                        y: root.textVerticalOffset
                    }

                    NText {
                        color: Color.mOnSurface
                        pointSize: root.customFontSize * root.scaling
                        family: root.customFontFamily
                        applyUiScale: false
                        font.weight: Style.fontWeightMedium
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.marginS * scaling
                spacing: Style.marginS * scaling
                visible: isVertical

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: iconSize
                    Layout.preferredHeight: iconSize

                    NIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: root.textVerticalOffset
                        width: iconSize
                        height: iconSize
                        icon: "music"
                        color: root.hovered ? Color.mPrimary : Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeL * scaling
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Item {
                        anchors.centerIn: parent
                        width: parent.height
                        height: parent.width
                        rotation: root.verticalRotationDirection === "cw" ? -90 : 90
                        transformOrigin: Item.Center

                        NScrollText {
                            id: verticalLyricScrollText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root.textVerticalOffset

                            text: root.displayLyricText
                            maxWidth: Math.max(20, parent.width)
                            alwaysMaxWidth: true
                            scrollMode: root.mappedScrollMode
                            forcedHover: root.hovered
                            fadeExtent: 0.1
                            fadeCornerRadius: Style.radiusM
                            fadeRoundLeftCorners: true
                            waitBeforeScrolling: 700
                            scrollCycleDuration: Math.max(1000, ((root.lyricContentWidth + 50) / Math.max(1, root.effectiveScrollSpeed)) * 1000)

                            NText {
                                color: Color.mOnSurface
                                pointSize: root.customFontSize * root.scaling
                                family: root.customFontFamily
                                applyUiScale: false
                                font.weight: Style.fontWeightMedium
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }

        NPopupContextMenu {
            id: contextMenu

            model: [
                {
                    "label": pluginApi?.tr("settings.title"),
                    "action": "settings",
                    "icon": "settings"
                }
            ]

            onTriggered: action => {
                contextMenu.close();
                PanelService.closeContextMenu(root.screen);

                if (action === "settings")
                    BarService.openPluginSettings(root.screen, pluginApi.manifest);
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: {
                root.hovered = true;
                if (isVertical)
                    TooltipService.show(root, root.lyricText, root.verticalTooltipSide);
            }
            onExited: {
                root.hovered = false;
                TooltipService.hide();
            }
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    PanelService.getPanel("mediaPlayerPanel", root.screen)?.toggle(container);
                } else if (mouse.button === Qt.RightButton) {
                    PanelService.showContextMenu(contextMenu, root, root.screen);
                }
            }
        }
    }

}
