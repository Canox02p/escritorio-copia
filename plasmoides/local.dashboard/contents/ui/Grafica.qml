import QtQuick
import QtQuick.Shapes

// Gráfica de líneas para el tráfico de red.
Item {
    id: g

    property var p
    property var serieA: []
    property var serieB: []

    readonly property real techo: {
        let m = 1
        for (const v of serieA) m = Math.max(m, v)
        for (const v of serieB) m = Math.max(m, v)
        return m
    }

    // Los mismos puntos pero cerrando contra el suelo, para poder rellenar
    function puntosRelleno(serie) {
        const lista = g.puntos(serie)
        if (lista.length === 0) return lista
        return lista.concat([Qt.point(g.width, g.height), Qt.point(0, g.height)])
    }

    function puntos(serie) {
        const lista = []
        const n = serie.length
        if (n < 2) return lista
        for (let i = 0; i < n; i++) {
            lista.push(Qt.point(i * g.width / (n - 1),
                                g.height - (serie[i] / g.techo) * g.height * 0.92))
        }
        return lista
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        // Relleno suave bajo cada línea
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.rgba(g.p.texto.r, g.p.texto.g, g.p.texto.b, 0.10)
            PathPolyline { path: g.puntosRelleno(g.serieA) }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.rgba(g.p.acento.r, g.p.acento.g, g.p.acento.b, 0.12)
            PathPolyline { path: g.puntosRelleno(g.serieB) }
        }
        ShapePath {
            strokeColor: g.p.texto
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: g.puntos(g.serieA) }
        }
        ShapePath {
            strokeColor: g.p.acento
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: g.puntos(g.serieB) }
        }
    }
}
