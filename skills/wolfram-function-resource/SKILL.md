---
name: wolfram-function-resource
description: Author a Wolfram Function Repository resource (a deployable ResourceFunction) as a literate-markdown document and convert it to the official definition notebook with MarkdownToNotebook. Use this whenever the user wants to create, write, draft, or publish a Wolfram Language Function Repository function, a ResourceFunction, or a FunctionResource definition notebook - especially when they would rather write markdown than hand-edit notebook cells. Also use it when asked to add usage, examples, or metadata to such a function.
---

# Authoring a Function Repository resource in markdown

`MarkdownToNotebook` fills the official Function Repository definition notebook (the
one `CreateNotebook["FunctionResource"]` opens, with its docked Deploy/Submit
toolbar) from a literate-markdown document. The author writes YAML frontmatter and
`## section` headings; the converter chooses every cell style. Use the
`FunctionResource` template.

The canonical worked example is `MarkdownToNotebook.md` itself (the converter is its
own resource). Model new documents on it, and read `docs/resource-notebooks.md` and
`docs/resource-guidelines.md` in this repo for the slot-by-slot mapping and the
Function Repository style rules.

## Frontmatter

Fence a `key: value` YAML header with `---` at the very top. The keys mirror the
template's metadata slots:

```
---
Template: FunctionResource
ResourceType: Function
Name: MyFunction
Description: One-line, imperative, no trailing period
ContributedBy: Author Name
Keywords: [keyword one, keyword two]
Categories: [Category Name]
SeeAlso: [RelatedSymbol, AnotherSymbol]
Links: ["[label](https://example.com)"]
EntrySymbol: MyFunction
---
```

`Description` begins with an imperative verb and has **no** ending punctuation.
`Name` is the function's short name. `Links` items are markdown links inside quotes.

## Sections (each `## Heading` fills a slot)

- `## Definition` - the implementation. Inline a `.wl` file with a code cell whose
  first line is `#| file: path` (resolved relative to the document), so the code
  keeps full IDE/lint support. The cell carries the `"DefaultContent"` cell tag the
  scraper needs - the converter handles that.
- `## Usage` - one statement per paragraph that begins with a `` `code` `` span: the
  span is the signature (`` `MyFunction[x]` ``) and the rest is its description.
- `## Details & Options` - bullets, each becomes a `Notes` cell; a markdown pipe
  table becomes a `TableNotes` grid (use it for an options table).
- Example sections, in order: `## Basic Examples` (start with the simplest use),
  then `## Scope`, `## Options`, `## Applications`, `## Properties and Relations`,
  `## Possible Issues`, `## Neat Examples`. Each example is one computation;
  separate sibling examples in a section with a `---` line (a thematic break),
  which restarts the `In[]`/`Out[]` numbering. A `### Heading` inside an example
  section becomes a subsubsection.

## Code-cell options

A fenced `wl` cell carries `#|` option lines at the top (the Quarto cell-option
convention), one `key: value` per line:

- `eval: false` - show code without running it (default is to evaluate and cache).
- `file: path` - replace the cell body with a local file or URL.
- `screenshot: true` - rasterize a produced `Notebook` expression to an inline image.
- `tear: h` - a torn-paper screenshot capped to `h` points (implies the tear look).
- `flag: future|excised|...` - mark the cell with a documentation build flag.

To show a produced notebook as a thumbnail, return a `NotebookObject`
(`NotebookPut[MarkdownToNotebook[...]]`); the converter rasterizes it. Inline math
is `$...$`; `` [`Symbol`] `` (backticked, empty target) infers a documentation link.

## Convert and deploy

```
(* convert markdown -> the definition notebook *)
Get["MarkdownToNotebook.wl"];                 (* or use the deployed ResourceFunction *)
MarkdownToNotebook["MyFunction.md", "MyFunction.nb"]
```

To deploy publicly, do **not** rely on a headless `DeployResource` (it scrapes an
empty definition); scrape the notebook into a `ResourceObject` and `CloudDeploy` the
resulting `ResourceFunction` - see `build.wls` and the deploy note in
`docs/subtleties.md`. Submit to the repository with the docked Submit button or
`ResourceSubmit`. Before submitting, run `DefinitionNotebookClient`CheckDefinitionNotebook[nbo]`
and clear its hints (`docs/subtleties.md` documents the common ones and fixes).
