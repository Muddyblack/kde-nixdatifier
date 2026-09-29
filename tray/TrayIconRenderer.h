#pragma once

#include <QColor>
#include <QIcon>
#include <QImage>
#include <QString>
#include <QSvgRenderer>
#include <array>

// A bounded frame cache. The SVG is rasterized once; rotating frames are built
// lazily and released when work stops. Tooltips never invalidate the artwork.
class TrayIconRenderer {
public:
    static constexpr int FrameCount = 60;
    static constexpr int FrameInterval = 30;
    explicit TrayIconRenderer(const QString &path);
    bool isValid() const { return !original.isNull(); }
    bool setAppearance(const QString &style, const QColor &accent, int updates);
    QIcon frame(int index);
    void releaseAnimationFrames();
    int cachedFrameCount() const;

private:
    static constexpr int Size = 64;
    static constexpr int Scale = 3;
    QImage original;
    QImage glyph;
    QString style;
    QColor accent;
    int updates = -1;
    std::array<QIcon, FrameCount> frames;
};
