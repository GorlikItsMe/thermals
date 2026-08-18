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

  function tempColor(temp) {
    var normal = root.bar ? root.bar.barForeground : Color.foreground
    if (typeof temp !== "number" || temp === -Infinity) return normal
    if (temp >= 70) return root.tempRed
    if (temp >= 50) return root.tempYellow
    return normal
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

  // Rich text: only the reading (e.g. 65°) is tinted; "CPU"/"GPU" labels stay
  // in the bar's normal foreground.
  readonly property string labelText: {
    var cpu = root.tempColor(Number(root.cpuTemp))
    var gpu = root.tempColor(Number(root.gpuTemp))
    return 'CPU <span style="color:' + cpu + '">' + root.cpuTemp + '°</span>' +
           '  GPU <span style="color:' + gpu + '">' + root.gpuTemp + '°</span>'
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.labelText
    tooltipText: "Open Thermals"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
