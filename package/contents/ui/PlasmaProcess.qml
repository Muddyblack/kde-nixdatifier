import QtQuick
import org.kde.plasma.plasma5support as P5Support

P5Support.DataSource {
    id: process
    engine: "executable"
    connectedSources: []
    property var callback: null
    property string command: ""
    function exec(cmd, cb) {
        command = cmd;
        callback = cb;
        connectSource(cmd);
    }
    onNewData: (source, data) => {
        disconnectSource(source);
        const cb = callback;
        callback = null;
        if (cb)
            cb(command, data.stdout || "", data.stderr || "", data["exit code"] || 0);
        destroy();
    }
    Component.onDestruction: if (command)
        disconnectSource(command)
}
