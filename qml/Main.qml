import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./components"
import "./theme"

ApplicationWindow {
    id: root

    visible: true
    width: 1500
    height: 920
    minimumWidth: 1150
    minimumHeight: 700

    title: "StoreLens"
    color: Theme.background

    property int currentPage: 0

    readonly property var pageNames: [
        "Dashboard",
        "Compare & Validate",
        "Record Repair",
        "Single File Review",
        "Create Store",
        "Explore / Data",
        "Health"
    ]

    readonly property var pageIds: [
        "home",
        "compare",
        "repair",
        "review",
        "create",
        "explore",
        "health"
    ]

    function navigateTo(pageId) {
        var index = pageIds.indexOf(pageId)

        if (index >= 0)
            currentPage = index
    }

    function navigateToIndex(index) {
        if (index >= 0 && index < pageIds.length)
            currentPage = index
    }

    Component.onCompleted: {
        currentPage = 0
    }

    // =========================================================
    // GLOBAL BACKEND NOTIFICATIONS
    // =========================================================

    Connections {
        target: typeof backend !== "undefined" ? backend : null
        ignoreUnknownSignals: true

        function onNotifySignal(title, message, level) {
            var prefix = String(title || "").trim()
            var body = String(message || "").trim()

            if (prefix !== "" && body !== "")
                toast.show(prefix + ": " + body, level)
            else if (body !== "")
                toast.show(body, level)
            else if (prefix !== "")
                toast.show(prefix, level)
        }

        function onSaySignal(message) {
            var text = String(message || "").trim()

            if (text !== "")
                toast.show(text, "info")
        }
    }

    // =========================================================
    // ROOT LAYOUT
    // =========================================================

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================
        // SIDEBAR
        // =====================================================

        Rectangle {
            id: sidebar

            Layout.fillHeight: true
            Layout.preferredWidth: Theme.sidebarWidth

            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingMedium

                // -------------------------------------------------
                // BRAND
                // -------------------------------------------------

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: "StoreLens"
                            color: Theme.textPrimary
                            font.pixelSize: 22
                            font.bold: true
                        }

                        Text {
                            text: "Data Intelligence"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                // -------------------------------------------------
                // NAVIGATION
                // -------------------------------------------------

                Text {
                    text: "WORKSPACE"
                    color: Theme.textMuted
                    font.pixelSize: 10
                    font.bold: true
                    Layout.leftMargin: Theme.spacingSmall
                    Layout.topMargin: Theme.spacingSmall
                }

                SidebarButton {
                    text: "Dashboard"
                    isActive: root.currentPage === 0

                    onClicked: {
                        root.navigateToIndex(0)
                    }
                }

                SidebarButton {
                    text: "Compare & Validate"
                    isActive: root.currentPage === 1

                    onClicked: {
                        root.navigateToIndex(1)
                    }
                }

                SidebarButton {
                    text: "Record Repair"
                    isActive: root.currentPage === 2

                    onClicked: {
                        root.navigateToIndex(2)
                    }
                }

                SidebarButton {
                    text: "Single File Review"
                    isActive: root.currentPage === 3

                    onClicked: {
                        root.navigateToIndex(3)
                    }
                }

                SidebarButton {
                    text: "Create Store"
                    isActive: root.currentPage === 4

                    onClicked: {
                        root.navigateToIndex(4)
                    }
                }

                SidebarButton {
                    text: "Explore / Data"
                    isActive: root.currentPage === 5

                    onClicked: {
                        root.navigateToIndex(5)
                    }
                }

                SidebarButton {
                    text: "Health"
                    isActive: root.currentPage === 6

                    onClicked: {
                        root.navigateToIndex(6)
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                // -------------------------------------------------
                // FOOTER
                // -------------------------------------------------

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "StoreLens"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Data processing workspace"
                        color: Theme.textMuted
                        font.pixelSize: 10
                    }
                }
            }
        }

        // =====================================================
        // MAIN CONTENT
        // =====================================================

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            color: Theme.background

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // -------------------------------------------------
                // TOP HEADER
                // -------------------------------------------------

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.headerHeight

                    color: Theme.background
                    border.color: Theme.border
                    border.width: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingLarge
                        anchors.rightMargin: Theme.spacingLarge
                        spacing: Theme.spacingMedium

                        Text {
                            text: root.pageNames[root.currentPage]
                            color: Theme.textPrimary
                            font.pixelSize: 17
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.success
                        }

                        Text {
                            text: "Ready"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                // -------------------------------------------------
                // PAGE HOST
                // -------------------------------------------------

                StackLayout {
                    id: pageStack

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    currentIndex: root.currentPage

                    // =============================================
                    // 0. HOME
                    // =============================================

                    Loader {
                        active: root.currentPage === 0
                        source: "pages/HomePage.qml"

                        onLoaded: {
                            if (item && item.navigateRequested) {
                                item.navigateRequested.connect(
                                    root.navigateTo
                                )
                            }
                        }
                    }

                    // =============================================
                    // 1. COMPARE
                    // =============================================

                    Loader {
                        active: root.currentPage === 1
                        source: "pages/ComparePage.qml"
                    }

                    // =============================================
                    // 2. REPAIR
                    // =============================================

                    Loader {
                        active: root.currentPage === 2
                        source: "pages/RepairPage.qml"
                    }

                    // =============================================
                    // 3. REVIEW
                    // =============================================

                    Loader {
                        active: root.currentPage === 3
                        source: "pages/SingleReviewPage.qml"
                    }

                    // =============================================
                    // 4. CREATE STORE
                    // =============================================

                    Loader {
                        active: root.currentPage === 4
                        source: "pages/CreateStorePage.qml"
                    }

                    // =============================================
                    // 5. EXPLORE
                    // =============================================

                    Loader {
                        active: root.currentPage === 5
                        source: "pages/ExplorePage.qml"
                    }

                    // =============================================
                    // 6. HEALTH
                    // =============================================

                    Loader {
                        active: root.currentPage === 6
                        source: "pages/HealthPage.qml"
                    }
                }
            }
        }
    }

    // =========================================================
    // GLOBAL TOAST
    // =========================================================

    Toast {
        id: toast

        z: 1000

        anchors.right: parent.right
        anchors.bottom: parent.bottom

        anchors.rightMargin: Theme.spacingLarge
        anchors.bottomMargin: Theme.spacingLarge
    }
}
