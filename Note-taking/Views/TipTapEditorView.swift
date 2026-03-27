import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit

/// WKWebView subclass that hides the default keyboard accessory bar
/// (the ^  v  Done row that WKWebView adds above the keyboard)
final class NoAccessoryWebView: WKWebView {
    override var inputAccessoryView: UIView? { nil }
}

struct TipTapEditorView: UIViewRepresentable {
    /// Always reflects the latest HTML from TipTap (updated on every keystroke)
    @Binding var html: String
    /// Called once when the WKWebView is ready — parent stores it for JS commands & export
    var onWebViewReady: ((WKWebView) -> Void)?

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: TipTapEditorView
        var webView: NoAccessoryWebView?
        private var isLoaded = false
        private var initialContentSet = false

        init(_ parent: TipTapEditorView) {
            self.parent = parent
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "contentChanged":
                if let html = message.body as? String {
                    DispatchQueue.main.async { self.parent.html = html }
                }
            case "editorReady":
                isLoaded = true
                if !initialContentSet {
                    setInitialContent()
                }
            default:
                break
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // editorReady message fires from JS once TipTap initialises
        }

        // MARK: Helpers

        func setInitialContent() {
            guard let webView, isLoaded, !initialContentSet else { return }
            initialContentSet = true
            let html = parent.html
            guard !html.isEmpty else { return }
            if let data = try? JSONEncoder().encode(html),
               let json = String(data: data, encoding: .utf8) {
                webView.evaluateJavaScript("setContent(\(json))") { _, _ in }
            }
        }

