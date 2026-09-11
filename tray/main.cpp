#include <QApplication>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMenu>
#include <QPainter>
#include <QProcess>
#include <QSvgRenderer>
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
    QSvgRenderer logo(QString::fromLocal8Bit(argv[4]));
    if (!logo.isValid()) return 2;
    QSystemTrayIcon tray;
    QMenu menu;
    auto call = [&](const QString &action) {
        auto *job = new QProcess(&app);
        QObject::connect(job, &QProcess::finished, job, &QObject::deleteLater);
        QObject::connect(job, &QProcess::errorOccurred, job, &QObject::deleteLater);
        job->start(qs, {"ipc", "--path", config, "call", "panel", action});
    };
    for (const auto &entry : {qMakePair(QString("Open Nixdatifier"), QString("show")),
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
    int angle = 0;
    QTimer animation;
    animation.setInterval(60);
    auto paint = [&] {
        QPixmap glyph(64,64); glyph.fill(Qt::transparent);
        { QPainter p(&glyph); p.setRenderHint(QPainter::Antialiasing); logo.render(&p, QRectF(5,5,54,54));
          const QString style = state.value("iconStyle").toString("colored");
          if (style != "colored") {
              p.setCompositionMode(QPainter::CompositionMode_SourceIn);
              p.fillRect(glyph.rect(), style == "white" ? QColor("white") : style == "black" ? QColor("black") : QColor(state.value("accent").toString("#91bcff")));
          }
        }
        QPixmap pix(64,64); pix.fill(Qt::transparent);
        QPainter p(&pix); p.setRenderHint(QPainter::Antialiasing);
        p.translate(32,32); p.rotate(angle); p.drawPixmap(-32,-32,glyph); p.resetTransform();
        const int updates=state.value("updates").toInt();
        if (updates>0) {
            p.setPen(Qt::NoPen); p.setBrush(QColor("#91bcff")); p.drawEllipse(QRectF(36,0,28,28));
            p.setPen(QColor("#131923")); QFont f=p.font(); f.setPixelSize(17); f.setBold(true); p.setFont(f);
            p.drawText(QRect(36,0,28,28),Qt::AlignCenter,updates>99 ? "99+" : QString::number(updates));
        }
        p.end(); tray.setIcon(QIcon(pix));
    };
    QObject::connect(&animation, &QTimer::timeout, &app, [&] { angle=(angle+12)%360; paint(); });
    QFileSystemWatcher watch;
    auto reload = [&] {
        QFile file(statusPath);
        if (file.open(QIODevice::ReadOnly)) {
            const auto document=QJsonDocument::fromJson(file.readAll());
            if (document.isObject()) state=document.object();
        }
        if (!watch.files().contains(statusPath) && QFileInfo::exists(statusPath)) watch.addPath(statusPath);
        tray.setToolTip(state.value("summary").toString("Nixdatifier"));
        if (state.value("working").toBool() && state.value("motion").toBool(true)) animation.start();
        else { animation.stop(); angle=0; }
        paint();
    };
    watch.addPath(QFileInfo(statusPath).absolutePath());
    QObject::connect(&watch,&QFileSystemWatcher::directoryChanged,&app,reload);
    QObject::connect(&watch,&QFileSystemWatcher::fileChanged,&app,reload);
    reload(); tray.show();
    return app.exec();
}
