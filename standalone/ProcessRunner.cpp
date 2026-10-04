#include "ProcessRunner.h"

void ProcessRunner::exec(const QString &cmd, const QJSValue &cb) {
    command = cmd;
    callback = cb;
    process = new QProcess(this);
    // Nothing the scripts run should ever wait on a terminal.
    process->setStandardInputFile(QProcess::nullDevice());
    connect(process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        finish(QString::fromUtf8(process->readAllStandardOutput()),
               QString::fromUtf8(process->readAllStandardError()),
               status == QProcess::NormalExit ? code : 1);
    });
    // FailedToStart never emits finished(); without this the caller's busy
    // flag would stay set forever.
    connect(process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            finish(QString(), QStringLiteral("Could not start bash"), 127);
    });
    process->start(QStringLiteral("bash"), {QStringLiteral("-c"), cmd});
}

void ProcessRunner::finish(const QString &out, const QString &err, int code) {
    if (done)
        return;
    done = true;
    QJSValue cb = callback;
    callback = QJSValue();
    if (cb.isCallable())
        cb.call({command, out, err, code});
    deleteLater();
}
