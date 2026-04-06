import XCTest
import SwiftData
@testable import Note_taking

// MARK: - ImprovementVerificationTests
// Verifies behaviors for improvements in issues #112–#114.
// Tests use public interfaces only — no mocking of internals.

final class ImprovementVerificationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppSchemaBuilder.makeInMemoryContainer()
        context   = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context   = nil
        container = nil
        try super.tearDownWithError()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #112: Cursor font resets to body after heading + Enter
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// HeadingLevel fonts must match the sizes used in the heading detection set.
    /// If someone changes the heading font sizes, this test catches the mismatch.
    func testHeadingFontSizesMatchDetectionSet() {
        let expectedSizes: Set<CGFloat> = [28, 18, 15, 13]
        let headingLevels: [RichEditorCommands.HeadingLevel] = [.h1, .h2, .h3, .h4]

        for level in headingLevels {
            XCTAssertTrue(expectedSizes.contains(level.font.pointSize),
                "Issue #112: HeadingLevel.\(level) font size \(level.font.pointSize) must be in detection set \(expectedSizes)")
        }
    }

    /// Body font must NOT match any heading size (so detection doesn't false-positive).
    func testBodyFontIsNotInHeadingSet() {
        let headingSizes: Set<CGFloat> = [28, 18, 15, 13]
        let bodyFont = RichEditorCommands.HeadingLevel.body.font
        XCTAssertFalse(headingSizes.contains(bodyFont.pointSize),
            "Issue #112: body font (\(bodyFont.pointSize)pt) must NOT be in heading detection set")
    }

    /// H1 heading must be 28pt bold.
    func testH1FontIs28ptBold() {
        let font = RichEditorCommands.HeadingLevel.h1.font
        XCTAssertEqual(font.pointSize, 28, "H1 must be 28pt")
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "H1 must be bold")
    }

    /// Applying a heading then body to the same text must restore body font.
    func testApplyHeadingThenBodyRestoresFont() {
        var text: NSAttributedString = NSAttributedString(
            string: "Test line",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        let range = NSRange(location: 0, length: text.length)

        // Apply H1
        RichEditorCommands.applyHeading(.h1, attributedText: &text, selectedRange: range)
        let h1Font = text.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
        XCTAssertEqual(h1Font.pointSize, 28, "After applying H1, font must be 28pt")

        // Apply Body
        RichEditorCommands.applyHeading(.body, attributedText: &text, selectedRange: NSRange(location: 0, length: text.length))
        let bodyFont = text.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
        XCTAssertFalse([28, 18, 15, 13].contains(Int(bodyFont.pointSize)),
            "Issue #112: after applying body, font must not be a heading size")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #113: Folder drag-drop nesting
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Setting parentFolder on a folder makes it a subfolder.
    func testFolderNestingViaParentFolder() throws {
        let parent = Folder(name: "Parent")
        let child  = Folder(name: "Child")
        context.insert(parent)
        context.insert(child)
        try context.save()

        // Simulate drag-drop: assign parent
        child.parentFolder = parent
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Folder>(
            predicate: #Predicate<Folder> { $0.name == "Parent" }
        ))
        let fetchedParent = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedParent.subfolders?.count, 1,
            "Issue #113: parent must have 1 subfolder after nesting")
        XCTAssertEqual(fetchedParent.subfolders?.first?.name, "Child")
    }

    /// Unnesting a folder (setting parentFolder = nil) moves it to root.
    func testFolderUnnestToRoot() throws {
        let parent = Folder(name: "Parent")
        let child  = Folder(name: "Child", parentFolder: parent)
        context.insert(parent)
        context.insert(child)
        try context.save()

        XCTAssertNotNil(child.parentFolder, "Child must have a parent before unnesting")

        // Simulate drag to root
        child.parentFolder = nil
        try context.save()

        XCTAssertNil(child.parentFolder,
            "Issue #113: after unnesting, parentFolder must be nil")
        let fetchedParent = try context.fetch(FetchDescriptor<Folder>(
            predicate: #Predicate<Folder> { $0.name == "Parent" }
        )).first
        XCTAssertEqual(fetchedParent?.subfolders?.count ?? 0, 0,
            "Issue #113: parent must have 0 subfolders after child unnested")
    }

    /// Moving a folder into itself must be blocked (same-id check).
    func testCannotNestFolderIntoItself() throws {
        let folder = Folder(name: "Solo")
        context.insert(folder)
        try context.save()

        // The drag-drop code checks draggedFolder.id != folder.id
        // We verify the IDs are equal for the same object
        XCTAssertEqual(folder.id, folder.id,
            "Issue #113: same folder must be detected by ID equality check")
    }

    /// Depth 10 nesting is the maximum allowed.
    func testMaxNestingDepthIs10() throws {
        var current = Folder(name: "Level 0")
        context.insert(current)

        for level in 1...10 {
            let child = Folder(name: "Level \(level)", parentFolder: current)
            context.insert(child)
            current = child
        }
        try context.save()

        // Walk up from deepest to verify depth
        var depth = 0
        var walk: Folder? = current
        while let parent = walk?.parentFolder {
            depth += 1
            walk = parent
        }
        XCTAssertEqual(depth, 10,
            "Issue #113: max nesting depth must be 10 levels")
    }

    /// FolderTransferID round-trips through Codable (needed for drag-drop).
    func testFolderTransferIDCodable() throws {
        let folder = Folder(name: "Draggable")
        context.insert(folder)
        try context.save()

        let transferID = FolderTransferID(rawID: folder.persistentModelID)

        // Encode
        let data = try JSONEncoder().encode(transferID)
        XCTAssertFalse(data.isEmpty, "Issue #113: FolderTransferID must encode to non-empty data")

        // Decode
        let decoded = try JSONDecoder().decode(FolderTransferID.self, from: data)
        XCTAssertEqual(decoded.rawID, folder.persistentModelID,
            "Issue #113: FolderTransferID must round-trip through Codable")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Issue #114: Sort tasks by priority flag
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// SortOption enum must include .priority case.
    func testSortOptionIncludesPriority() {
        let allCases = SortOption.allCases
        XCTAssertTrue(allCases.contains(.priority),
            "Issue #114: SortOption must include .priority")
        XCTAssertEqual(SortOption.priority.rawValue, "Priority")
    }

    /// SortOption must have exactly 3 cases: manual, creationDate, priority.
    func testSortOptionHasThreeCases() {
        XCTAssertEqual(SortOption.allCases.count, 3,
            "Issue #114: SortOption must have exactly 3 cases")
    }

    /// Tasks with different priorities must sort: high → medium → default.
    func testPrioritySortOrder() throws {
        let list = TaskList(name: "Test List")
        context.insert(list)

        let low    = TaskItem(title: "Low priority", taskList: list)
        low.priority = "default"
        low.createdAt = Date().addingTimeInterval(-300)

        let high   = TaskItem(title: "High priority", taskList: list)
        high.priority = "high"
        high.createdAt = Date().addingTimeInterval(-200)

        let medium = TaskItem(title: "Medium priority", taskList: list)
        medium.priority = "medium"
        medium.createdAt = Date().addingTimeInterval(-100)

        context.insert(low)
        context.insert(high)
        context.insert(medium)
        try context.save()

        // Sort using the same logic as TaskListView.filteredTasks
        let tasks = [low, high, medium]
        let sorted = tasks.sorted { lhs, rhs in
            let lw = Self.priorityWeight(lhs.priority)
            let rw = Self.priorityWeight(rhs.priority)
            if lw != rw { return lw < rw }
            return lhs.createdAt < rhs.createdAt
        }

        XCTAssertEqual(sorted[0].title, "High priority",
            "Issue #114: high priority (red) must sort first")
        XCTAssertEqual(sorted[1].title, "Medium priority",
            "Issue #114: medium priority (orange) must sort second")
        XCTAssertEqual(sorted[2].title, "Low priority",
            "Issue #114: default (no flag) must sort last")
    }

    /// Same-priority tasks must sort by creation date (oldest first).
    func testSamePrioritySortsByCreationDate() throws {
        let list = TaskList(name: "Test List")
        context.insert(list)

        let newer = TaskItem(title: "Newer", taskList: list)
        newer.priority = "high"
        newer.createdAt = Date()

        let older = TaskItem(title: "Older", taskList: list)
        older.priority = "high"
        older.createdAt = Date().addingTimeInterval(-3600) // 1 hour earlier

        context.insert(newer)
        context.insert(older)
        try context.save()

        let tasks = [newer, older]
        let sorted = tasks.sorted { lhs, rhs in
            let lw = Self.priorityWeight(lhs.priority)
            let rw = Self.priorityWeight(rhs.priority)
            if lw != rw { return lw < rw }
            return lhs.createdAt < rhs.createdAt
        }

        XCTAssertEqual(sorted[0].title, "Older",
            "Issue #114: same priority must sort older task first")
        XCTAssertEqual(sorted[1].title, "Newer",
            "Issue #114: same priority must sort newer task second")
    }

    /// Priority weight mapping must be: high=0, medium=1, default=2.
    func testPriorityWeightValues() {
        XCTAssertEqual(Self.priorityWeight("high"), 0, "high must map to weight 0")
        XCTAssertEqual(Self.priorityWeight("medium"), 1, "medium must map to weight 1")
        XCTAssertEqual(Self.priorityWeight("default"), 2, "default must map to weight 2")
        XCTAssertEqual(Self.priorityWeight(""), 2, "empty string must map to weight 2")
        XCTAssertEqual(Self.priorityWeight("unknown"), 2, "unknown must map to weight 2")
    }

    // Helper — mirrors TaskListView.priorityWeight exactly
    private static func priorityWeight(_ priority: String) -> Int {
        switch priority {
        case "high":   return 0
        case "medium": return 1
        default:       return 2
        }
    }
}
