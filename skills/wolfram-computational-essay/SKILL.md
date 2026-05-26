---
name: wolfram-computational-essay
description: Author a Wolfram Computational Essay (Stephen Wolfram's narrative-and-code notebook genre, published on the Notebook Archive or Wolfram Cloud) as a literate-markdown document and convert it to a publishable notebook with MarkdownToNotebook. Use this whenever the user wants to write, draft, or publish a Wolfram computational essay, a narrative notebook, an explanatory notebook combining prose and computation - especially when they would rather write markdown than hand-edit notebook cells. Also use it when asked to add abstract, byline, or sections to such an essay.
---

# Authoring a Computational Essay in markdown

A **Computational Essay** (Stephen Wolfram, 2017) is an intellectual story told
in three interleaved voices: ordinary prose for context and motivation, short
Wolfram Language inputs that *advance* the story, and the explicit outputs
those inputs produce. Each code block is intentionally narrated by a
one-sentence caption (the "CodeText" style) that says what the next input
does. `MarkdownToNotebook` builds the produced notebook with the `Default.nb`
stylesheet, fills the title / byline / abstract from the frontmatter, and
promotes any one-line prose ending with `:` (right before a code block) to a
`CodeText` cell - the essay's canonical caption style. Use the
`ComputationalEssay` template.

Model new documents on the worked example -
https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/PiIsMostlyRandom.md
- and read https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-notebooks.md
(the "ComputationalEssay" section) for the slot mapping.

Read first - the canonical guidelines:

- *What Is a Computational Essay?* (Stephen Wolfram, 2017): https://writings.stephenwolfram.com/2017/11/what-is-a-computational-essay/
- *Steps to Writing a Computational Essay* (official guidelines): https://www.wolframcloud.com/obj/Expositions/Published/ComputationalEssayGuidelines
- *Computational Essays* collection on the Notebook Archive: https://www.notebookarchive.org/collection-pod?collection=computational-essays
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

Fence a `key: value` YAML header with `---` at the very top:

```
---
Template: ComputationalEssay
Name: The Catenary Hidden in a Hanging Chain
Author: Author Name
Date: 2026
Description: One-sentence summary for the listing page
Abstract: One short paragraph (~100 words) that sets the question, names the tools
  used, and previews the conclusion. Goes under the byline as the essay's Abstract
  cell.
Keywords: [keyword one, keyword two]
Sources: ["[Reference 1](https://...)"]
Links: ["[Related essay](https://...)"]
---
```

`Name` is the essay's title (Title Case is conventional). `Author` (or
`ContributedBy`) and `Date` together form the byline (`by Name • Date` in
Subtitle style). `Abstract` (or, lacking that, `Description`) becomes the
Abstract cell - keep it to about 100 words.

## Sections (each `## Heading` is a Section in the notebook)

The body has no required section names - structure it the way the essay
needs. The conventional shape:

- An introductory section that motivates the question.
- Several body sections, each one a *segment* of `Text + CodeText + Input + Output`:
  a sentence or two of context, then a one-line caption ending with `:` that
  describes what the code does, then the code itself, then its output.
- A closing section that summarises what was found and what was *not* shown.
- A `## References` section with one numbered reference per item.

A one-line prose paragraph ending with `:` *directly before* a code block is
automatically promoted to `CodeText` (the dim grey caption style that sits
flush against its `Input` cell). Multi-line paragraphs and prose that does not
end in `:` stay as ordinary `Text`. This means you can write the essay as
plain markdown and let the converter pick the right style:

```
Some context here about pi:

A glance at the first twenty digits:

```wl
Take[First @ RealDigits[Pi, 10, 10000], 20]
```
```

The first paragraph stays `Text`; the second (`A glance ...:`) becomes
`CodeText`.

## Code-cell options

A fenced `wl` cell carries `#|` option lines at the top (the Quarto cell-option
convention), one `key: value` per line: `eval: false` (show code without
running it), `file: path` (replace the body with a local file or URL),
`screenshot: true` (rasterize a produced `Notebook` to an inline image),
`tear: h` (torn-paper screenshot capped to `h` points). Record an example's
expected result in an `<!-- => ... -->` comment after the cell. Keep each
input to about three lines - the essay reads better when each code segment
is short enough to fit in a single mental scope. Inline math is `$...$`.
To link a documented symbol, wrap an inferred ref in `<code>`:
`<code>[Symbol]()</code>`.

## Build & deploy

```bash
wolframscript -f build.wls               # converts the .md to .nb
```

The notebook the converter writes is a plain `.nb` with the `Default.nb`
stylesheet, ready to upload to the [Notebook Archive](https://www.notebookarchive.org/),
publish on [Wolfram Community](https://community.wolfram.com/), submit as a
[Wolfram U](https://www.wolfram.com/wolfram-u/) capstone, or deploy as a
public `CloudObject` (`examples/build.wls` does the last automatically).
There is no resource-system scraper to satisfy, so a Computational Essay has
no `## Definition` section, no docked Submit toolbar, and no per-resource
metadata template - the notebook is the thing.

## Check

The `## Check` linter in the other resource skills does not apply here -
Computational Essays are plain notebooks, not resource definitions, so
`DefinitionNotebookClient`CheckDefinitionNotebook` returns an empty hint
list. The author's checklist instead:

- Title in Title Case.
- A byline and a ~100-word Abstract under it.
- Every code cell preceded by a one-line `:`-terminated caption.
- Inputs short (~3 lines each); outputs explicit (not hidden).
- A closing section that names what the essay did *not* prove.
- A `## References` section, items numbered `[1]`, `[2]`, ...
- The notebook re-opens cleanly in a fresh kernel (no stray `In[]` numbers,
  no `$Failed` outputs).
