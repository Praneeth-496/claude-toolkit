---
name: 10x
description: Rewrite text to be dramatically sharper — tighter, more vivid, more memorable. TRIGGER when user says "make this sharper", "tighten this", "rewrite better", "make it punchier", "improve this paragraph", "this is too wordy", or pastes prose/commit-msg/PR-text and asks for a better version. For thesis paragraphs, abstracts, copy, commit messages.
---

# 10x rewrite

The user has invoked `/10x`. Rewrite the target text to be sharper by an order of magnitude.

## Target

- If the user pasted text, rewrite that.
- Otherwise, rewrite Claude's most recent substantive response.
- If neither is obvious, ask: "Which text should I sharpen?"

## How to sharpen

1. **Cut filler ruthlessly**: "in order to" → "to", "due to the fact that" → "because", "it is important to note" → delete.
2. **Replace abstract with concrete**: "improves performance" → "drops p99 latency from 800ms to 110ms".
3. **Active voice, strong verbs**: "was implemented by us" → "we shipped".
4. **One idea per sentence**. Break long sentences.
5. **Lead with the punchline.** Bury context, not the point.
6. **Kill adjectives** that don't carry information ("very", "really", "quite", "somewhat").
7. **Preserve all factual claims and numbers** — sharpening is about form, never invented content.

## Output

Just the rewritten text. No "here's the rewrite", no diff, no explanation — unless the user asks. If the original had structural issues (wrong audience, missing claim), flag that in one line AFTER the rewrite.
