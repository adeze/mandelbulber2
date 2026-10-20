#ifndef MANDELBULBER2_QT_RENDER_CONTROLS_H_
#define MANDELBULBER2_QT_RENDER_CONTROLS_H_

#include <QQuickWidget>

class cRenderControlsWidget : public QQuickWidget
{
	Q_OBJECT
public:
	explicit cRenderControlsWidget(QWidget *parent = nullptr);
	void SetRenderEnabled(bool enabled);
	void SetHistoryEnabled(bool enabled);
	void SetNavigationActionsVisible(bool visible);

signals:
	void renderRequested();
	void stopRequested();
	void undoRequested();
	void redoRequested();
	void navigatorRequested();
};

#endif
