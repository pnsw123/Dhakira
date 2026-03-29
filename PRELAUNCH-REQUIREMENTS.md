# Pre-Launch Requirements

---

## 1. Apple Developer Program
- [ ] Enroll at developer.apple.com/programs/enroll ($99/year)
- [ ] Required for iCloud, CloudKit, and App Store publishing

## 2. iCloud / CloudKit Setup
- [ ] Xcode → Note-taking target → Signing & Capabilities → add iCloud
- [ ] Check the CloudKit checkbox
- [ ] Commit the auto-generated Note-taking.entitlements file

---

## 3. App Identity
- [ ] Design and finalize app logo (1024x1024 px)
- [ ] Add all required icon sizes in Xcode Assets catalog
- [ ] Choose final app name (confirm "Note-taking" or rename)
- [ ] Write App Store description and keywords

## 4. App Store Screenshots
- [ ] Screenshot: Home / Folders screen
- [ ] Screenshot: Task list view
- [ ] Screenshot: Note editor with formatting toolbar
- [ ] Screenshot: Slash command `/` menu open
- [ ] Screenshot: Calendar event created from a note
- [ ] Minimum: 3 screenshots per device size (iPhone 6.9", 6.5")

---

## 5. Simulator Testing Checklist
Run through every feature manually on the simulator before submitting.

### Core Note Features
- [ ] Create a new task / note
- [ ] Type in the editor — text appears correctly
- [ ] Bold, italic, underline, strikethrough formatting works
- [ ] Heading 1, 2, 3 apply and revert correctly
- [ ] Bullet list inserts and toggles off
- [ ] Quote block inserts with blue bar and toggles off
- [ ] Checklist inserts and checkbox toggles checked/unchecked
- [ ] Slash `/` menu appears, filters, and applies command correctly
- [ ] Slash menu dismisses on backspace
- [ ] Drag-to-reorder toolbar icons works

### Folders & Navigation
- [ ] Create a new folder
- [ ] Rename a folder inline
- [ ] Delete a folder
- [ ] Navigate Tasks → Folders → Tasks smoothly
- [ ] Select a task list from a folder and it becomes active

### Calendar & Date Detection
- [ ] Type a date in a note title (e.g. "Dentist tomorrow at 3pm")
- [ ] App detects the date automatically
- [ ] Calendar event is created in Apple Calendar
- [ ] Event has correct title, date, and time
- [ ] Event has 15-minute reminder alarm
- [ ] Edit the date in the title — event updates
- [ ] Remove the date from the title — event is deleted
- [ ] Deep link in calendar event opens the app at the correct note

### Export
- [ ] PDF export: tap export → share sheet appears with .pdf file
- [ ] PDF file opens correctly and contains title + body content
- [ ] Word/RTF export: share sheet appears with .rtf file
- [ ] RTF file opens in Pages or Word correctly
- [ ] Plain text share works

### Attachments
- [ ] Attach a photo from photo library
- [ ] Attach a file (PDF, doc, etc.)
- [ ] Record and attach a voice message
- [ ] Scan a document with camera (text scan)
- [ ] Attached items appear inline in the note

### Reminders Import
- [ ] Grant Reminders permission
- [ ] Import from Apple Reminders works
- [ ] Imported reminder becomes a task with correct title and notes

### Sync & Data
- [ ] Close and reopen app — all notes are still there
- [ ] iCloud sync: notes appear on a second device (requires Developer account)
- [ ] Recently Completed shows completed tasks
- [ ] Recently Deleted shows soft-deleted tasks
- [ ] Restore a deleted task works
- [ ] Permanently delete a task works

### Deep Links & Siri
- [ ] Siri shortcut "Create Task" works
- [ ] Deep link URL (prodnote://task/{uuid}) opens correct note

### Polish
- [ ] App looks correct in Light Mode
- [ ] App looks correct in Dark Mode
- [ ] No visible layout breaks on iPhone 16 Pro Max
- [ ] No visible layout breaks on iPhone SE (small screen)
- [ ] App does not crash on cold launch

---

## 6. Final Submission
- [ ] Set correct Bundle ID in Xcode
- [ ] Set version number (1.0.0) and build number (1)
- [ ] Archive the app (Product → Archive)
- [ ] Upload to App Store Connect via Xcode Organizer
- [ ] Fill in App Store Connect listing (description, category, age rating)
- [ ] Submit for Apple Review
