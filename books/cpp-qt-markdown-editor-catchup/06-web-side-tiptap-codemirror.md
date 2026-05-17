---
title: "Web 側エディタ — TipTap + CodeMirror + KaTeX + Mermaid を Vite で束ねる"
---

C++ 側がファイル I/O・テーマ・自動保存・エクスポートを担当するなら、Web 側の責務は **「WYSIWYG 編集体験そのもの」だけ** に絞れる。本章では Vite + TypeScript で組む最小構成を見る。

## ライブラリ選定

| 役割 | 採用 | 代替 |
|---|---|---|
| WYSIWYG エンジン | **TipTap** (ProseMirror ベース) | Lexical, Slate |
| ソースモード | **CodeMirror 6** | Monaco (重い、Electron 寄り) |
| 数式 | **KaTeX** | MathJax (遅い) |
| 図表 | **Mermaid** | (代替少) |
| シンタックスハイライト | **highlight.js** | Shiki (品質高いが大きい) |
| Markdown ↔ AST | **markdown-it** + **turndown** | unified/remark (堅いが学習コスト高) |

## package.json (最小)

```jsonc
{
  "name": "your-editor-web",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev":   "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "devDependencies": {
    "vite": "^7.0.0",
    "typescript": "^5.6.0"
  },
  "dependencies": {
    "@tiptap/core": "^2.10.0",
    "@tiptap/starter-kit": "^2.10.0",
    "@tiptap/extension-link": "^2.10.0",
    "@tiptap/extension-table": "^2.10.0",
    "@tiptap/extension-image": "^2.10.0",
    "codemirror": "^6.0.1",
    "@codemirror/lang-markdown": "^6.3.0",
    "@codemirror/theme-one-dark": "^6.1.2",
    "katex": "^0.16.11",
    "mermaid": "^11.4.0",
    "highlight.js": "^11.10.0",
    "markdown-it": "^14.1.0",
    "turndown": "^7.2.0"
  }
}
```

## vite.config.ts

```ts
import { defineConfig } from "vite";

export default defineConfig({
  base: "./",              // qrc:/ や file:/ で動かすため相対パス
  build: {
    outDir: "dist",
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          mermaid: ["mermaid"],
          katex:   ["katex"],
        },
      },
    },
  },
});
```

`base: "./"` が地味に重要で、これがないと build 結果が `/assets/xxx.js` という absolute path を吐き、`file://` や `qrc:///` でロードした時に解決できない。

## エディタの最小実装

```ts
// editor/src/editor.ts
import { Editor } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import Link from "@tiptap/extension-link";
import Table from "@tiptap/extension-table";
import Image from "@tiptap/extension-image";
import MarkdownIt from "markdown-it";
import TurndownService from "turndown";

const md = new MarkdownIt({ html: false, linkify: true, typographer: true });
const turndown = new TurndownService({ headingStyle: "atx" });

export type EditorHandle = {
  setMarkdown(markdown: string): void;
  getMarkdown(): string;
  onChange(fn: (markdown: string) => void): void;
};

export function mountEditor(root: HTMLElement): EditorHandle {
  const listeners: Array<(markdown: string) => void> = [];

  const editor = new Editor({
    element: root,
    extensions: [
      StarterKit,
      Link.configure({ openOnClick: false }),
      Table.configure({ resizable: true }),
      Image.configure({ inline: true }),
    ],
    content: "",
    onUpdate({ editor }) {
      const html = editor.getHTML();
      const markdown = turndown.turndown(html);
      listeners.forEach((fn) => fn(markdown));
    },
  });

  return {
    setMarkdown(markdown) {
      const html = md.render(markdown);
      editor.commands.setContent(html, false);
    },
    getMarkdown() {
      return turndown.turndown(editor.getHTML());
    },
    onChange(fn) {
      listeners.push(fn);
    },
  };
}
```

これだけで基本的な WYSIWYG が動く。`turndown` が HTML → Markdown を担う点が重要。TipTap は内部 HTML で持つので、保存時に Markdown へ変換する。

## ソースモード切り替え

ユーザーが「生 Markdown を直接編集したい」と思うことがある。CodeMirror 6 を併設してトグルする。

