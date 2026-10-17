// HTMLHint results as CodeMirror diagnostics.
import { HTMLHint } from "htmlhint";

const severities = { error: "error", warning: "warning" };

export function lintHTML(view) {
  const doc = view.state.doc;
  const messages = HTMLHint.verify(doc.toString(), HTMLHint.defaultRuleset);
  return messages.map((message) => {
    const line = doc.line(Math.min(Math.max(message.line, 1), doc.lines));
    const from = Math.min(line.from + Math.max(message.col - 1, 0), line.to);
    const to = Math.min(from + Math.max(message.raw?.length ?? 1, 1), doc.length);
    return {
      from,
      to,
      severity: severities[message.type] ?? "info",
      source: `HTMLHint ${message.rule.id}`,
      message: message.message,
    };
  });
}
