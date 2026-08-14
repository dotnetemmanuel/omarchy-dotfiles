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
  property int hoveredCore: -1

  readonly property real hotTemp: 85
  readonly property real busyCore: 85
  readonly property real cpu: root.reading("cpu")
  readonly property real cpuTemp: root.reading("cpuTemp")
  readonly property real gpuTemp: root.reading("gpuTemp")
  readonly property var cores: (stats && Array.isArray(stats.cores)) ? stats.cores : []
  readonly property var processes: (stats && Array.isArray(stats.processes)) ? stats.processes : []
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

  function hoveredCoreLabel() {
    if (hoveredCore < 0 || hoveredCore >= cores.length) return cores.length + " threads"
    var v = cores[hoveredCore]
    var shown = (v === null || v === undefined) ? "--" : Math.round(root.coreLoad(v)) + "%"
    return "Thread " + hoveredCore + "  ·  " + shown
  }

  function coreLoad(value) {
    if (value === null || value === undefined) return 0
    var n = Number(value)
    return isFinite(n) ? Math.max(0, Math.min(100, n)) : 0
  }

  function processLabel(entry) {
    if (!entry) return "?"
    var name = String(entry.name || "?")
    var where = String(entry.where || "")
    return where === "" ? name : name + " · " + where
  }

  function processShare(value) {
    var n = Number(value)
    if (!isFinite(n)) return "--"
    return (n >= 100 ? n.toFixed(0) : n.toFixed(1)) + "%"
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
    // A poll cut short by plugin reload or shell shutdown finishes its stream
    // with nothing in it, which is not worth a warning.
    var text = String(raw || "").trim()
    if (text === "") return

    try {
      var parsed = JSON.parse(text)
      if (parsed && typeof parsed === "object") stats = parsed
    } catch (e) {
      console.warn(root.moduleName + ": invalid stats output", e)
    }
  }

  onOpenedChanged: if (opened) {
    refresh()
    statsFlick.contentY = 0
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) {
          statsFlick.contentY = Math.max(0, Math.min(
            statsFlick.contentY + dy * Style.space(48),
            Math.max(0, statsFlick.contentHeight - statsFlick.height)
          ))
        }
      }
      onActivateRequested: Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh() }

      Flickable {
        id: statsFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          // Held clear of the scroll bar: it overlays the right edge and eats
          // hover events, which cost the last core bar its readout.
          width: statsFlick.width - Style.space(12)
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

            Item { width: 1; height: Style.space(4) }

            Item {
              id: coreStrip
              width: parent.width
              height: Style.space(28)

              Row {
                id: coreRow
                anchors.fill: parent
                spacing: Style.space(2)

                readonly property int slots: root.cores.length

                Repeater {
                  model: root.cores

                  Rectangle {
                    id: coreBar
                    readonly property real load: root.coreLoad(modelData)
                    readonly property bool hovered: root.hoveredCore === index

                    width: coreRow.slots > 0
                      ? (coreRow.width - coreRow.spacing * (coreRow.slots - 1)) / coreRow.slots
                      : 0
                    height: parent.height
                    radius: Style.space(2)
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                                   coreBar.hovered ? 0.2 : 0.09)

                    Rectangle {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.bottom: parent.bottom
                      height: parent.height * coreBar.load / 100
                      radius: parent.radius
                      color: coreBar.load >= root.busyCore ? root.urgent : root.foreground
                      opacity: 0.85
                    }
                  }
                }
              }

              // One hit area for the whole strip. A mouse area per bar flickers
              // in the sub-pixel gaps between them, worst at the far right where
              // the rounding has accumulated.
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                function pick(x) {
                  var n = coreRow.slots
                  if (n <= 0 || width <= 0) return -1
                  return Math.max(0, Math.min(n - 1, Math.floor(x / (width / n))))
                }

                onPositionChanged: function(mouse) { root.hoveredCore = pick(mouse.x) }
                onEntered: root.hoveredCore = pick(mouseX)
                onExited: root.hoveredCore = -1
              }
            }

            Text {
              width: parent.width
              visible: coreRow.slots > 0
              text: root.hoveredCoreLabel()
              color: root.hoveredCore >= 0 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader {
              text: "󰓅  HEAVIEST PROCESSES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              visible: root.processes.length === 0
              text: "Measuring"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              model: root.processes

              Item {
                width: parent ? parent.width : 0
                implicitHeight: Math.max(procName.implicitHeight, procShare.implicitHeight)

                Text {
                  id: procName
                  anchors.left: parent.left
                  anchors.right: procShare.left
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.processLabel(modelData)
                  color: root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }

                Text {
                  id: procShare
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.processShare(modelData.pct)
                  color: Number(modelData.pct) >= 100 ? root.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            Text {
              width: parent.width
              visible: root.processes.length > 0
              text: "100% is one thread fully used"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
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
