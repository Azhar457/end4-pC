import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "translator"
    hoverEnabled: true

    implicitWidth: 320
    implicitHeight: 220

    property string targetLanguage: Config.options.language.translator.targetLanguage || "id"
    property string sourceLanguage: Config.options.language.translator.sourceLanguage || "auto"
    property string inputText: ""
    property string translatedText: ""
    property bool translating: translateProc.running

    function swapLanguages() {
        if (root.sourceLanguage === "auto") {
            root.sourceLanguage = root.targetLanguage === "id" ? "en" : "id";
        } else {
            let tmp = root.targetLanguage;
            root.targetLanguage = root.sourceLanguage;
            root.sourceLanguage = tmp;
        }
        if (root.inputText.length > 0) translateTimer.restart();
    }

    Timer {
        id: translateTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (root.inputText.trim().length === 0) {
                root.translatedText = "";
                return;
            }
            translateProc.running = false;
            let src = root.sourceLanguage === "auto" ? "" : root.sourceLanguage;
            let tgt = root.targetLanguage;
            let targetSpec = (src ? (src + ":") : ":") + tgt;
            translateProc.command = ["trans", "-e", "bing", "-brief", "-no-bidi", targetSpec, root.inputText.trim()];
            translateProc.running = true;
        }
    }

    Process {
        id: translateProc
        stdout: SplitParser {
            onRead: data => {
                root.translatedText = data.trim();
            }
        }
    }

    StyledRectangularShadow {
        target: card
        z: -2
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "translate"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: Translation.tr("Translator")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                Item { Layout.fillWidth: true }

                // Lang swap button
                Rectangle {
                    implicitWidth: 70
                    implicitHeight: 24
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer0
                    border.color: Appearance.colors.colOutlineVariant
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        StyledText {
                            text: root.sourceLanguage.toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            text: "swap_horiz"
                            iconSize: 14
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: root.targetLanguage.toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.swapLanguages()
                    }
                }
            }

            // Input field
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0
                border.color: inputArea.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                border.width: 1

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    contentWidth: width
                    contentHeight: inputArea.paintedHeight

                    TextArea.flickable: TextArea {
                        id: inputArea
                        wrapMode: Text.Wrap
                        placeholderText: Translation.tr("Type text to translate...")
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        background: null
                        onTextChanged: {
                            root.inputText = text;
                            translateTimer.restart();
                        }
                    }
                }
            }

            // Result Field
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.small
                color: Appearance.colors.colPrimaryContainer
                border.color: Appearance.colors.colOutlineVariant
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: resultText.paintedHeight

                        StyledText {
                            id: resultText
                            width: parent.width
                            text: root.translating ? Translation.tr("Translating...") : (root.translatedText || Translation.tr("Translation appears here"))
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.translatedText ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            wrapMode: Text.Wrap
                        }
                    }

                    // Copy button
                    Rectangle {
                        visible: root.translatedText.length > 0
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer0
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "content_copy"
                            iconSize: 14
                            color: Appearance.colors.colPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["wl-copy", root.translatedText]);
                            }
                        }
                    }
                }
            }
        }
    }
}
