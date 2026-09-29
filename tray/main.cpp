#include <QApplication>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMenu>
#include <QElapsedTimer>
#include <QProcess>
#include "TrayIconRenderer.h"
#include <QSystemTrayIcon>
#include <QTimer>

// A standard StatusNotifier entry through Qt. Status changes arrive through
// inotify; IPC runs only in response to a user's action, never on a poll timer.
int main(int argc, char **argv) {
    QApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);
    if (argc != 5) return 2; // qs executable, config root, status file, original SVG
    const QString qs = QString::fromLocal8Bit(argv[1]);
    const QString config = QString::fromLocal8Bit(argv[2]);
    const QString statusPath = QString::fromLocal8Bit(argv[3]);
    TrayIconRenderer icons(QString::fromLocal8Bit(argv[4]));
    if (!icons.isValid()) return 2;
    QSystemTrayIcon tray;
    QMenu menu;
    auto call = [&](const QString &action) {
        auto *job = new QProcess(&app);
        QObject::connect(job, &QProcess::finished, job, &QObject::deleteLater);
        QObject::connect(job, &QProcess::errorOccurred, job, &QObject::deleteLater);
        job->start(qs, {"ipc", "--path", config, "call", "panel", action});
    };
    for (const auto &entry : {qMakePair(QString("Open Nixdatifier"), QString("open")),
                             qMakePair(QString("Refresh"), QString("refresh")),
                             qMakePair(QString("Settings…"), QString("configure")),
                             qMakePair(QString("Quit"), QString("quit"))}) {
        QObject::connect(menu.addAction(entry.first), &QAction::triggered, &app,
                         [&, action = entry.second] { call(action); });
    }
    tray.setContextMenu(&menu);
    QObject::connect(&tray, &QSystemTrayIcon::activated, &app,
                     [&](QSystemTrayIcon::ActivationReason reason) {
                         if (reason == QSystemTrayIcon::Trigger) call("toggle");
                     });
    QJsonObject state;
    QElapsedTimer elapsed;
    int lastFrame = -1;
    QTimer animation;
    animation.setInterval(TrayIconRenderer::FrameInterval);
    animation.setTimerType(Qt::PreciseTimer);
    auto paint = [&](bool force = false) {
        const int frame = animation.isActive()
            ? (elapsed.elapsed() / TrayIconRenderer::FrameInterval) % TrayIconRenderer::FrameCount : 0;
        if (!force && frame == lastFrame) return;
        tray.setIcon(icons.frame(frame));
        lastFrame = frame;
    };
    QObject::connect(&animation, &QTimer::timeout, &app, [&] { paint(); });
    QFileSystemWatcher watch;
    auto reload = [&] {
        // Atomic file replacement can produce both directory and file events.
        // Reattach the watch even if the JSON has not changed.
        if (!watch.files().contains(statusPath) && QFileInfo::exists(statusPath)) watch.addPath(statusPath);
        QFile file(statusPath);
        if (!file.open(QIODevice::ReadOnly)) return;
        const auto document = QJsonDocument::fromJson(file.readAll());
        if (!document.isObject() || document.object() == state) return;
        const auto next = document.object();
        if (next.value("summary") != state.value("summary"))
            tray.setToolTip(next.value("summary").toString("Nixdatifier"));
        state = next;
        QColor accent(state.value("accent").toString("#91bcff"));
        if (!accent.isValid()) accent = QColor("#91bcff");
        const bool appearanceChanged = icons.setAppearance(state.value("iconStyle").toString("colored"),
                                                           accent, state.value("updates").toInt());
        const bool working = state.value("working").toBool() && state.value("motion").toBool(true);
        if (working && !animation.isActive()) {
            elapsed.start();
            animation.start();
        } else if (!working && animation.isActive()) {
            animation.stop();
            elapsed.invalidate();
        }
        paint(appearanceChanged);
        if (!working) icons.releaseAnimationFrames();
    };
    icons.setAppearance("colored", QColor("#91bcff"), 0);
    tray.setToolTip("Nixdatifier");
    paint();
    watch.addPath(QFileInfo(statusPath).absolutePath());
    QObject::connect(&watch, &QFileSystemWatcher::directoryChanged, &app, reload);
    QObject::connect(&watch, &QFileSystemWatcher::fileChanged, &app, reload);
    reload();
    tray.show();
    return app.exec();
}
