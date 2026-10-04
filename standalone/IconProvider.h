#pragma once

#include <QIcon>
#include <QQuickImageProvider>

// Serves icons from the active icon theme as image://nixicon/<name>, which is
// what Quickshell's iconPath() and Kirigami.Icon do on the other hosts.
class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override {
        const QSize wanted = requested.isValid() ? requested : QSize(64, 64);
        const QIcon icon = id.startsWith('/') ? QIcon(id) : QIcon::fromTheme(id);
        QPixmap pixmap = icon.pixmap(wanted);
        if (size)
            *size = pixmap.size();
        return pixmap;
    }
};
