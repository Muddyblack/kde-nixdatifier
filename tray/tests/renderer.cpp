#include "TrayIconRenderer.h"
#include <QApplication>
#include <QElapsedTimer>
#include <QPainter>
#include <QTemporaryDir>
#include <QFile>
#include <cstdio>
#include <cstdlib>

static void check(bool ok, const char *message) {
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    check(argc == 2, "provide the project icon path");
    TrayIconRenderer renderer(QString::fromLocal8Bit(argv[1]));
    check(renderer.isValid(), "project SVG loads");
    check(renderer.setAppearance("colored", QColor("#91bcff"), 0), "first appearance loads");
    QElapsedTimer timer;
    timer.start();
    for (int i = 0; i < TrayIconRenderer::FrameCount; ++i) {
        const auto icon = renderer.frame(i);
        check(!icon.isNull(), "frame exists");
        check(icon.cacheKey() == renderer.frame(i).cacheKey(), "same frame reuses its QIcon");
        const auto image = icon.pixmap(64, 64).toImage();
        check(image.size() == QSize(64, 64), "frame dimensions remain fixed");
        for (int x = 0; x < 64; ++x) {
            check(qAlpha(image.pixel(x, 0)) == 0 && qAlpha(image.pixel(x, 63)) == 0,
                  "rotating artwork is not clipped at top/bottom");
            check(qAlpha(image.pixel(0, x)) == 0 && qAlpha(image.pixel(63, x)) == 0,
                  "rotating artwork is not clipped at left/right");
        }
    }
    const auto warmupNs = timer.nsecsElapsed();
    check(renderer.cachedFrameCount() == 60, "frame cache is bounded at 60");
    check(!renderer.setAppearance("colored", QColor("#91bcff"), 0), "unchanged appearance preserves cache");
    timer.restart();
    for (int i = 0; i < 6000; ++i) renderer.frame(i % 60);
    const auto cachedNs = timer.nsecsElapsed();
    renderer.releaseAnimationFrames();
    check(renderer.cachedFrameCount() == 1, "idle releases every rotating frame");
    for (const QString &style : {QString("white"), QString("black"), QString("accent")}) {
        check(renderer.setAppearance(style, QColor("#ff8040"), 0), "style changes invalidate cache");
        check(renderer.cachedFrameCount() == 0, "old frames released on appearance change");
        const auto image = renderer.frame(0).pixmap(64,64).toImage().convertToFormat(QImage::Format_ARGB32);
        const QColor expected = style == "white" ? QColor(Qt::white) : style == "black" ? QColor(Qt::black) : QColor("#ff8040");
        bool found = false;
        for (int y = 0; y < 64; ++y) for (int x = 0; x < 64; ++x) {
            const QColor color(image.pixel(x, y));
            if (qAlpha(image.pixel(x, y)) > 250) {
                check(std::abs(color.red() - expected.red()) <= 1 && std::abs(color.green() - expected.green()) <= 1 && std::abs(color.blue() - expected.blue()) <= 1, "tint survives rotation/downsampling");
                found = true;
            }
        }
        check(found, "tinted icon contains opaque pixels");
    }
    renderer.setAppearance("colored", QColor("#91bcff"), 101);
    renderer.frame(0);
    check(!renderer.setAppearance("colored", QColor("#91bcff"), 999), "99+ badge does not redraw for equivalent counts");
    QSvgRenderer svg(QString::fromLocal8Bit(argv[1]));
    timer.restart();
    for (int i = 0; i < 60; ++i) {
        QImage glyph(64,64,QImage::Format_ARGB32_Premultiplied); glyph.fill(Qt::transparent);
        QPainter painter(&glyph); painter.setRenderHint(QPainter::Antialiasing);
        svg.render(&painter, QRectF(5,5,54,54));
    }
    std::printf("PASS: frames, clipping, cache reuse/release, colors and badge invalidation\n");
    std::printf("60 old SVG renders: %.2f ms; 60 new frames incl checks: %.2f ms; 6000 cached frame lookups: %.2f ms\n",
                timer.nsecsElapsed()/1e6, warmupNs/1e6, cachedNs/1e6);
    return 0;
}
