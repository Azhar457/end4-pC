pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool isVideo: false
    property bool isPlaying: false
    property bool isMuted: true
    property real volume: 1.0
    property bool manualPaused: false

    function load() {}

    signal playRequested()
    signal pauseRequested()
    signal togglePlayRequested()
    signal toggleMuteRequested()

    function play() {
        manualPaused = false;
        playRequested();
    }

    function pause() {
        manualPaused = true;
        pauseRequested();
    }

    function togglePlay() {
        if (isPlaying) {
            pause();
        } else {
            play();
        }
    }

    function toggleMute() {
        isMuted = !isMuted;
        toggleMuteRequested();
    }

    function setVolume(v) {
        volume = Math.max(0.0, Math.min(1.0, v));
    }

    IpcHandler {
        target: "liveWallpaper"

        function play(): void { root.play(); }
        function pause(): void { root.pause(); }
        function toggle(): void { root.togglePlay(); }
        function toggleMute(): void { root.toggleMute(); }
        function setVolume(v: real): void { root.setVolume(v); }
    }
}
