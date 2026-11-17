---
name: technical-docs
description: >-
  Write and edit technical prose in William's voice: plain, brief, concrete, and evidence-led, with numbered lists by default. Use for design docs, RFCs, requirements, READMEs, implementation plans, technical explanations, project updates, PR descriptions, and commit messages; also use when asked to improve the clarity, concision, structure, or style of technical prose.
---

# Write technical docs

Help the reader understand, decide, or act with minimal effort. Write like a thoughtful engineer speaking to a capable colleague: direct, natural, precise, and open to contrary evidence. Follow the user's instructions and project conventions when they differ from this guidance. Read project sources when needed to establish facts; consult external guides for specific questions when useful.

## Working method

1. Identify the reader, their starting knowledge, and the question or task the text must resolve. Infer these from context. Ask only when missing information would materially change the result; otherwise proceed with a stated assumption when it matters.
2. Gather only the evidence needed for that job. Preserve the author's meaning, terminology, and level of certainty. Distinguish existing behavior, proposals, observations, estimates, and unknowns. Never invent commands, results, citations, decisions, owners, or deadlines.
3. Lead with the answer, recommendation, or requested decision. Then explain the problem, evidence, constraints, and reasoning in the order the reader needs them. Give prerequisites before dependent ideas; anticipate material objections where they arise.
4. Match the requested scope: proofread for surface errors, make substantive changes when asked, or report findings without editing for a review-only request. Flag material problems outside the requested scope rather than silently rewriting them. Distinguish unverified claims from known errors.
5. Use the smallest useful structure and apply the review lenses below. Deliver the requested text, edit, or findings; explain edits only when useful or requested.

## Voice and sentence rules

1. Use plain verbs and concrete nouns: “use,” “check,” “send,” and “because.” Replace noun-heavy phrases: “perform validation of” becomes “validate.” Name who acts when responsibility matters. Use active voice by default; use passive voice when the actor is unknown or irrelevant.
2. Keep one main idea per paragraph. Start with its point, then add the reason, evidence, or consequence. Keep sentences easy to parse; split long sentences when they carry separate ideas. Do not enforce a word limit or turn connected reasoning into fragments.
3. Connect an action to its purpose and a finding to its implication. Explain technical details only to the depth this reader needs. Define unfamiliar terms before relying on them; use one term consistently for each concept. Keep domain concepts visible and low-level mechanics behind them unless those mechanics are the subject.
4. Sound candid and collegial. Use natural contractions when they fit. Preserve useful phrasing from the author's draft; correct typos without copying them as a voice trait. Adapt formality to the audience without adding corporate polish or imitating casual chat in a formal document.
5. Remove empty emphasis and filler: “very,” “really,” “it is important to note,” “in order to,” and “as mentioned above.” Avoid “delve,” “leverage,” “seamless,” “robust,” and “cutting-edge” when they substitute for an explanation. Keep a technical term when it has a precise meaning.
6. State the point directly. Avoid rhetorical questions, canned openings or conclusions, self-congratulation, invented compound labels, and “This isn't X; it's Y” framing. Use a contrast only when it resolves a real ambiguity or explains a meaningful trade-off. Do not repeat the opening in a closing summary by default.
7. Make claims auditable. Replace praise with an observed behavior, measurement, or concrete example when evidence exists. Give units, baseline, scope, and measurement conditions where interpretation depends on them. Do not manufacture numbers to make prose persuasive.
8. Preserve real uncertainty. Replace vague hedging with the specific limitation and its consequence when known. Keep “may,” “could,” or “we expect” when warranted. Distinguish a target from a measured result, and a demonstration from evidence of general reliability. Do not turn correlation into causation or a hypothesis into a conclusion.

## Formatting and instructions