```ts
// editor/src/source-mode.ts
import { EditorView, basicSetup } from "codemirror";
import { markdown } from "@codemirror/lang-markdown";
import { oneDark } from "@codemirror/theme-one-dark";

export function mountSourceMode(root: HTMLElement, initial: string): {
  getValue(): string;
  setValue(v: string): void;
  destroy(): void;
} {
  const view = new EditorView({
    doc: initial,
    extensions: [basicSetup, markdown(), oneDark],
    parent: root,
  });
  return {
    getValue: () => view.state.doc.toString(),
    setValue: (v) => view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: v },
    }),
    destroy: () => view.destroy(),
  };
}
```

WYSIWYG と Source mode の切り替えは「現在の markdown を取り出して、もう一方の mode の初期値として渡す」だけのシンプルなロジックで実現できる。

## KaTeX で数式

markdown-it に plugin を入れるとブロック/インライン数式を `<span class="katex">` に変換できる。

```ts
import MarkdownIt from "markdown-it";
// 本家 `markdown-it-katex` は long-unmaintained。markdown-it 14 系では
// メンテされている fork (例: @traptitech/markdown-it-katex) を使う方が安全。
import mdKatex from "@traptitech/markdown-it-katex";

const md = new MarkdownIt({ html: false }).use(mdKatex, { throwOnError: false });
```

CSS は `import "katex/dist/katex.min.css"` を bundle に含める。

## Mermaid で図表

```ts
import mermaid from "mermaid";

mermaid.initialize({ startOnLoad: false, theme: "default" });

export async function renderMermaidAll(container: HTMLElement) {
  const blocks = container.querySelectorAll<HTMLElement>("code.language-mermaid");
  for (const block of blocks) {
    const code = block.textContent ?? "";
    const id = `mermaid-${Math.random().toString(36).slice(2)}`;
    try {
      const { svg, bindFunctions } = await mermaid.render(id, code);
      const div = document.createElement("div");
      div.innerHTML = svg;
      block.parentElement?.replaceWith(div);
      // gantt / journey / sequence 等で click handler が必要な場合は bindFunctions を呼ぶ
      bindFunctions?.(div);
    } catch (err) {
      console.warn("mermaid render error", err);
    }
  }
}
```

Mermaid は遅延ロード可能で、`mermaid.render` を呼んだ瞬間に Lazy で chunk が読み込まれる (Vite manualChunks で分離した効果)。

## highlight.js で構文ハイライト

```ts
import hljs from "highlight.js";
import "highlight.js/styles/github.css";

export function highlightAll(container: HTMLElement) {
  container.querySelectorAll<HTMLElement>("pre code").forEach((el) => {
    hljs.highlightElement(el);
  });
}
```

`onUpdate` 後 / `setMarkdown` 後に `highlightAll(root)` を呼べば良い。

## C++ Bridge との結線

第 5 章で書いた bridge と連動するエントリポイント:

```ts
// editor/src/index.ts (全体構造)
import { initBridge } from "./bridge";
import { mountEditor } from "./editor";
import { mountSourceMode } from "./source-mode";
import { renderMermaidAll } from "./mermaid-render";
import { highlightAll } from "./highlight";

(async () => {
  const bridge = await initBridge();
  const root = document.getElementById("root")!;
  const editor = mountEditor(root);

  bridge.documentLoaded.connect((md: string) => {
    editor.setMarkdown(md);
    requestAnimationFrame(() => {
      renderMermaidAll(root);
      highlightAll(root);
    });
  });

  editor.onChange(() => bridge.setDirty(true));

  document.addEventListener("keydown", (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === "s") {
      e.preventDefault();
      bridge.requestSave(editor.getMarkdown());
    }
  });

  bridge.saveFinished.connect((ok, path) => {
    if (!ok) console.error("save failed:", path);
  });
})();
```

## 落とし穴

1. **`base: "./"` を vite.config に書き忘れる** → file:// で `404 /assets/index-xxx.js`
2. **TipTap が ProseMirror Schema を内部で持つため、HTML ⇆ Markdown ラウンドトリップで微小な差** が出る (例: `**text**` が `<strong>text</strong>` 経由で `<b>` に戻ることがある)。turndown のオプションで吸収する
3. **Mermaid の起動コストが Initial Load を重くする**: lazy import (`const m = await import("mermaid")`) でユーザーが Mermaid ブロックを含む doc を開いた時だけ読む
4. **CodeMirror 6 と TipTap 2 を同時 mount すると stylesheet 競合** することがある。CodeMirror 側に CSS scope を当てる

## 次の章

第 7 章で C++ 側の Feature Manager (DocumentManager / ThemeManager / AutoSaveManager / ExportManager) の実装パターンを扱う。
