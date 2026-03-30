import WidgetKit
import SwiftUI
import ProdNoteShared

// MARK: - ProdNoteWidgetBundle
// Entry point for the Widget Extension target.
// Issue #78 — https://github.com/pnsw123/prod-note/issues/78
// REQUIRES: Widget Extension target created manually per issue #77

@main
struct ProdNoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProdNoteWidget()
        ProdNoteWidgetAccessory()
    }
}
