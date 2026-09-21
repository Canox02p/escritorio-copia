import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    readonly property string dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))

    Plasmoid.icon: "notifications"
    toolTipMainText: "Centro de avisos"
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    Paleta { id: paletaColores; dirCodigo: root.dirCodigo }

    fullRepresentation: PanelAvisos {
        Layout.minimumWidth: 300
        Layout.minimumHeight: 420
        Layout.preferredWidth: 330
        Layout.preferredHeight: 620

        p: paletaColores
        dirCodigo: root.dirCodigo
    }
}
