#include "Host.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocalSocket>
#include <QSaveFile>
#include <QStandardPaths>
#include <cstdio>

QString socketPath() {
    QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (runtime.isEmpty())
        runtime = QDir::tempPath();
    return runtime + QStringLiteral("/nixdatifier.sock");
}

Host::Host(const QString &dataDir, bool startHidden) : m_dataDir(dataDir), m_startHidden(startHidden) {
    icons = std::make_unique<TrayIconRenderer>(m_dataDir + QStringLiteral("/package/icon-emblem.svg"));

    const struct {
        const char *label;
        void (Host::*signal)();
    } entries[] = {{"Open Nixdatifier", &Host::showRequested},
                   {"Refresh", &Host::refreshRequested},
                   {"Settings…", &Host::settingsRequested}};
    for (const auto &entry : entries)
        connect(menu.addAction(QString::fromUtf8(entry.label)), &QAction::triggered, this, entry.signal);
    menu.addSeparator();
    connect(menu.addAction(QStringLiteral("Quit")), &QAction::triggered, this, &Host::quitRequested);
    tray.setContextMenu(&menu);
    connect(&tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger)
            emit toggleRequested();
    });

    animation.setInterval(TrayIconRenderer::FrameInterval);
    animation.setTimerType(Qt::PreciseTimer);
    connect(&animation, &QTimer::timeout, this, [this] { paint(false); });

    if (icons->isValid()) {
        updateTray();
        tray.setToolTip(m_tooltip);
        tray.show();
    }
    checkTray();
}

Host::~Host() {
    server.close();
    QLocalServer::removeServer(socketPath());
}

bool Host::listen(const QString &) {
    // Reached only after main() found nobody answering, so a leftover socket
    // file is stale and safe to replace.
    QLocalServer::removeServer(socketPath());
    server.setSocketOptions(QLocalServer::UserAccessOption);
    connect(&server, &QLocalServer::newConnection, this, &Host::handleConnection);
    return server.listen(socketPath());
}

QString Host::configPath() const {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) +
           QStringLiteral("/nixdatifier/standalone.json");
}

QString Host::version() const {
    return QStringLiteral(NIXDATIFIER_VERSION);
}

QString Host::readFile(const QString &path) const {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()) : QString();
}

bool Host::writeFile(const QString &path, const QString &text) const {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path); // atomic: readers never see a half-written file
    return file.open(QIODevice::WriteOnly) && file.write(text.toUtf8()) >= 0 && file.commit();
}

void Host::reportLoaded() const {
    fputs("NIXDATIFIER_HOST_LOADED\n", stdout);
    fflush(stdout);
}

bool Host::checkTray() {
    const bool available = icons && icons->isValid() && QSystemTrayIcon::isSystemTrayAvailable();
    if (available != m_trayAvailable) {
        m_trayAvailable = available;
        emit trayAvailableChanged();
    }
    return m_trayAvailable;
}

void Host::handleConnection() {
    while (auto *socket = server.nextPendingConnection()) {
        connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
        connect(socket, &QLocalSocket::readyRead, this, [this, socket] {
            if (!socket->canReadLine())
                return;
            const QString command = QString::fromUtf8(socket->readLine()).trimmed();
            QByteArray reply = "ok\n";
            if (command == QLatin1String("show"))
                emit showRequested();
            else if (command == QLatin1String("hide"))
                emit hideRequested();
            else if (command == QLatin1String("toggle"))
                emit toggleRequested();
            else if (command == QLatin1String("refresh"))
                emit refreshRequested();
            else if (command == QLatin1String("settings"))
                emit settingsRequested();
            else if (command == QLatin1String("quit"))
                emit quitRequested();
            else if (command == QLatin1String("status"))
                reply = (m_statusJson + QLatin1Char('\n')).toUtf8();
            else
                reply = "error: unknown command\n";
            socket->write(reply);
            socket->disconnectFromServer();
        });
    }
}

void Host::setTooltip(const QString &value) {
    m_tooltip = value;
    tray.setToolTip(value);
}
void Host::setIconStyle(const QString &value) {
    m_iconStyle = value;
    updateTray();
}
void Host::setAccent(const QColor &value) {
    m_accent = value;
    updateTray();
}
void Host::setUpdates(int value) {
    m_updates = value;
    updateTray();
}
void Host::setWorking(bool value) {
    m_working = value;
    updateTray();
}
void Host::setMotion(bool value) {
    m_motion = value;
    updateTray();
}

void Host::paint(bool force) {
    if (!icons->isValid())
        return;
    const int frame = animation.isActive()
        ? (elapsed.elapsed() / TrayIconRenderer::FrameInterval) % TrayIconRenderer::FrameCount : 0;
    if (!force && frame == lastFrame)
        return;
    tray.setIcon(icons->frame(frame));
    lastFrame = frame;
}

void Host::updateTray() {
    if (!icons || !icons->isValid())
        return;
    const QColor accent = m_accent.isValid() ? m_accent : QColor(QStringLiteral("#91bcff"));
    const bool changed = icons->setAppearance(m_iconStyle, accent, m_updates);
    const bool spin = m_working && m_motion;
    if (spin && !animation.isActive()) {
        elapsed.start();
        animation.start();
    } else if (!spin && animation.isActive()) {
        animation.stop();
        elapsed.invalidate();
    }
    paint(changed);
    if (!spin)
        icons->releaseAnimationFrames();
}
