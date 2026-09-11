import QtQuick
import Quickshell.Io

Process {
    id: process
    property var callback: null
    property string sourceCommand: ""
    stdout: StdioCollector {
        id: output
    }
    stderr: StdioCollector {
        id: errors
    }
    function exec(cmd, cb) {
        sourceCommand = cmd;
        callback = cb;
        command = ["bash", "-c", cmd];
        running = true;
    }
    onExited: (exitCode, exitStatus) => {
        const cb = callback;
        callback = null;
        if (cb)
            cb(sourceCommand, output.text, errors.text, exitCode);
        destroy();
    }
}
