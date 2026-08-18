import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "ak.thermals"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  property string cpuTemp: "-"
  property string gpuTemp: "-"
  property string gpuFan: "-"
  property string cpuFan: "-"

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  // Temperature tint shared with the panel: yellow 50–70 °C, red above.
  // Explicit hex colors — Qt.red/Qt.yellow render black in this shell.
  readonly property color tempYellow: "#f7c948"
  readonly property color tempRed: "#f03e3e"
  // Neutral color for the "CPU"/"GPU" label text.
  readonly property color labelColor: root.bar ? root.bar.barForeground : Color.foreground

  function tempColor(temp) {
    if (typeof temp !== "number" || isNaN(temp)) return root.labelColor
    if (temp >= 70) return root.tempRed
    if (temp >= 50) return root.tempYellow
    return root.labelColor
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  // Make the slot wide enough for the segmented label (button text is hidden).
  width: label.implicitWidth + Style.space(17)
  height: button.implicitHeight

  onBarChanged: injectPanel()

  Component.onCompleted: console.log("ak.thermals: BarWidget created")

  // One persistent collector process streams a line per interval. Slow while
  // the panel is closed (bar label only), fast while it is open.
  readonly property int pollInterval: opened ? 2000 : 10000

  Process {
    id: sensorsProcess
    command: [String(Qt.resolvedUrl("sensors.sh")).replace("file://", ""), "--loop", "--interval", String(Math.round(root.pollInterval / 1000))]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split(/\s+/)
        if (parts.length === 4) {
          root.cpuTemp = parts[0]
          root.gpuTemp = parts[1]
          root.gpuFan = parts[2]
          root.cpuFan = parts[3]
        }
      }
    }

    Component.onCompleted: {
      console.log("ak.thermals: starting collector", JSON.stringify(command))
      running = true
    }
  }

  onPollIntervalChanged: {
    sensorsProcess.running = false
    sensorsProcess.command = [String(Qt.resolvedUrl("sensors.sh")).replace("file://", ""), "--loop", "--interval", String(Math.round(pollInterval / 1000))]
    sensorsProcess.running = true
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // Label color for the plain "CPU"/"GPU" names (bar's normal foreground).
  readonly property color labelColor: root.bar ? root.bar.barForeground : Color.foreground

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 8.75
    verticalPadding: 8.75
    implicitWidth: label.impliedWidth + Style.spaceReal(horizontalMargin) * 2
    tooltipText: "Open Thermals"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }

    // Separate Texts so only the readings are tinted; "CPU"/"GPU" stay plain.
    Row {
      id: label
      anchors.centerIn: parent
      spacing: Style.space(4)
      property real impliedWidth: childrenRect.width

      Text { text: "CPU"; color: root.labelColor; font.family: button.fontFamily; font.pixelSize: button.fontSize }
      Text { text: root.cpuTemp + "°"; color: root.tempColor(Number(root.cpuTemp)); font.family: button.fontFamily; font.pixelSize: button.fontSize; font.bold: true }
      Text { text: "GPU"; color: root.labelColor; font.family: button.fontFamily; font.pixelSize: button.fontSize }
      Text { text: root.gpuTemp + "°"; color: root.tempColor(Number(root.gpuTemp)); font.family: button.fontFamily; font.pixelSize: button.fontSize; font.bold: true }
    }
  }

}