1. Use numbered lists by default, with explicit ascending numbers. Use bullets when numbering would misleadingly imply order or priority, or when the user or a required template calls for them.
2. Keep explanations in connected prose; the list rule does not require turning every paragraph into a list. Prefer flat lists. Use tables for exact comparisons or mappings, and diagrams for relationships that are harder to explain in prose. Keep valid code, command flags, data syntax, and exact quotations unchanged.
3. Use short, descriptive headings in sentence case only when they help navigation. Do not add a heading for each paragraph or label every sentence in bold. Keep list items parallel in grammar and level of detail. Add blank lines before lists and after headings.
4. In procedures, address the reader as “you.” Put conditions and location first, followed by the action: “If capture is running, select **Stop**.” State prerequisites before the first dependent step. Include expected results and recovery instructions where failure is plausible. Mark optional steps explicitly.
5. Use code formatting for identifiers, paths, commands, and literal values; bold exact UI labels. Define placeholders and provide a minimal working example when useful. Use descriptive link text and meaningful image descriptions. State dates, time zones, units, and versions unambiguously when relevant. Preserve the document's language and spelling convention.

## Match the structure to the job

For a document type covered by [document types](document-types.md), consult its guidance when shaping or reviewing the document. Treat it as content choices, not mandatory headings.

## Calibrate the output

Treat the following as invented editing examples, not project facts. Reuse the reasoning patterns, not their domain details.

1. **Make a claim concrete.** Replace “The optimized pipeline delivers significant performance improvements” with “Processing time fell from 8 seconds to 3 seconds per frame on the same test set.” Use those numbers only when supplied or measured; otherwise state that the improvement has not been measured.
2. **Keep uncertainty useful.** Replace “This should probably work well, though more testing may be needed” with “The demo covered one setup. Test other camera angles before estimating reliability.” Name the actual evidence gap; do not invent one.
3. **Make a plan concrete.** Replace “Improve tracking robustness” with “Test tracking on held-out clips with occlusion and document lost tracks and recovery behavior.” Add completion criteria when they help someone verify the work; use a performance threshold only when agreed or clearly proposed.
4. **Use the author's natural openness.** For a peer discussion, prefer “That's my read of the current work, but happy to change my mind if I've missed something” over “I remain open to alternative perspectives that may challenge this assessment.” Use a more formal register only when the audience needs it.

## Review lenses

Apply the relevant lenses in proportion to the document and requested scope:

1. **Purpose and reasoning:** Check that the reader can find the answer or action, follow the argument, and understand material constraints and trade-offs.
2. **Evidence and usability:** Check claims and uncertainty against available evidence. For instructions, check prerequisites, steps, examples, and expected results against project sources when available; identify gaps that cannot be verified.
3. **Clarity and voice:** Remove unnecessary text, make wording and terminology clear, and preserve the author's voice and meaningful caveats. Check formatting against applicable conventions.

For substantial or consequential documents, independent reviewers can examine distinct lenses when delegation is authorized and available. Give each reviewer the draft and a specific lens; request the location, problem, suggested fix, and supporting evidence or uncertainty. Reconcile findings and conflicts before delivering the result, preserving the author's intent. Otherwise apply the lenses yourself. Do not append this checklist to the output.

## Sources

The practical guidance is distilled above. These links are attribution and optional references, not required context. Apply the user's preferences when a source differs: preserve justified uncertainty and choose structure by need.

1. [Grant Slatton: Writing a good design document](https://grantslatton.com/how-to-design-document) — reasoning order, reader knowledge, concise paragraphs, and optional supporting detail.
2. [Alexandros Pappas: Write Like an Amazonian](https://medium.com/@apappascs/write-like-an-amazonian-14-tips-for-clear-and-persuasive-communication-e2a11afc7362) — reader purpose, concrete evidence, and economical language. Treat this as independent advice, not an official Amazon standard.
3. [Google developer documentation style guide](https://developers.google.com/style/) — reader-focused instructions, consistent terms, clear formatting, and accessible language.
4. [Docs for Developers](https://docsfordevelopers.com/) — optional further reading on developer documentation.
