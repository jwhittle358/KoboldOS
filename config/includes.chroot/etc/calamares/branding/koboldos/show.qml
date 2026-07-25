import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    function onActivate()   { presentation.currentSlide = 0; }
    function onLeave()      { }

    Slide {
        anchors.fill: parent
        Column {
            anchors.centerIn: parent
            spacing: 24
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "logo.png"
                width: 320
                fillMode: Image.PreserveAspectFit
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Installing KoboldOS…"
                color: "#F5F0E6"
                font.pixelSize: 24
            }
        }
    }

    Slide {
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "A lean Wayland desktop — Sway, Waybar, and Foot — forged on Debian."
            color: "#C8A24A"
            font.pixelSize: 22
        }
    }
}
