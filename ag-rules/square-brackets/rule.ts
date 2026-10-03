// ag-rules: square-brackets (spec: rule.md beside this). Bracketed notes in Nathan's prompts → new sessions.
import { originTag, parseOrigins } from "../../../ag/pi/dot-pi/agent/extensions/ag-origin.ts";
import type { PromptRule } from "../../../ag/ag-rules/types.ts";

// Agent-written prompts: origin tags only agents add (ag spawn/report, the tickler, a spun-out note), and the
// older plain-text markers (the [ag-parent: …] footer, tickler icons). Routed captures (follow, hint, share,
// screenshot, comment, playbook) are still Nathan's words, so the rule applies to them.
const AGENT_KINDS = new Set(["spawn", "report", "tickler", "note"]);
const LEGACY_AGENT = /\[ag-parent: |^\s*(?:⏰|🔔|◷|↺) /u;
const APPENDED = /\n(?:---\n)?(?:Session context \(snapshot|\[ag-parent: )/;
// Tags tools put in prompts, not Nathan's notes.
const TOOL_TAG = /^(?:ag-|image\b|pasted\b|merged\b|routine-)/i;

/** Nathan's own words: the prompt without origin tags or appended context blocks. */
function ownText(text: string): string | null {
	const { text: rest, origins } = parseOrigins(text);
	if (origins.some((o) => AGENT_KINDS.has(o.kind)) || LEGACY_AGENT.test(text)) return null;
	return rest.split(APPENDED)[0];
}

/** The bracketed notes in a prompt: prose in [ ], outside code, not a link/checkbox/index. */
export function bracketNotes(text: string): string[] {
	const own = ownText(text);
	if (own === null) return [];
	const body = own.replace(/```[\s\S]*?(```|$)/g, " ").replace(/`[^`\n]*`/g, " ");
	const notes: string[] = [];
	for (const m of body.matchAll(/(?<![\w\]\\!])\[([^\[\]\n]+)\](?![(\[:])/g)) {
		const note = m[1].trim();
		if (/[a-z]/i.test(note) && /\s/.test(note) && !TOOL_TAG.test(note)) notes.push(note);
	}
	return notes;
}

const rule: PromptRule = (prompt, ag) => {
	const notes = bracketNotes(prompt.text);
	if (!notes.length) return;
	const context = ownText(prompt.text)!.trim();
	for (const note of notes) {
		const why =
			`Nathan wrote this as a [bracketed] note in a prompt to another session. His standing rule (ag-rules: ` +
			`square-brackets) is that bracketed notes become their own session, so handle it here. Bracketed notes are ` +
			`often about the Ag system itself (the agent instructions in ~/ag/agents.md, the ag and dotfiles repos, how ` +
			`agents behave); if this one is, treat it as a change to the system and ship it per those repos' rules. ` +
			`For context, the full prompt it came from:\n\n> ${context.replace(/\n/g, "\n> ")}`;
		ag.spawn(`${originTag({ kind: "note", label: "Bracketed note", note: why })}\n${note}`);
	}
	let rest = prompt.text;
	for (const note of notes) rest = rest.replace(`[${note}]`, "").replace(/[ \t]{2,}/g, " ");
	if (!(ownText(rest) ?? "").trim()) return { handled: `Spun out ${notes.length} bracketed note(s) as new sessions` };
	const list = notes.map((n) => `“${n}”`).join("; ");
	const label = notes.length === 1 ? "Bracketed note spun out" : `${notes.length} bracketed notes spun out`;
	return {
		text: `${rest.trim()}\n\n${originTag({ kind: "rule", label, note: `Nathan's bracketed note(s) were already spun out to new Inbox sessions automatically; don't act on them here: ${list}.` })}`,
	};
};
export default rule;
