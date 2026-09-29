#include "TrayIconRenderer.h"

#include <QPainter>
#include <QPixmap>
#include <algorithm>
#include <cmath>

TrayIconRenderer::TrayIconRenderer(const QString &path) {
    QSvgRenderer logo(path);
    if (!logo.isValid()) return;
    QImage source(Size * Scale, Size * Scale, QImage::Format_ARGB32_Premultiplied);
    source.fill(Qt::transparent);
    {
        QPainter painter(&source);
        painter.setRenderHint(QPainter::Antialiasing);
        logo.render(&painter, QRectF(5 * Scale, 5 * Scale, 54 * Scale, 54 * Scale));
    }
    // Fit the painted artwork inside a circle so no angle clips the corners.
    const double center = source.width() / 2.0;
    double radius = 0;
    for (int y = 0; y < source.height(); ++y) {
        const auto *pixels = reinterpret_cast<const QRgb *>(source.constScanLine(y));
        for (int x = 0; x < source.width(); ++x) {
            if (qAlpha(pixels[x]) != 0)
                radius = std::max(radius, std::hypot(x + 0.5 - center, y + 0.5 - center));
        }
    }
    const double fit = radius > 0 ? std::min(1.0, (center - Scale) / radius) : 1.0;
    original = QImage(source.size(), source.format());
    original.fill(Qt::transparent);
    QPainter painter(&original);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    const double edge = center * (1.0 - fit);
    painter.drawImage(QRectF(edge, edge, source.width() * fit, source.height() * fit), source);
}

bool TrayIconRenderer::setAppearance(const QString &nextStyle, const QColor &nextAccent, int nextUpdates) {
    nextUpdates = std::max(0, std::min(100, nextUpdates));
    if (style == nextStyle && accent == nextAccent && updates == nextUpdates) return false;
    const bool recolor = glyph.isNull() || style != nextStyle || accent != nextAccent;
    style = nextStyle;
    accent = nextAccent;
    updates = nextUpdates;
    frames.fill(QIcon());
    if (recolor) {
        glyph = original.copy();
        if (style != "colored") {
            QPainter painter(&glyph);
            painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
            painter.fillRect(glyph.rect(), style == "white" ? QColor(Qt::white) : style == "black" ? QColor(Qt::black) : accent);
        }
    }
    return true;
}

QIcon TrayIconRenderer::frame(int index) {
    index = std::clamp(index, 0, FrameCount - 1);
    if (!frames[index].isNull()) return frames[index];
    QImage image(glyph.size(), QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    {
        QPainter painter(&image);
        painter.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
        painter.translate(image.width() / 2.0, image.height() / 2.0);
        painter.rotate(index * (360.0 / FrameCount));
        painter.drawImage(-image.width() / 2, -image.height() / 2, glyph);
        painter.resetTransform();
        if (updates > 0) {
            painter.scale(Scale, Scale);
            painter.setPen(Qt::NoPen);
            painter.setBrush(accent);
            painter.drawEllipse(QRectF(36, 0, 28, 28));
            painter.setPen(QColor("#131923"));
            QFont font = painter.font();
            font.setPixelSize(17);
            font.setBold(true);
            painter.setFont(font);
            painter.drawText(QRect(36, 0, 28, 28), Qt::AlignCenter, updates > 99 ? "99+" : QString::number(updates));
        }
    }
    frames[index] = QIcon(QPixmap::fromImage(image.scaled(Size, Size, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)));
    return frames[index];
}

void TrayIconRenderer::releaseAnimationFrames() {
    for (int i = 1; i < FrameCount; ++i) frames[i] = QIcon();
}

int TrayIconRenderer::cachedFrameCount() const {
    return std::count_if(frames.begin(), frames.end(), [](const QIcon &icon) { return !icon.isNull(); });
}
