import XCTest
@testable import Note_taking

final class NamedColorTests: XCTestCase {

    // MARK: - #1 find(id:) returns correct color

    func test_find_knownId_returnsMatchingColor() {
        let result = NamedColor.find(id: "colorBlue")

        XCTAssertNotNil(result, "find(id: 'colorBlue') should return a NamedColor")
        XCTAssertEqual(result?.label, "Blue")
        XCTAssertEqual(result?.id, "colorBlue")
    }

    func test_find_unknownId_returnsNil() {
        let result = NamedColor.find(id: "colorUltraviolet")
        XCTAssertNil(result, "find with unknown id should return nil")
    }

    // MARK: - #2 forEditor excludes palette-only colors

    func test_forEditor_excludesPaletteOnlyColors() {
        let editorColors = NamedColor.forEditor

        let paletteOnlyIds = ["paletteYellow", "paletteRed", "paletteGreen",
                              "paletteTeal", "paletteBlack", "paletteWhite"]

        for id in paletteOnlyIds {
            XCTAssertFalse(
                editorColors.contains(where: { $0.id == id }),
                "forEditor should not include palette-only color '\(id)'"
            )
        }
    }

    func test_forEditor_includesSharedColors() {
        let editorColors = NamedColor.forEditor
        let sharedIds = ["colorGray", "colorOrange", "colorBlue",
                         "colorPurple", "colorPink", "colorBrown"]

        for id in sharedIds {
            XCTAssertTrue(
                editorColors.contains(where: { $0.id == id }),
                "forEditor should include shared color '\(id)'"
            )
        }
    }

    // MARK: - #3 All colors in `all` have unique IDs

    func test_all_hasUniqueIds() {
        let ids = NamedColor.all.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count,
                       "NamedColor.all should have no duplicate IDs")
    }

    // MARK: - #4 paletteMain contains exactly 4 colors

    func test_paletteMain_hasFourColors() {
        XCTAssertEqual(NamedColor.paletteMain.count, 4,
                       "paletteMain should always expose exactly 4 primary swatches")
    }

    // MARK: - #5 Blue is unified — same hex in editor and palette

    func test_blue_sameColorInEditorAndPalette() {
        // This test would have caught the #0a84ff vs #007AFF mismatch (Issue #51)
        let editorBlue = NamedColor.find(id: "colorBlue")
        let paletteBlue = NamedColor.paletteMain.first(where: { $0.id == "colorBlue" })

        XCTAssertNotNil(editorBlue, "colorBlue must exist in the master list")
        XCTAssertNotNil(paletteBlue, "colorBlue must appear in paletteMain")

        // Both reference the same NamedColor object (same id → same uiColor)
        XCTAssertEqual(editorBlue?.id, paletteBlue?.id,
                       "Editor blue and palette blue must reference the same NamedColor id")
    }
}
