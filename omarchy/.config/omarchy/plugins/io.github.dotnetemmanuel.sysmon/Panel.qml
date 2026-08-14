import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "io.github.dotnetemmanuel.sysmon"
  ipcTarget: "io.github.dotnetemmanuel.sysmon"

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string statsCommand: (Quickshell.env("HOME") || "")
    + "/.config/omarchy/plugins/io.github.dotnetemmanuel.sysmon/stats.sh"

  property var stats: ({})

  readonly property real hotTemp: 85
  readonly property real cpu: root.reading("cpu")
  readonly property real cpuTemp: root.reading("cpuTemp")
  readonly property real gpuTemp: root.reading("gpuTemp")
  readonly property bool hot: (!isNaN(cpuTemp) && cpuTemp >= hotTemp) || (!isNaN(gpuTemp) && gpuTemp >= hotTemp)
  readonly property string barText: root.degrees(root.cpuTemp)

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function reading(key) {
    var v = stats ? stats[key] : null
    if (v === null || v === undefined) return NaN
    var n = Number(v)
    return isFinite(n) ? n : NaN
  }

  function percent(v) {
    return isNaN(v) ? "--" : Math.round(v) + "%"
  }

  function degrees(v) {
    return isNaN(v) ? "--" : Math.round(v) + "°C"
  }

  function rpm(v) {
    if (isNaN(v)) return "--"
    return v <= 0 ? "stopped" : Math.round(v) + " rpm"
  }

  function gibFromKb(kb) {
    return isNaN(kb) ? NaN : kb / 1048576
  }

  function gibFromBytes(bytes) {
    return isNaN(bytes) ? NaN : bytes / 1073741824
  }

  function pair(used, total) {
    if (isNaN(used) || isNaN(total) || total <= 0) return "--"
    return used.toFixed(1) + " / " + total.toFixed(1) + " GB"
  }

  function tempColor(v) {
    return (!isNaN(v) && v >= root.hotTemp) ? root.urgent : root.foreground
  }

  function heroMeta() {
    if (root.hot) return "RUNNING HOT"
    if (isNaN(root.cpu)) return "READING"
    if (root.cpu >= 60) return "UNDER LOAD"
    return "IDLING"
  }

  function heroDetail() {
    var mem = root.pair(root.gibFromKb(root.reading("memUsedKb")), root.gibFromKb(root.reading("memTotalKb")))
    return root.percent(root.cpu) + "  ·  " + mem
  }

  function refresh() {
    if (statsProcess.running) return
    statsProcess.running = true
  }

  function parseStats(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (parsed && typeof parsed === "object") stats = parsed
    } catch (e) {
      console.warn(root.moduleName + ": invalid stats output", e)
    }
  }

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: statsProcess
    command: [root.statsCommand]
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStats(text)
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn(root.moduleName + ": stats command exited", exitCode)
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    active: root.hot
    activeColor: root.urgent
    fontSize: Style.bar.iconFont
    horizontalMargin: 3.5
    tooltipText: ""

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh() }

      Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "System"
          meta: root.heroMeta()
          detail: root.heroDetail()
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            Text {
              text: "󰻠"
              color: root.hot ? root.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          PanelSectionHeader {
            text: "󰻠  PROCESSOR"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          GridLayout {
            width: parent.width
            columns: 4
            columnSpacing: Style.space(20)
            rowSpacing: Style.spacing.labelGap

            InfoLabel { text: "Load" }
            InfoValue { text: root.percent(root.cpu) }
            InfoLabel { text: "Memory" }
            InfoValue {
              text: root.pair(root.gibFromKb(root.reading("memUsedKb")),
                              root.gibFromKb(root.reading("memTotalKb")))
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          PanelSectionHeader {
            text: "󰢮  GRAPHICS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          GridLayout {
            width: parent.width
            columns: 4
            columnSpacing: Style.space(20)
            rowSpacing: Style.spacing.labelGap

            InfoLabel { text: "Busy" }
            InfoValue { text: root.percent(root.reading("gpuBusy")) }
            InfoLabel { text: "Video memory" }
            InfoValue {
              text: root.pair(root.gibFromBytes(root.reading("vramUsed")),
                              root.gibFromBytes(root.reading("vramTotal")))
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          PanelSectionHeader {
            text: "󰔏  TEMPERATURES"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          GridLayout {
            width: parent.width
            columns: 4
            columnSpacing: Style.space(20)
            rowSpacing: Style.spacing.labelGap

            InfoLabel { text: "Processor" }
            InfoValue {
              text: root.degrees(root.cpuTemp)
              color: root.tempColor(root.cpuTemp)
            }
            InfoLabel { text: "Graphics" }
            InfoValue {
              text: root.degrees(root.gpuTemp)
              color: root.tempColor(root.gpuTemp)
            }

            InfoLabel { text: "Disk" }
            InfoValue {
              text: root.degrees(root.reading("diskTemp"))
              color: root.tempColor(root.reading("diskTemp"))
            }
            InfoLabel { text: "Fan" }
            InfoValue { text: root.rpm(root.reading("fanRpm")) }
          }
        }
      }
    }
  }

  component InfoLabel: Text {
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignRight
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
