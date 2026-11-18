import QtQuick

Rectangle {
	id: root

	property alias text:		label.text
	property alias iconColor:	label.color
	property alias fontFamily:	label.font.family

	implicitHeight:		label.font.pixelSize + 20
	implicitWidth:		Math.max(implicitHeight, label.implicitWidth + 20)
	radius:				15

	color:				Qt.rgba(20/255, 20/255, 50/255, 1)

	Text {
		id:					label
		anchors.centerIn:	parent
		font.pixelSize: 	15
		font.bold:			true
	}
}