        func flushContent(completion: @escaping (String) -> Void) {
            webView?.evaluateJavaScript("getContent()") { result, _ in
                completion((result as? String) ?? self.parent.html)
            }
        }
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> NoAccessoryWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "contentChanged")
        controller.add(context.coordinator, name: "editorReady")

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = NoAccessoryWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.webView = webView

        // Load embedded HTML — no Xcode bundle config required.
        // baseURL must be nil so ESM imports from esm.sh resolve correctly.
        webView.loadHTMLString(Self.editorHTML, baseURL: nil)

        DispatchQueue.main.async {
            self.onWebViewReady?(webView)
        }

        return webView
    }

    func updateUIView(_ webView: NoAccessoryWebView, context: Context) {
        context.coordinator.setInitialContent()
    }

    // MARK: - Embedded editor HTML
    // Inlined so no Xcode bundle target setup is required.
    // TipTap loads from esm.sh CDN — requires network on first load.
    static let editorHTML = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        html, body { height: 100%; background: transparent; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
          font-size: 16px;
          color: #1c1c1e;
          padding: 12px 0;
          -webkit-text-size-adjust: none;
        }
        .ProseMirror { outline: none; min-height: 200px; line-height: 1.65; padding: 0 4px; }
        .ProseMirror > * + * { margin-top: 8px; }
        .ProseMirror p { margin: 0; }
        .ProseMirror h1 { font-size: 20px; font-weight: 700; }
        .ProseMirror h2 { font-size: 17px; font-weight: 600; }
        .ProseMirror h3 { font-size: 15px; font-weight: 600; }
        .ProseMirror ul, .ProseMirror ol { padding-left: 22px; }
        .ProseMirror li { margin-top: 2px; }
        ul[data-type="taskList"] { list-style: none; padding: 0; }
        ul[data-type="taskList"] li { display: flex; align-items: flex-start; gap: 8px; }
        ul[data-type="taskList"] li > label { flex-shrink: 0; margin-top: 2px; }
        ul[data-type="taskList"] li > div { flex: 1; }
        ul[data-type="taskList"] li[data-checked="true"] > div { text-decoration: line-through; color: #8e8e93; }
        .ProseMirror blockquote { border-left: 3px solid #c7c7cc; padding-left: 14px; color: #6c6c70; }
        .ProseMirror code { background: #f2f2f7; padding: 2px 5px; border-radius: 4px; font-family: 'SF Mono', 'Menlo', monospace; font-size: 14px; }
        .ProseMirror pre { background: #f2f2f7; padding: 12px; border-radius: 8px; overflow-x: auto; }
        .ProseMirror pre code { background: none; padding: 0; font-size: 14px; }
        .ProseMirror table { border-collapse: collapse; table-layout: fixed; width: 100%; margin-top: 8px; }
        .ProseMirror td, .ProseMirror th { border: 1px solid #c7c7cc; padding: 6px 10px; vertical-align: top; min-width: 40px; }
        .ProseMirror th { background: #f2f2f7; font-weight: 600; }
        details summary { cursor: pointer; list-style: none; display: flex; align-items: center; gap: 6px; font-weight: 600; }
        details summary::before { content: '▶'; font-size: 10px; color: #8e8e93; transition: transform 0.2s; }
        details[open] summary::before { transform: rotate(90deg); }
        details .details-content { padding-left: 20px; margin-top: 4px; }
        .ProseMirror img { max-width: 100%; border-radius: 8px; display: block; margin-top: 8px; }
        .ProseMirror p.is-editor-empty:first-child::before { content: attr(data-placeholder); color: #c7c7cc; pointer-events: none; float: left; height: 0; }
        #slash-menu { display: none; position: fixed; z-index: 999; background: rgba(255,255,255,0.85); backdrop-filter: blur(20px) saturate(180%); -webkit-backdrop-filter: blur(20px) saturate(180%); border-radius: 14px; box-shadow: 0 8px 32px rgba(0,0,0,0.18); min-width: 220px; max-height: 320px; overflow-y: auto; padding: 6px 0; }
        #slash-menu .menu-section { padding: 6px 14px 2px; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; color: #8e8e93; }
        #slash-menu .menu-item { display: flex; align-items: center; gap: 10px; padding: 9px 14px; cursor: pointer; font-size: 15px; color: #1c1c1e; }
        #slash-menu .menu-item.selected, #slash-menu .menu-item:hover { background: rgba(99,102,241,0.12); }
        #slash-menu .menu-item .icon { width: 26px; height: 26px; border-radius: 6px; background: #f2f2f7; display: flex; align-items: center; justify-content: center; font-size: 14px; flex-shrink: 0; }
        @media (prefers-color-scheme: dark) {
          body { color: #f2f2f7; }
          .ProseMirror code, .ProseMirror pre { background: #2c2c2e; }
          .ProseMirror th { background: #2c2c2e; }
          .ProseMirror td, .ProseMirror th { border-color: #48484a; }
          #slash-menu { background: rgba(28,28,30,0.88); color: #f2f2f7; }
          #slash-menu .menu-item { color: #f2f2f7; }
          #slash-menu .menu-item .icon { background: #3a3a3c; }
          #slash-menu .menu-item.selected, #slash-menu .menu-item:hover { background: rgba(99,102,241,0.2); }
        }
      </style>
    </head>
    <body>
      <div id="editor"></div>
      <div id="slash-menu"></div>
      <script type="module">
        import { Editor, Extension, Node } from 'https://esm.sh/@tiptap/core@2'
        import StarterKit from 'https://esm.sh/@tiptap/starter-kit@2'
        import Placeholder from 'https://esm.sh/@tiptap/extension-placeholder@2'
        import TaskList from 'https://esm.sh/@tiptap/extension-task-list@2'
        import TaskItem from 'https://esm.sh/@tiptap/extension-task-item@2'
        import { Table, TableRow, TableCell, TableHeader } from 'https://esm.sh/@tiptap/extension-table@2'
        import Image from 'https://esm.sh/@tiptap/extension-image@2'
        import TextStyle from 'https://esm.sh/@tiptap/extension-text-style@2'
        import Color from 'https://esm.sh/@tiptap/extension-color@2'
        import Underline from 'https://esm.sh/@tiptap/extension-underline@2'

        const ToggleNode = Node.create({
          name: 'toggle', group: 'block', content: 'block+', defining: true,
          addAttributes() { return { open: { default: true } } },
          parseHTML() { return [{ tag: 'details' }] },
          renderHTML({ node }) { return ['details', node.attrs.open ? { open: '' } : {}, ['summary', {}, 0], ['div', { class: 'details-content' }]] },
          addNodeView() {
            return ({ node, getPos, editor }) => {
              const details = document.createElement('details')
              if (node.attrs.open) details.setAttribute('open', '')
              const summary = document.createElement('summary')
              summary.textContent = node.firstChild?.textContent || 'Toggle'
              const content = document.createElement('div')
              content.className = 'details-content'
              details.append(summary, content)
              details.addEventListener('toggle', () => {
                if (typeof getPos === 'function') {
                  editor.chain().command(({ tr }) => { tr.setNodeMarkup(getPos(), null, { open: details.open }); return true }).run()
                }
              })
              return { dom: details, contentDOM: content }
            }
          }
        })

        const SLASH_COMMANDS = [
          { section: 'Basic Blocks' },
          { label: 'Text', icon: '¶', cmd: 'setParagraph' },
          { label: 'Bulleted List', icon: '•', cmd: 'toggleBulletList' },
          { label: 'To-do List', icon: '☑', cmd: 'toggleTaskList' },
          { label: 'Quote', icon: '"', cmd: 'toggleBlockquote' },
          { label: 'Code', icon: '</>', cmd: 'toggleCodeBlock' },
          { section: 'Headings' },
          { label: 'Heading 1', icon: 'H1', cmd: 'h1' },
          { label: 'Heading 2', icon: 'H2', cmd: 'h2' },
          { label: 'Heading 3', icon: 'H3', cmd: 'h3' },
          { section: 'Media' },
          { label: 'Image', icon: '🖼', cmd: 'insertImage' },
          { label: 'Table', icon: '⊞', cmd: 'insertTable' },
          { section: 'Inline' },
          { label: 'Inline Equation', icon: 'λ', cmd: 'insertLatex' },
          { label: 'Gray', icon: 'A', cmd: 'colorGray' },
          { label: 'Orange', icon: 'A', cmd: 'colorOrange' },
          { label: 'Yellow', icon: 'A', cmd: 'colorYellow' },
          { label: 'Blue', icon: 'A', cmd: 'colorBlue' },
          { label: 'Purple', icon: 'A', cmd: 'colorPurple' },
          { label: 'Pink', icon: 'A', cmd: 'colorPink' },
          { label: 'Brown', icon: 'A', cmd: 'colorBrown' },
        ]

        const SlashCommands = Extension.create({
          name: 'slashCommands',
          addKeyboardShortcuts() { return { 'Escape': () => { hideSlashMenu(); return false } } }
        })

        const editor = new Editor({
          element: document.querySelector('#editor'),
          extensions: [
            StarterKit, Placeholder.configure({ placeholder: "Type '/' for commands, or start writing…" }),
            TaskList, TaskItem.configure({ nested: true }),
            Table.configure({ resizable: false }), TableRow, TableCell, TableHeader,
            Image, TextStyle, Color, Underline, ToggleNode, SlashCommands,
          ],
          content: '',
          onUpdate({ editor }) {
            window.webkit?.messageHandlers?.contentChanged?.postMessage(editor.getHTML())
            checkSlashTrigger(editor)
          },
        })

        let slashQuery = null, selectedIndex = 0
        const menuEl = document.getElementById('slash-menu')

        function checkSlashTrigger(ed) {
          const { from } = ed.state.selection
          const text = ed.state.doc.textBetween(Math.max(0, from - 30), from, '\\n', '\\0')
          const match = text.match(/\\/(\\w*)$/)
          if (match) { slashQuery = match[1].toLowerCase(); selectedIndex = 0; renderSlashMenu(ed) }
          else hideSlashMenu()
        }

        function getFilteredItems() {
          return SLASH_COMMANDS.filter(i => !i.section && (!slashQuery || i.label.toLowerCase().includes(slashQuery)))
        }

        function renderSlashMenu(ed) {
          const items = getFilteredItems()
          if (!items.length) { hideSlashMenu(); return }
          const coords = ed.view.coordsAtPos(ed.state.selection.from)
          menuEl.style.left = Math.min(coords.left, window.innerWidth - 240) + 'px'
          const menuH = Math.min(items.length * 44 + 40, 320)
          const top = coords.bottom + 8
          menuEl.style.top = (top + menuH > window.innerHeight - 40 ? coords.top - menuH - 8 : top) + 'px'
          menuEl.style.display = 'block'
          let html = '', lastSection = null
          SLASH_COMMANDS.forEach(item => {
            if (item.section) { lastSection = item.section; return }
            if (slashQuery && !item.label.toLowerCase().includes(slashQuery)) return
            const idx = items.indexOf(item)
            if (idx === 0 || lastSection) { html += `<div class="menu-section">${lastSection || ''}</div>`; lastSection = null }
            html += `<div class="menu-item${idx === selectedIndex ? ' selected' : ''}" data-cmd="${item.cmd}"><div class="icon">${item.icon}</div><span>${item.label}</span></div>`
          })
          menuEl.innerHTML = html
          menuEl.querySelectorAll('.menu-item').forEach(el => {
            el.addEventListener('mousedown', e => { e.preventDefault(); executeSlashCommand(el.dataset.cmd, ed) })
          })
        }

        function hideSlashMenu() { menuEl.style.display = 'none'; slashQuery = null }

        function executeSlashCommand(cmd, ed) {
          hideSlashMenu()
          const { from } = ed.state.selection
          const text = ed.state.doc.textBetween(Math.max(0, from - 30), from, '\\n', '\\0')
          const match = text.match(/\\/\\w*$/)
          if (match) ed.chain().focus().deleteRange({ from: from - match[0].length, to: from }).run()
          switch (cmd) {
            case 'setParagraph': ed.chain().focus().setParagraph().run(); break
            case 'toggleBulletList': ed.chain().focus().toggleBulletList().run(); break
            case 'toggleTaskList': ed.chain().focus().toggleTaskList().run(); break
            case 'toggleBlockquote': ed.chain().focus().toggleBlockquote().run(); break
            case 'toggleCodeBlock': ed.chain().focus().toggleCodeBlock().run(); break
            case 'h1': ed.chain().focus().toggleHeading({ level: 1 }).run(); break
            case 'h2': ed.chain().focus().toggleHeading({ level: 2 }).run(); break
            case 'h3': ed.chain().focus().toggleHeading({ level: 3 }).run(); break
            case 'insertTable': ed.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(); break
            case 'insertImage': window.webkit?.messageHandlers?.contentChanged?.postMessage('__REQUEST_IMAGE__'); break
            case 'insertLatex': ed.chain().focus().insertContent('<p>$$E = mc^2$$</p>').run(); break
            case 'colorGray': ed.chain().focus().setColor('#8e8e93').run(); break
            case 'colorOrange': ed.chain().focus().setColor('#ff6a00').run(); break
            case 'colorYellow': ed.chain().focus().setColor('#ffd60a').run(); break
            case 'colorBlue': ed.chain().focus().setColor('#0a84ff').run(); break
            case 'colorPurple': ed.chain().focus().setColor('#bf5af2').run(); break
            case 'colorPink': ed.chain().focus().setColor('#ff375f').run(); break
            case 'colorBrown': ed.chain().focus().setColor('#ac8e68').run(); break
          }
        }

        document.addEventListener('mousedown', e => { if (!menuEl.contains(e.target)) hideSlashMenu() })

        window.setContent = html => editor.commands.setContent(html, false)
        window.getContent = () => editor.getHTML()
        window.focusEditor = () => editor.commands.focus('end')
        window.editorCommand = cmd => {
          switch (cmd) {
            case 'toggleBold': editor.chain().focus().toggleBold().run(); break
            case 'toggleItalic': editor.chain().focus().toggleItalic().run(); break
            case 'toggleUnderline': editor.chain().focus().toggleUnderline().run(); break
            case 'toggleStrike': editor.chain().focus().toggleStrike().run(); break
            case 'toggleBulletList': editor.chain().focus().toggleBulletList().run(); break
            case 'toggleTaskList': editor.chain().focus().toggleTaskList().run(); break
          }
        }
        window.insertImage = src => editor.chain().focus().setImage({ src }).run()
        window.insertTable = (rows, cols) => editor.chain().focus().insertTable({ rows, cols, withHeaderRow: true }).run()
        window.exportAsDocx = async () => {
          try {
            const { default: HTMLtoDOCX } = await import('https://esm.sh/html-to-docx@1')
            const blob = await HTMLtoDOCX(editor.getHTML(), null, { orientation: 'portrait' })
            const bytes = new Uint8Array(await blob.arrayBuffer())
            let bin = ''; for (let b of bytes) bin += String.fromCharCode(b)
            return btoa(bin)
          } catch { return null }
        }

        window.webkit?.messageHandlers?.editorReady?.postMessage(true)
      </script>
    </body>
    </html>
    """
}
#endif
