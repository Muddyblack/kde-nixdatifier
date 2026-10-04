#pragma once

#include <QJSValue>
#include <QObject>
#include <QProcess>

// The one capability plain Qt Quick lacks and every other host provides:
// run a shell command and hand back stdout, stderr and the exit code. It
// mirrors the `exec(cmd, callback)` contract of the Plasma and Quickshell
// adapters, and removes itself once the callback has run.
class ProcessRunner : public QObject {
    Q_OBJECT
public:
    explicit ProcessRunner(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE void exec(const QString &command, const QJSValue &callback);

private:
    void finish(const QString &out, const QString &err, int code);
    QProcess *process = nullptr;
    QString command;
    QJSValue callback;
    bool done = false;
};
