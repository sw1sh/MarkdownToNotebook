# Authoring gaps: palette vs markdown

What you can do in the DocumentationTools palette / docked toolbars
(catalogued in [palette.md](palette.md) and [docked-cells.md](docked-cells.md))
that the markdown source for `MarkdownToNotebook` cannot yet express, for
every template. "Lossy" = the markdown produces a working notebook but
loses a distinction the palette draws; "Missing" = no md form at all.

## Cross-cutting (applies to every template)

| Gap | Palette / toolbar | Markdown form | Notes |
|---|---|---|---|
| **Missing**: `Overview` template | "New Overview Page" + `TOCChapter` / `TOCSection` / `TOCSubsection` / `TOCSubsubsection` styles + `GenerateOverviewDialog[]` | no `Template: Overview` | the only mid-level Wolfram doc-page kind without a markdown shell |
| **Missing**: TooltipBox annotations | "Annotate" / "Annotation Search ↑↓" / "Annotation Remove" | no md form | inline tooltips on a span of prose; usually authoring scratchwork |
| **Missing**: Reviewer comments | "Insert comment for reviewer" / "Reply »" cells | no md form | a review-loop construct; the markdown source is the canonical artifact, so reviews don't round-trip |
| **Missing**: `Excluded` cell tag | cell-tools "Mark/unmark as excluded" | (close, not equivalent: `#\| eval: false`) | excluded cells stay in the source notebook but are stripped from the scraped resource; `eval: false` keeps the cell visible (just doesn't run it) |
| **Missing**: `Hidden` cell with `CellOpen -> False` only on the *published* page | cell-tools "Mark/unmark as hidden" | no md form | the input is shown when downloaded but closed on the web page; the converter groups input+output but doesn't distinguish "shown vs hidden when published" |
| **Lossy**: Span First Column | `TableSpanToggle[]` | n/a in pipe tables | GFM pipe tables can't span cells - if you need a wide first-column label, change the layout |
| **Lossy**: bulk paclet-wide rewrites | `SetPacletApplyFunction[...]` (every page in the paclet) | no md form | rewrites all pages' guide listings or symbol classifications at once; the markdown equivalent is a sed across `docs/**/*.md` |
| **Lossy**: per-section MoreInfo bubbles | the `?` opener next to each section heading | not authored from md | the resource template injects them; both the forward converter and `NotebookToMarkdown` ignore them |

## `Symbol` (function / symbol ref page)

| Status | Gap | Palette button → action | Markdown form |
|---|---|---|---|
| ✓ Done | Usage, Details & Options, Examples, Scope, Options, Applications, Properties, Possible Issues, Neat Examples | every section / heading / delimiter button | `## …` headings, `---` between sibling examples |
| ✓ Done | Usage signatures with linked head and italic args | "Double Usage Line" + "Template Input" + "Italic Input" + "Traditional Math" | `<code>[Range]()[$x_1$, $x_2$]</code>` |
| ✓ Done | Inferred symbol links | "Link to Function" / "Make Link" / "Custom URI" | `[Name]()` for inferred, `[label](paclet:Pub/Pkg/ref/Name)` for explicit |
| ✓ Done | Pipe tables in Details / Options | "Insert Custom Table" / "Insert table with two/three columns" / "Add Row" | `\| a \| b \|` rows + `\|---\|---\|` separator |
| ⚠ Lossy | Auto-populated options table | "Options Table" → `OptionsTableCreate[]` (dialog reads `Options[Symbol]`) | author the table by hand |
| ⚠ Lossy | Subscripted variable placeholder | "Insert subscripted variable placeholder" → `SubscriptBox` in `InlineFormula` | `$x_1$` works, but no per-cell *placeholder* affordance |
| ✗ Missing | Annotate | "Annotate" | no md form |

## `Guide` (guide page)

| Status | Gap | Palette button → action | Markdown form |
|---|---|---|---|
| ✓ Done | Section, Subsection, Text, Functions listing | the Guide-tab Insert buttons | `## …`, `### …`, prose paragraphs, `## Functions` list |
| ⚠ Lossy | Choosing layout for the functions listing | "1 Line Function Listing" vs "Functions Inline Listing" vs "Inline Listing Toggle" | the converter picks one rendering; no front-matter / cell-option to choose |
| ✗ Missing | Bulk paclet-wide listing rewrite | `SetPacletApplyFunction[...]` | run a sed across `docs/Guides/*.md` |

## `TechNote` (tutorial page)

| Status | Gap | Palette button → action | Markdown form |
|---|---|---|---|
| ✓ Done | Sections, code examples with captions | Section / Subsection / Text / Example Group / Example Caption | `## …`, `### …`, one-line caption ending in `:` right before the `wl` block |
| ✓ Done | 2-column / 3-column Definition Box | "2 Column" / "3 Column" → `2ColumnTableMod` / `3ColumnTableMod` | a 2-/3-column pipe table |
| ⚠ Lossy | Span First Column on a definition box | `TableSpanToggle[]` | (no equivalent - see Cross-cutting) |
| ✗ Missing | Annotate | "Annotate" | no md form |

## `Overview`

| Status | Gap | Palette button → action | Markdown form |
|---|---|---|---|
| ✗ Missing | The whole template | "New Overview Page" / "Generate Overview" / `TOCChapter`/`TOCSection`/`TOCSubsection`/`TOCSubsubsection` | no `Template: Overview` yet; the closest is a Guide page |

## `FunctionResource` (and the resource-system family: `Prompt`, `LLMTool`, `Example`, `Data`)

| Status | Gap | Toolbar button → action | Markdown form |
|---|---|---|---|
| ✓ Done | Definition + scraper-visible content | (any cell carries `"DefaultContent"`) | `## Definition` with `#\| file: path` inline |
| ✓ Done | Frontmatter slots | "Edit values" panel | YAML keys at the top |
| ✓ Done | Tests | `## Tests` section drops `VerificationTest` cells into the `VerificationTests` slot | one `wl` block per `VerificationTest[...]` |
| ✓ Done | Check / Preview | "Check" → `CheckDefinitionNotebook` / "Preview" → `PreviewResource` | `check.wls` / `build-out.wls` (the rendered twin) |
| ⚠ Lossy | Deploy ▾ submenu options (cloud public / cloud private / local / session-only) | `DeployResource[..., Local -> .., "Public" -> ..]` | `examples/build.wls` is the *public cloud* branch; the others are one-line variants |
| ⚠ Lossy | Submit / Submit Update | `SubmitRepository[nbo]` / `SubmitRepositoryUpdate[nbo]` | `ResourceSubmit` the scraped `ResourceObject` by hand |
| ✗ Missing | Excluded / Hidden cell tags | cell-tools toggles | `#\| eval: false` covers "don't run", not "scrape out" or "closed when published" |
| ✗ Missing | Reviewer comments / replies | "Insert comment for reviewer" / "Reply »" | n/a |

`Prompt`, `LLMTool`, `Example`, `Data` share the same shell - the same
gaps apply, with the slot names different (PromptTemplate /
ToolDescription+ToolFunction / Content / Content+Distribution).

## `Demonstration`

The most palette-dependent template; the Demonstrations toolbar adds its
own buttons on top of the resource-system shell.

| Status | Gap | Toolbar button → action | Markdown form |
|---|---|---|---|
| ✓ Done | Caption / Initialization / Manipulate / Snapshots / Details / References sections | every section drops into its `…Group` slot | `## Caption`, `## Initialization`, `## Manipulate`, `## Snapshots`, `## Details`, `## References` |
| ✓ Done | Snapshots that re-render the Manipulate at fixed control settings | "UPDATE THUMBNAIL & SNAPSHOTS" → `UpdateManipulateOutputs[..., True]` (re-renders the *current* live Manipulate state into the snapshot cells) | parameterised helper `demo[p1_:..., p2_:..., ...] := Manipulate[...]` in `## Initialization` + calls like `demo[v1, v2, ...]` with `#\| input: false` in `## Snapshots` |
| ⚠ Lossy | The button captures the *live*, currently-displayed Manipulate state | (same) | the markdown source can only call the helper at predeclared parameter tuples; an author who wants the exact snapshot they're looking at on screen must transcribe the control values into a `demo[…]` call |
| ✗ Missing | UPLOAD to demonstrations.wolfram.com | "UPLOAD" → opens a browser flow after `PreflightCheck` | `examples/build.wls` deploys the `.nb` to a public `CloudObject`; no automated Demonstrations-site submit |
| ✗ Missing | Test Image Size / Resize Notebook to Fit / Check Spelling | TOOLS dropdown items | author checks the rendered twin by eye |

## `ComputationalEssay`

| Status | Gap | Palette/toolbar | Markdown form |
|---|---|---|---|
| ✓ Done | Title / Author / Date / Abstract / sections / `CodeText` captions | the official `ComputationalEssayTemplate[]` button | frontmatter + `## …` sections + one-line `:`-terminated paragraph before each `wl` block |
| ⚠ Lossy | Notebook Analysis docked pod (the always-on "Notebook Analysis" panel an essay opens with) | injected by the template's StyleDefinitions | the converter inherits the same StyleDefinitions, so the panel is there when the `.nb` is opened in the FE; no md control over it |
| ✗ N/A | No Submit toolbar | (essays have none) | direct `CloudDeploy[NotebookGet[essay], Permissions -> "Public"]` (what `examples/build.wls` does) |

## `Paclet` (paclet repository)

| Status | Gap | Toolbar button → action | Markdown form |
|---|---|---|---|
| ✓ Done | Paclet metadata + Details + Examples + Hero Image | the resource-system shell + the Paclet-specific `## Hero Image` slot | frontmatter + `## Hero Image` whose first executable cell evaluates to the image |
| ⚠ Lossy | Choose button for an existing paclet directory | "Choose" → opens a directory picker | the markdown points at a paclet on disk via `Paclet:` frontmatter; the per-build command supplies the path |

## Quick "what to fix next" list

In rough priority order, the markdown side is missing:

1. `Template: Overview` (+ `TOC*` heading styles, plus a build-overview command).
2. A way to mark a cell **Excluded** (`#| excluded: true` → drops the cell from the scraped resource but keeps it in the source `.nb`) and **Hidden when published** (`#| hidden: true` → closed `CellOpen -> False` on the web page, open in the download).
3. Guide-page listing-layout option (`#| listing: oneline | inline | block` per `## Functions` block) so the author can choose the layout the "1 Line Function Listing" / "Inline Listing Toggle" buttons set.
4. An `## Annotations` convention (or `<annotate>…</annotate>` inline tag) for the rare `TooltipBox` cases.
5. A `TableSpan` option for the rare wide-first-column case (likely a YAML option on the table block - GFM can't express it in the table syntax itself).

The remaining gaps (Reviewer comments / Submit-to-repository button /
bulk paclet rewrites / TOOLS dropdown items) are either review-loop
ceremony or shell-script equivalents and don't need a markdown form.
