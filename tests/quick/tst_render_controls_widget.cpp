#include <QQuickItem>
#include <QRegularExpression>
#include <QSignalSpy>
#include <QtTest>

#include "render_controls.h"

class RenderControlsWidgetTest : public QObject
{
    Q_OBJECT
private slots:
    void loadsResourcesForwardsActionsAndUpdatesState()
    {
        QTest::failOnWarning(QRegularExpression(QStringLiteral(".*")));
#ifdef Q_OS_MACOS
        qApp->setFont(QFont(QStringLiteral("Helvetica")));
#endif
        QWidget host;
        host.setFixedSize(400, 300);
        cRenderControlsWidget widget(&host);
        widget.resize(host.width(), widget.height());
        QCOMPARE(widget.status(), QQuickWidget::Ready);
        auto *root = widget.rootObject();
        QVERIFY(root);
        host.show();
        QVERIFY(QTest::qWaitForWindowExposed(&host));
        QVERIFY(widget.height() > 0);
        const int fullHeight = widget.height();

        const char *signalSignatures[] = {"renderRequested()", "stopRequested()", "undoRequested()",
            "redoRequested()", "navigatorRequested()"};
        const char *methods[] = {"renderRequested", "stopRequested", "undoRequested",
            "redoRequested", "navigatorRequested"};
        for (int i = 0; i < 5; ++i)
        {
            const int index = widget.metaObject()->indexOfSignal(signalSignatures[i]);
            QVERIFY(index >= 0);
            QSignalSpy spy(&widget, widget.metaObject()->method(index));
            QVERIFY(spy.isValid());
            QVERIFY(QMetaObject::invokeMethod(root, methods[i], Qt::DirectConnection));
            QCOMPARE(spy.count(), 1);
        }

        widget.SetRenderEnabled(false);
        widget.SetHistoryEnabled(false);
        widget.SetNavigationActionsVisible(false);
        QCOMPARE(root->property("renderEnabled").toBool(), false);
        QCOMPARE(root->property("historyEnabled").toBool(), false);
        QCOMPARE(root->property("navigationActionsVisible").toBool(), false);
        QTRY_VERIFY(widget.height() > 0 && widget.height() < fullHeight);
        widget.SetRenderEnabled(true);
        widget.SetHistoryEnabled(true);
        widget.SetNavigationActionsVisible(true);
        QCOMPARE(root->property("renderEnabled").toBool(), true);
        QCOMPARE(root->property("historyEnabled").toBool(), true);
        QCOMPARE(root->property("navigationActionsVisible").toBool(), true);
        QTRY_COMPARE(widget.height(), fullHeight);
    }
};

QTEST_MAIN(RenderControlsWidgetTest)
#include "tst_render_controls_widget.moc"
