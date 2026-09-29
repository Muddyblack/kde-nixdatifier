import QtQuick
import QtTest
import org.kde.kirigami as Kirigami

Item {
    id: scene
    width: 700
    height: 750
    TestCase {
        name: "PlasmaSettingsContract"
        when: windowShown
        function test_defaults_are_accepted_and_independent() {
            const component = Qt.createComponent("../package/contents/ui/configGeneral.qml");
            compare(component.status, Component.Ready, component.errorString());
            const page = createTemporaryObject(component, scene);
            verify(page !== null);
            const initial = {};
            let count = 0;
            for (const key in page) {
                if (key.startsWith("cfg_") && !key.endsWith("Default") && typeof page[key] !== "function") {
                    verify((key + "Default") in page, "Missing default: " + key);
                    initial[key + "Default"] = page[key];
                    count++;
                }
            }
            verify(count > 30);
            initial.cfg_fontScale = 1.5;
            initial.cfg_fontScaleDefault = 1.0;
            const configured = createTemporaryObject(component, scene, initial);
            verify(configured !== null);
            compare(configured.cfg_fontScale, 1.5);
            compare(configured.cfg_fontScaleDefault, 1.0);
            configured.cfg_fontScale = 1.2;
            compare(configured.cfg_fontScaleDefault, 1.0);
            compare(configured.globalToolBarStyle, Kirigami.ApplicationHeaderStyle.None);
            compare(configured.topPadding, 0);
        }
    }
}
