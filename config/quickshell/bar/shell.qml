import QtQuick
import Quickshell
import Quickshell.Hyprland

PanelWindow {
	implicitHeight: 50
	color: "transparent"

	margins {
		top:	10
		left:	10
		right:	10
	}

	anchors {
		top:	true
		left:	true
		right:	true
	}

	Rectangle {
		anchors.fill:	parent

		border.color:	Qt.rgba(15/255, 15/255, 30/255, 0.8)
		border.width:	3
		radius:			20

		color:			Qt.rgba(35/255, 35/255, 61/255, 0.85)
	}


	//Left modules
	Row {
		anchors.left:			parent.left
		anchors.verticalCenter:	parent.verticalCenter
		anchors.leftMargin:		20
		spacing:				20

		Repeater {
			model: Math.max(3, ...Hyprland.workspaces.values
								.filter(w => w.id > 0)
								.map(w => w.id))

			Text {
				required property int	index
				readonly property int	wsId:		index + 1
				readonly property bool	isActive:	Hyprland.focusedWorkspace?.id === wsId

				font.pixelSize: 20
				color:			"white"
				font.family:	"MesloLGM Nerd Font Propo"
				text:			isActive ? "" : ""
			}
		}
	}

	//Middle module
	Module {
		anchors.centerIn:       parent

		SystemClock { id: clock; precision: SystemClock.Minutes }

		text:					Qt.formatDateTime(clock.date, "hh:mm")
		iconColor:				Qt.rgba(5/255, 220/255, 220/255, 1)
		fontFamily:				"Monocraft"
	}

	//Right modules
	Row {
		anchors.right:			parent.right
		anchors.verticalCenter:	parent.verticalCenter
		anchors.rightMargin:	10

		spacing:				10
		layoutDirection:		Qt.RightToLeft

		Module { text:	"☰";	iconColor: "white" }
		Module { text:	"";	iconColor: Qt.rgba(57/255, 1, 20/255, 1);			fontFamily: "MesloLGM Nerd Font Propo" }
		Module { text:	"";	iconColor: Qt.rgba(150/255, 100/255, 190/255, 1);	fontFamily: "MesloLGM Nerd Font Propo" }
	}
}
