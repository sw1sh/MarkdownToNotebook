---
Template: FunctionResource
ResourceType: Function
Name: MarkdownToNotebook
Description: Convert a literate-markdown document into a Wolfram notebook using a template
ContributedBy: Nikolay Murzin
Keywords: [markdown, literate programming, function repository, notebook, documentation, templates]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, CreateNotebook, DefineResourceFunction]
Links: ["[Wolfram/AccessibleColors - an example paclet authored entirely in markdown](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AccessibleColors/)"]
EntrySymbol: MarkdownToNotebook
---

This document is the source of truth for the resource function it describes.
The frontmatter above is the Function Repository metadata; the Definition
section below inlines the implementation from a local `.wl` file; and the
example cells are evaluated (with caching) to build the resource's
documentation. Running the function on this very file reproduces its own
definition notebook, so it publishes itself.

## Definition

The implementation lives in a separate `.wl` file so it has full IDE and lint
support. The cell below inlines it at conversion time via the `file` option, a
general mechanism: any code cell with `#| file: path` is replaced by the
contents of that local file or URL, resolved relative to this document.

```wl
#| file: MarkdownToNotebook.wl
```

## Details & Options

- The *source* is a local file path, an `http(s)` URL, or a raw markdown string.
- The layout is the document's own `Template` frontmatter key — `FunctionResource`, `Symbol`, `Guide`, `TechNote`, `Paclet`, or `Default` — so the source declares its own layout.
- `FunctionResource` fills the official `FunctionResourceDefinition.nb` template (keeping its docked Deploy/Submit toolbar); `Symbol` and `Guide` fill the DocumentationTools authoring templates; `Default` maps headings and code to standard notebook styles.
- The frontmatter keys mirror each template's metadata, so the author never writes cell styles.
- The optional second argument selects the result: omitted (or `"Notebook"`) returns the `Notebook`, `"Association"` returns the parsed structure, and a file name writes the notebook to that file. There are no options.
- Evaluated example outputs are cached as a `PersistentSymbol` per cell at the `"Local"` `PersistenceLocation`, keyed by a cumulative hash of the preceding cells, so re-runs reuse them across sessions.
- Manage that cache the standard way: `PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]` lists it, `DeleteObject` clears it, and `$PersistencePath` / `PersistenceLocation` relocate it.
- The source lives on GitHub, which renders the markdown directly: [github.com/sw1sh/MarkdownToNotebook](https://github.com/sw1sh/MarkdownToNotebook).
- Running the function on this document — `Get` the `.wl`, then `MarkdownToNotebook["MarkdownToNotebook.md", "MarkdownToNotebook.nb"]` — reproduces this very definition notebook; that is the loop `build.wls` runs.

## Usage

`MarkdownToNotebook[source]` converts a literate-markdown *source* into a Wolfram notebook and returns the `Notebook` expression.

`MarkdownToNotebook[source, "Association"]` returns the parsed structure as an `Association` instead of the notebook.

`MarkdownToNotebook[source, file]` writes the notebook to *file* and returns the file.

## Basic Examples

Convert a markdown string into a notebook. The result is the explicit `Notebook` expression:

```wl
MarkdownToNotebook["# Title\n\nA paragraph.\n\n## Section\n\nMore text."]
```

Open the result with `NotebookPut` to see it rendered:

```wl
NotebookPut[MarkdownToNotebook["# Title\n\nA paragraph.\n\n## Section\n\nMore text."]]
```

Prose formatting, inline code, and lists all carry through:

```wl
NotebookPut[MarkdownToNotebook["# Notes\n\nA *key* idea, with inline `code`:\n\n- first\n- second\n- third"]]
```

## Scope

The *source* is a file path, an `http(s)` URL, or a raw string, and the layout comes from the `Template` frontmatter key. The subsections below cover the markdown the converter understands and the results it returns.

### Headings and prose

`#` becomes a `Title`, `##` a `Section`, `###` a `Subsection`; blank-line-separated paragraphs become `Text`:

```wl
NotebookPut[MarkdownToNotebook["# Title\n\n## Section\n\n### Subsection\n\nA paragraph of text."]]
```

### Inline formatting

Inline `` `code` `` is formatted code, `*emphasis*` is italic, a double-backtick ``literal`` is a verbatim span, and `$...$` is inline math:

```wl
NotebookPut[MarkdownToNotebook["Inline `Range[3]`, *emphasis*, ``verbatim``, and the value $Sin[x]$."]]
```

### Links

`[label](url)` is a prose hyperlink; a backticked label with no target — `` [`Symbol`] `` or `` [`Symbol`]() `` — infers a documentation reference; `` [`Symbol`](url) `` links explicitly:

```wl
NotebookPut[MarkdownToNotebook["See [`Range`] and the [Wolfram site](https://www.wolfram.com)."]]
```

### Lists and tables

`-`, `*`, or `+` lines become items, and a GitHub-style pipe table becomes a grid:

```wl
NotebookPut[MarkdownToNotebook["- one\n- two\n\n| x | y |\n|---|---|\n| 1 | 2 |"]]
```

### Evaluated code cells

A fenced `wl` cell is evaluated and its output kept (then cached); a cell may carry options such as `#| eval: false` to show code without running it:

```wl
NotebookPut[MarkdownToNotebook["```wl\nRange[5]^2\n```"]]
```

### Inlining a file

A code cell whose first line is `#| file: path` is replaced by the contents of that local file or URL, resolved relative to the source — the mechanism the Definition section above uses to pull in `MarkdownToNotebook.wl`.

### Returning a notebook, an association, or a file

Omitted (or `"Notebook"`) returns the `Notebook`; `"Association"` returns the parsed structure for inspection; any other string writes the notebook to that file and returns it:

```wl
MarkdownToNotebook["---\nName: Demo\nKeywords: [alpha, beta]\n---\n# Demo", "Association"]["Metadata"]
```

## Applications

Generate a paclet's entire documentation set, the guide page, the symbol reference pages, and a publishable Function Repository definition, from plain markdown, so authors never edit notebook cell styles by hand. The published [Wolfram/AccessibleColors](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AccessibleColors/) paclet is built this way end to end: its guide, four symbol reference pages, a tutorial, and the Paclet Repository definition notebook all come from the markdown in its `docs/` folder.

## Properties and Relations

`FunctionResource` fills the same template that `CreateNotebook["FunctionResource"]` opens in the front end, and the result is a `ResourceObject` definition notebook ready for `ResourceSubmit`. `Symbol` and `Guide` fill the DocumentationTools authoring templates that `DocumentationBuild` turns into reference pages.

## Possible Issues

A string that is neither a URL nor an existing file is treated as raw markdown, so a mistyped path silently parses as content rather than erroring:

```wl
MarkdownToNotebook["nonexistent.md", "Association"]["Sections"]
```

## Neat Examples

The `Template` frontmatter key alone switches the layout, so the same converter and source style yield a guide, a symbol page, or a plain notebook. Here the key selects the layout reported back:

```wl
MarkdownToNotebook["---\nTemplate: Guide\n---\n# Demo\n\ntext", "Association"]["Template"]
```
