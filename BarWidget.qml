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

  // Hottest of CPU/GPU so the bar label flames red as the system heats up.
  function hottestTemp() {
    var cpu = Number(root.cpuTemp)
    var gpu = Number(root.gpuTemp)
    var c = isNaN(cpu) ? -Infinity : cpu
    var g = isNaN(gpu) ? -Infinity : gpu
    return Math.max(c, g)
  }

  // Temperature tint shared with the panel: yellow 50–70 °C, red above.
  function tempColor(temp) {
    var normal = root.bar ? root.bar.barForeground : Color.foreground
    if (typeof temp !== "number" || temp === -Infinity) return normal
    if (temp >= 70) return Qt.red
    if (temp >= 50) return Qt.yellow
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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "CPU " + root.cpuTemp + "°  GPU " + root.gpuTemp + "°"
    foreground: root.tempColor(root.hottestTemp())
    tooltipText: "Open Thermals"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
