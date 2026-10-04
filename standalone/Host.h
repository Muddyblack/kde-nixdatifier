#pragma once

#include <QColor>
#include <QElapsedTimer>
#include <QLocalServer>
#include <QMenu>
#include <QObject>
#include <QString>
#include <QSystemTrayIcon>
#include <QTimer>
#include <memory>

#include "TrayIconRenderer.h"

// Path of the per-user socket a running instance listens on.
QString socketPath();

// Everything the QML side needs from the desktop that Qt Quick alone cannot
// give it: a tray icon, a single running instance with a small command socket
// (so panels and launchers can drive it), and a few file helpers.
class Host : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString dataDir READ dataDir CONSTANT)
    Q_PROPERTY(QString configPath READ configPath CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(bool startHidden READ startHidden CONSTANT)
    Q_PROPERTY(bool smokeTest READ smokeTest CONSTANT)
    Q_PROPERTY(bool trayAvailable READ trayAvailable NOTIFY trayAvailableChanged)
    Q_PROPERTY(QString statusJson MEMBER m_statusJson)
    Q_PROPERTY(QString tooltip MEMBER m_tooltip WRITE setTooltip)
    Q_PROPERTY(QString iconStyle MEMBER m_iconStyle WRITE setIconStyle)
    Q_PROPERTY(QColor accent MEMBER m_accent WRITE setAccent)
    Q_PROPERTY(int updates MEMBER m_updates WRITE setUpdates)
    Q_PROPERTY(bool working MEMBER m_working WRITE setWorking)
    Q_PROPERTY(bool motion MEMBER m_motion WRITE setMotion)
public:
    Host(const QString &dataDir, bool startHidden);
    ~Host() override;

    // Binds the single-instance socket. False means another instance owns it.
    bool listen(const QString &name);
    QString dataDir() const { return m_dataDir; }
    QString configPath() const;
    QString version() const;
    bool startHidden() const { return m_startHidden; }
    bool smokeTest() const { return qEnvironmentVariable("NIXDATIFIER_SMOKE_TEST") == QLatin1String("1"); }
    bool trayAvailable() const { return m_trayAvailable; }

    Q_INVOKABLE QString readFile(const QString &path) const;
    Q_INVOKABLE bool writeFile(const QString &path, const QString &text) const;
    // The smoke test's marker: QML console.log is compiled out of release
    // builds, so print to stdout directly.
    Q_INVOKABLE void reportLoaded() const;
    // Re-evaluates tray availability: panels often register their
    // StatusNotifierWatcher a moment after the session starts.
    Q_INVOKABLE bool checkTray();

    void setTooltip(const QString &value);
    void setIconStyle(const QString &value);
    void setAccent(const QColor &value);
    void setUpdates(int value);
    void setWorking(bool value);
    void setMotion(bool value);

signals:
    void showRequested();
    void hideRequested();
    void toggleRequested();
    void refreshRequested();
    void settingsRequested();
    void quitRequested();
    void trayAvailableChanged();

private:
    void handleConnection();
    void updateTray();
    void paint(bool force);

    QString m_dataDir;
    bool m_startHidden;
    bool m_trayAvailable = false;
    QString m_statusJson = QStringLiteral("{\"text\":\"\",\"tooltip\":\"Nixdatifier is starting\",\"class\":\"starting\"}");
    QString m_tooltip = QStringLiteral("Nixdatifier");
    QString m_iconStyle = QStringLiteral("colored");
    QColor m_accent = QColor(QStringLiteral("#91bcff"));
    int m_updates = 0;
    bool m_working = false;
    bool m_motion = true;

    QLocalServer server;
    std::unique_ptr<TrayIconRenderer> icons;
    QSystemTrayIcon tray;
    QMenu menu;
    QTimer animation;
    QElapsedTimer elapsed;
    int lastFrame = -1;
};
