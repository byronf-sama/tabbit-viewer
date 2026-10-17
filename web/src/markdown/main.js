// Markdown View: GitHub-flavored rendering with markdown-it and highlight.js.
// Swift loads the built page with the .md file's URL as the base URL, then calls
// window.tabbit.render(text) whenever the text changes, so the page (and scroll
// position) survives re-renders.
import MarkdownIt from "markdown-it";
import anchor from "markdown-it-anchor";
import footnote from "markdown-it-footnote";
import taskLists from "markdown-it-task-lists";
import alerts from "markdown-it-github-alerts";
import { slug } from "github-slugger";
import hljs from "highlight.js/lib/common";

const md = new MarkdownIt({
  html: true,
  linkify: true,
  highlight(code, lang) {
    if (!lang || !hljs.getLanguage(lang)) return "";
    try {
      const html = hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
      return `<pre><code class="hljs language-${md.utils.escapeHtml(lang)}">${html}</code></pre>`;
    } catch {
      return "";
    }
  },
})
  // GitHub-style heading ids, so [links](#some-heading) work.
  .use(anchor, { slugify: (text) => slug(text), tabIndex: false, failOnNonUnique: false })
  .use(footnote)
  .use(taskLists, { label: true })
  .use(alerts);

// Footnote references as plain numbers, like GitHub ("1", not "[1]").
md.renderer.rules.footnote_caption = (tokens, idx) => {
  const { id, subId } = tokens[idx].meta;
  return subId > 0 ? `${id + 1}:${subId}` : `${id + 1}`;
};

const content = document.getElementById("content");

window.tabbit = {
  render(text) {
    content.innerHTML = md.render(text);
  },
};
