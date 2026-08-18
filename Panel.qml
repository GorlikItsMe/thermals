import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ak.thermals"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // Rows without a real reading (e.g. no GPU temp, no fan exposed in sysfs)
  // are dropped so the panel doesn't show "n/a" clutter.
  readonly property var rows: {
    var w = root.w
    return [
      { label: "CPU Temp", value: w && w.cpuTemp !== "-" ? w.cpuTemp + " °C" : "" },
      { label: "CPU Fan", value: w && w.cpuFan !== "-" ? w.cpuFan + " RPM" : "" },
      { label: "GPU Temp", value: w && w.gpuTemp !== "-" ? w.gpuTemp + " °C" : "" },
      { label: "GPU Fan", value: w && w.gpuFan !== "-" ? w.gpuFan + " RPM" : "" }
    ].filter(function(r) { return r.value !== "" })
  }

  readonly property var w: hostWidget

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(260))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        Text {
          width: parent.width
          text: "Thermals"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Repeater {
          model: root.rows

          delegate: RowLayout {
            required property var modelData
            width: parent ? parent.width : 0
            spacing: Style.space(8)

            Text {
              Layout.fillWidth: true
              text: parent.modelData.label
              color: root.barForeground
              opacity: 0.7
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              text: parent.modelData.value
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }
        }
      }
    }
  }
}
