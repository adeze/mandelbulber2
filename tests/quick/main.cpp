#include <QtQuickTest/quicktest.h>
#include <QFont>
#include <QGuiApplication>

class QuickTestSetup : public QObject
{
    Q_OBJECT
public slots:
    void applicationAvailable()
    {
#ifdef Q_OS_MACOS
        QGuiApplication::setFont(QFont(QStringLiteral("Helvetica")));
#endif
    }
};

QUICK_TEST_MAIN_WITH_SETUP(mandelbulber_quick, QuickTestSetup)
#include "main.moc"
