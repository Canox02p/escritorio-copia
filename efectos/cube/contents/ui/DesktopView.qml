/*
    SPDX-FileCopyrightText: 2022 Vlad Zahorodnii <vlad.zahorodnii@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import org.kde.kwin as KWinComponents
import org.kde.kirigami as Kirigami

Item {
    id: desktopView

    required property QtObject desktop

    // ¿es el escritorio en el que estoy ahora mismo?
    readonly property bool esActual: currentDesktop === desktopView.desktop

    Repeater {
        model: KWinComponents.WindowFilterModel {
            activity: KWinComponents.Workspace.currentActivity
            desktop: desktopView.desktop
            screenName: targetScreen.name
            windowModel: KWinComponents.WindowModel {}
        }

        KWinComponents.WindowThumbnail {
            wId: model.window.internalId
            x: model.window.x - targetScreen.geometry.x
            y: model.window.y - targetScreen.geometry.y
            z: model.window.stackingOrder
            visible: !model.window.minimized
        }
    }

    // Distintivo con el número y el nombre del escritorio, para saber en cuál estoy
    Column {
        z: 999999
        anchors.centerIn: parent
        spacing: Math.round(desktopView.height * 0.022)

        Rectangle {
            id: disco
            width: Math.round(desktopView.height * 0.22)
            height: width
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter

            readonly property color acento: Kirigami.Theme.highlightColor
            // texto oscuro si el acento es claro, para que el número se lea siempre
            readonly property bool acentoClaro: (0.299 * acento.r + 0.587 * acento.g + 0.114 * acento.b) > 0.6

            color: desktopView.esActual ? Qt.rgba(acento.r, acento.g, acento.b, 0.95)
                                        : Qt.rgba(0, 0, 0, 0.55)
            border.width: Math.max(2, Math.round(width * 0.025))
            border.color: Qt.rgba(1, 1, 1, desktopView.esActual ? 0.95 : 0.4)

            Text {
                anchors.centerIn: parent
                text: desktopView.desktop.x11DesktopNumber
                color: (desktopView.esActual && disco.acentoClaro) ? "#1a1a1a" : "white"
                font.pixelSize: Math.round(disco.width * 0.55)
                font.bold: true
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: nombre.implicitWidth + Math.round(desktopView.height * 0.04)
            height: nombre.implicitHeight + Math.round(desktopView.height * 0.018)
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.55)

            Text {
                id: nombre
                anchors.centerIn: parent
                text: desktopView.desktop.name
                color: "white"
                font.pixelSize: Math.round(desktopView.height * 0.036)
                font.bold: true
            }
        }
    }
}
