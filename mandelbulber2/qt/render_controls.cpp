#include "render_controls.h"

#include <cmath>

#include <QDebug>
#include <QQmlError>
#include <QQuickItem>

cRenderControlsWidget::cRenderControlsWidget(QWidget *parent) : QQuickWidget(parent)
{
	setFocusPolicy(Qt::StrongFocus);
	setResizeMode(QQuickWidget::SizeRootObjectToView);
	setSource(QUrl(QStringLiteral("qrc:/qt/qml/Mandelbulber/Gui/RenderControls.qml")));
	if (!rootObject())
	{
		qCritical() << "Cannot load render controls:" << errors();
		return;
	}
	connect(rootObject(), SIGNAL(renderRequested()), this, SIGNAL(renderRequested()));
	connect(rootObject(), SIGNAL(stopRequested()), this, SIGNAL(stopRequested()));
	connect(rootObject(), SIGNAL(undoRequested()), this, SIGNAL(undoRequested()));
	connect(rootObject(), SIGNAL(redoRequested()), this, SIGNAL(redoRequested()));
	connect(rootObject(), SIGNAL(navigatorRequested()), this, SIGNAL(navigatorRequested()));
	const auto updateHeight = [this]() { setFixedHeight(int(std::ceil(rootObject()->implicitHeight()))); };
	// Resizing during Qt Quick's layout pass can re-enter an active Metal frame.
	connect(rootObject(), &QQuickItem::implicitHeightChanged, this, updateHeight, Qt::QueuedConnection);
	updateHeight();
}

void cRenderControlsWidget::SetRenderEnabled(bool enabled)
{
	if (rootObject()) rootObject()->setProperty("renderEnabled", enabled);
}

void cRenderControlsWidget::SetHistoryEnabled(bool enabled)
{
	if (rootObject()) rootObject()->setProperty("historyEnabled", enabled);
}

void cRenderControlsWidget::SetNavigationActionsVisible(bool visible)
{
	if (rootObject()) rootObject()->setProperty("navigationActionsVisible", visible);
}
