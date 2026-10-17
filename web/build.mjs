// Bundles the web code into ../Tabbit/Resources/web (committed, so the app builds without Node).
//
//   markdown.html  Self-contained Markdown viewer page (JS and CSS inlined). Swift serves it at
//                  the .md file's own path over the tabbit-file: scheme, so relative links and
//                  images resolve against the file's folder.
//   editor.html    Self-contained source editor page (CodeMirror 6 + markdownlint + HTMLHint).
//
// Usage: npm run build
import * as esbuild from "esbuild";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.resolve(here, "../Tabbit/Resources/web");
const target = ["safari17"];

const read = (file) => readFile(path.resolve(here, file), "utf8");

async function bundleJS(entry) {
  const result = await esbuild.build({
    entryPoints: [path.resolve(here, entry)],
    bundle: true,
    format: "iife",
    minify: true,
    target,
    write: false,
  });
  return result.outputFiles[0].text;
}

async function minifyCSS(css) {
  const result = await esbuild.transform(css, { loader: "css", minify: true, target });
  return result.code;
}

// Insert code into an inline <script>/<style> without letting it close the tag early.
function inline(template, marker, code, tag) {
  const safe = code.replace(new RegExp(`</(${tag})`, "gi"), "<\\/$1");
  if (!template.includes(marker)) throw new Error(`Missing ${marker} in template`);
  return template.replace(marker, () => safe);
}

async function buildMarkdownViewer() {
  const css = await minifyCSS(
    [
      await read("node_modules/github-markdown-css/github-markdown.css"),
      `@media (prefers-color-scheme: light) {\n${await read("node_modules/highlight.js/styles/github.css")}\n}`,
      `@media (prefers-color-scheme: dark) {\n${await read("node_modules/highlight.js/styles/github-dark.css")}\n}`,
      await read("src/markdown/page.css"),
    ].join("\n"),
  );
  const js = await bundleJS("src/markdown/main.js");

  let html = await read("src/markdown/template.html");
  html = inline(html, "/* @inline-css */", css, "style");
  html = inline(html, "/* @inline-js */", js, "script");
  await writeFile(path.join(outDir, "markdown.html"), html);
  return html.length;
}

async function buildEditor() {
  const css = await minifyCSS(await read("src/editor/page.css"));
  const js = await bundleJS("src/editor/main.js");

  let html = await read("src/editor/template.html");
  html = inline(html, "/* @inline-css */", css, "style");
  html = inline(html, "/* @inline-js */", js, "script");
  await writeFile(path.join(outDir, "editor.html"), html);
  return html.length;
}

await mkdir(outDir, { recursive: true });
for (const [name, build] of [["markdown.html", buildMarkdownViewer], ["editor.html", buildEditor]]) {
  const size = await build();
  console.log(`${name.padEnd(14)} ${(size / 1024).toFixed(0)} KB`);
}
