import QtQuick
import QtTest
import "../../mandelbulber2/qml/Mandelbulber/Gui"

Item {
    id: root
    width: 400
    height: 300

    Component {
        id: panelComponent
        RenderControls { width: 400; height: 280 }
    }

    Component {
        id: spyComponent
        SignalSpy {}
    }

    TestCase {
        name: "RenderControls"
        when: windowShown

        function init() {
            failOnWarning(/.?/)
        }

        function signalSpy(panel, signalName) {
            const spy = createTemporaryObject(spyComponent, root, {
                target: panel, signalName: signalName
            })
            verify(!!spy, "Object exists")
            verify(spy.valid)
            return spy
        }

        function test_forwardActions_data() {
            return [
                { tag: "render", button: "renderButton", signal: "renderRequested" },
                { tag: "stop", button: "stopButton", signal: "stopRequested" },
                { tag: "undo", button: "undoButton", signal: "undoRequested" },
                { tag: "redo", button: "redoButton", signal: "redoRequested" },
                { tag: "navigator", button: "navigatorButton", signal: "navigatorRequested" }
            ]
        }

        function test_forwardActions(data) {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel, "Component exists")
            const button = findChild(panel, data.button)
            verify(!!button, "Object exists")
            const spy = signalSpy(panel, data.signal)
            verify(waitForPolish(panel))
            mouseClick(button)
            tryCompare(spy, "count", 1)
        }

        function test_disabledActionsRecover() {
            const panel = createTemporaryObject(panelComponent, root, {
                renderEnabled: false, historyEnabled: false
            })
            verify(!!panel, "Component exists")
            const actions = [
                { button: "renderButton", signal: "renderRequested" },
                { button: "undoButton", signal: "undoRequested" },
                { button: "redoButton", signal: "redoRequested" }
            ]
            verify(waitForPolish(panel))
            for (const action of actions) {
                const button = findChild(panel, action.button)
                verify(!!button, "Object exists")
                const spy = signalSpy(panel, action.signal)
                compare(button.enabled, false)
                mouseClick(button)
                tryCompare(spy, "count", 0)
                panel.renderEnabled = true
                panel.historyEnabled = true
                tryCompare(button, "enabled", true)
                mouseClick(button)
                tryCompare(spy, "count", 1)
                panel.renderEnabled = false
                panel.historyEnabled = false
            }
            const stopButton = findChild(panel, "stopButton")
            verify(!!stopButton, "Object exists")
            const stopSpy = signalSpy(panel, "stopRequested")
            mouseClick(stopButton)
            tryCompare(stopSpy, "count", 1)
        }

        function test_navigationVisibilityPreservesRenderActions() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel, "Component exists")
            panel.navigationActionsVisible = false
            for (const name of ["undoButton", "redoButton", "navigatorButton"]) {
                const button = findChild(panel, name)
                verify(!!button, "Object exists")
                tryCompare(button, "visible", false)
            }
            for (const name of ["renderButton", "stopButton"]) {
                const button = findChild(panel, name)
                verify(!!button, "Object exists")
                compare(button.visible, true)
            }
            panel.navigationActionsVisible = true
            for (const name of ["undoButton", "redoButton", "navigatorButton"]) {
                const button = findChild(panel, name)
                verify(!!button, "Object exists")
                tryCompare(button, "visible", true)
            }
        }
    }
}
