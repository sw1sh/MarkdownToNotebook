---
Template: FunctionResource
ResourceType: Function
Name: MarkdownToNotebook
Description: Convert a literate-markdown document (file, URL, or string) into a Wolfram notebook: a Function Repository definition, a documentation page, or a plain styled notebook, choosing the layout from a template and evaluating example cells with caching.
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

A single template registry drives the layout. `FunctionResource` fills the slots of the official `FunctionResourceDefinition.nb` template (preserving its docked Deploy/Submit toolbar); `Symbol` and `Guide` fill the DocumentationTools authoring templates (`ObjectName`/`Usage`/`Examples`, `GuideTitle`/`GuideAbstract` and so on); and `Default` maps headings and code directly to standard notebook styles. The frontmatter keys mirror each template's metadata, so the author never writes cell styles.

Read this document rendered online: [wolframcloud.com/obj/nikm/MarkdownToNotebook.md](https://www.wolframcloud.com/obj/nikm/MarkdownToNotebook.md), a self-contained page (the bootstrap deploys it) that renders this markdown with marked.js and offers a button to download the raw source (`.md` + `.wl`) as a zip; no third-party viewer and no cross-origin fetch.

To regenerate the definition notebook from that zip: extract `MarkdownToNotebook.md` and `MarkdownToNotebook.wl` into the same folder, evaluate `Get["MarkdownToNotebook.wl"]` to define the function, then `MarkdownToNotebook["MarkdownToNotebook.md"]`. The `#| file:` include in the Definition section pulls the code back in from the `.wl`, the example cells are evaluated and cached, and the `FunctionResource` template is filled, writing `MarkdownToNotebook.nb`. The whole loop (define from markdown, convert, publish) is what `bootstrap.wls` runs.

## Usage

`MarkdownToNotebook[source]` parses a literate-markdown `source`, which may be a local file path, an http(s) URL, or a raw markdown string. It picks a layout from the `Template` frontmatter key (`FunctionResource`, `Symbol`, `Guide`, or `Default`), evaluates the example cells with caching, and returns the notebook (writing it next to the source by default). `MarkdownToResourceFunction[source]` is the `FunctionResource` specialization. The option `"Output" -> "Association"` returns the parsed structure for inspection, and `"Cache" -> False` forces re-evaluation of every example cell.

## Basic Examples

Convert a raw markdown string into a notebook and count its cells:

```wl
Count[MarkdownToNotebook["# Title\n\nA paragraph.\n\n## Section\n\nMore text.", "Output" -> "Notebook"], _Cell, Infinity]
```

## Scope

The source can be a file path, an http(s) URL, or a raw string. Read back the parsed top-level sections:

```wl
MarkdownToNotebook["---\nTemplate: Default\n---\n## Alpha\n\nx\n\n## Beta\n\ny", "Output" -> "Association"]["Sections"]
```

## Options

`"Output"` controls the return value: a written file (default), the `Notebook` expression, or an `Association` for inspection, which exposes the parsed metadata:

```wl
MarkdownToNotebook["---\nName: Demo\nKeywords: [alpha, beta]\n---\n# Demo", "Output" -> "Association"]["Metadata"]
```

## Applications

Generate a paclet's entire documentation set, the guide page, the symbol reference pages, and a publishable Function Repository definition, from plain markdown, so authors never edit notebook cell styles by hand. The published [Wolfram/AccessibleColors](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AccessibleColors/) paclet is built this way end to end: its guide, four symbol reference pages, a tutorial, and the Paclet Repository definition notebook all come from the markdown in its `docs/` folder.

## Properties and Relations

`FunctionResource` fills the same template that `CreateNotebook["FunctionResource"]` opens in the front end, and the result is a `ResourceObject` definition notebook ready for `ResourceSubmit`. `Symbol` and `Guide` fill the DocumentationTools authoring templates that `DocumentationBuild` turns into reference pages.

## Possible Issues

A string that is neither a URL nor an existing file is treated as raw markdown, so a mistyped path silently parses as content rather than erroring:

```wl
MarkdownToNotebook["nonexistent.md", "Output" -> "Association"]["Sections"]
```

## Neat Examples

A `Template` option overrides the frontmatter, so one source can target several layouts:

```wl
MarkdownToNotebook["# X\n\ntext", "Output" -> "Association", "Template" -> "Default"]["Template"]
```
