// markdownlint results as CodeMirror diagnostics.
import { lint } from "markdownlint/sync";

// All rules except MD013 (line length), which flags nearly every paragraph of prose.
const config = { default: true, MD013: false };

export function lintMarkdown(view) {
  const doc = view.state.doc;
  const results = lint({ strings: { content: doc.toString() }, config });
  return (results.content ?? []).map((issue) => {
    const line = doc.line(Math.min(Math.max(issue.lineNumber, 1), doc.lines));
    let from = line.from;
    let to = line.to;
    if (issue.errorRange) {
      const [column, length] = issue.errorRange;
      from = Math.min(line.from + column - 1, line.to);
      to = Math.min(from + length, line.to);
    }
    const [id, name] = issue.ruleNames;
    return {
      from,
      to,
      // Style rules rather than syntax errors: show them all as warnings.
      severity: "warning",
      source: `markdownlint ${id}/${name}`,
      message: issue.ruleDescription + (issue.errorDetail ? ` [${issue.errorDetail}]` : ""),
    };
  });
}
