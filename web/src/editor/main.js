// Edit mode: CodeMirror 6 with syntax highlighting, line numbers and inline lint
// (markdownlint for Markdown, HTMLHint for HTML).
//
// Swift owns the file. It calls window.tabbit.setDocument / getText / markSaved, and
// receives {type: "ready"} and {type: "dirty", dirty} via window.webkit.messageHandlers.tabbit.
import { basicSetup } from "codemirror";
import { Compartment, EditorState, Text } from "@codemirror/state";
import { EditorView, keymap } from "@codemirror/view";
import { indentWithTab } from "@codemirror/commands";
import { defaultHighlightStyle, HighlightStyle, LanguageDescription, syntaxHighlighting } from "@codemirror/language";
import { tags } from "@lezer/highlight";
import { linter, lintGutter } from "@codemirror/lint";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { html } from "@codemirror/lang-html";
import { javascript } from "@codemirror/lang-javascript";
import { css } from "@codemirror/lang-css";
import { json } from "@codemirror/lang-json";
import { python } from "@codemirror/lang-python";
import { oneDark } from "@codemirror/theme-one-dark";
import { lintMarkdown } from "./lint-markdown.js";
import { lintHTML } from "./lint-html.js";

// Highlighting inside fenced code blocks in Markdown.
const codeLanguages = [
  LanguageDescription.of({ name: "JavaScript", alias: ["js", "mjs", "cjs"], support: javascript() }),
  LanguageDescription.of({ name: "TypeScript", alias: ["ts"], support: javascript({ typescript: true }) }),
  LanguageDescription.of({ name: "JSX", support: javascript({ jsx: true }) }),
  LanguageDescription.of({ name: "TSX", support: javascript({ jsx: true, typescript: true }) }),
  LanguageDescription.of({ name: "CSS", support: css() }),
  LanguageDescription.of({ name: "HTML", alias: ["htm"], support: html() }),
  LanguageDescription.of({ name: "JSON", support: json() }),
  LanguageDescription.of({ name: "Python", alias: ["py"], support: python() }),
];

// CodeMirror's default light colors, minus the underline on Markdown headings (which looks
// too much like a lint underline).
const lightHighlight = HighlightStyle.define(
  defaultHighlightStyle.specs.map((spec) => (spec.tag === tags.heading ? { ...spec, textDecoration: "none" } : spec)),
);

const darkMode = window.matchMedia("(prefers-color-scheme: dark)");
const theme = new Compartment();
const themeFor = (dark) => (dark ? oneDark : syntaxHighlighting(lightHighlight));

const baseTheme = EditorView.theme({
  "&": { height: "100%", fontSize: "13px" },
  "&.cm-focused": { outline: "none" },
  ".cm-scroller": { fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace', lineHeight: "1.55" },
  ".cm-content": { padding: "10px 0" },
  ".cm-gutters": { border: "none" },
});

let view = null;
let savedDoc = Text.empty;
let lastDirty = false;

function post(message) {
  window.webkit?.messageHandlers?.tabbit?.postMessage(message);
}

// Tells Swift whether the text differs from the saved file (only on change, unless forced).
function reportDirty(force = false) {
  const dirty = !view.state.doc.eq(savedDoc);
  if (force || dirty !== lastDirty) {
    lastDirty = dirty;
    post({ type: "dirty", dirty });
  }
}

function createState(text, language) {
  const isMarkdown = language === "markdown";
  return EditorState.create({
    doc: text,
    extensions: [
      basicSetup,
      keymap.of([indentWithTab]),
      isMarkdown ? markdown({ base: markdownLanguage, codeLanguages }) : html(),
      isMarkdown ? EditorView.lineWrapping : [],
      lintGutter(),
      linter(isMarkdown ? lintMarkdown : lintHTML, { delay: 400 }),
      baseTheme,
      theme.of(themeFor(darkMode.matches)),
      // Keep Windows line endings when saving a file that has them.
      text.includes("\r\n") ? EditorState.lineSeparator.of("\r\n") : [],
      EditorView.contentAttributes.of({ autocorrect: "off", autocapitalize: "off", spellcheck: "false" }),
      EditorView.updateListener.of((update) => {
        if (update.docChanged) reportDirty();
      }),
    ],
  });
}

darkMode.addEventListener("change", (event) => {
  view?.dispatch({ effects: theme.reconfigure(themeFor(event.matches)) });
});

window.tabbit = {
  /** Replaces the content (and undo history); `text` becomes the saved baseline. */
  setDocument(text, language) {
    const state = createState(text, language);
    if (view) {
      view.setState(state);
    } else {
      view = new EditorView({ state, parent: document.getElementById("editor") });
    }
    savedDoc = view.state.doc;
    reportDirty(true);
  },

  /** The current text, with the file's original line endings. */
  getText() {
    return view ? view.state.sliceDoc() : null;
  },

  /** `text` was just written to disk: it becomes the baseline for the edited state. */
  markSaved(text) {
    savedDoc = text === view.state.sliceDoc() ? view.state.doc : Text.of(text.split(/\r\n|\r|\n/));
    reportDirty(true);
  },

  focus() {
    view?.focus();
  },
};

post({ type: "ready" });
