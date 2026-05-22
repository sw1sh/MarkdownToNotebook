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

The *source* can be a local file path, an `http(s)` URL, or a raw markdown string. The layout comes from the `Template` frontmatter key (`FunctionResource`, `Symbol`, `Guide`, `TechNote`, `Paclet`, or `Default`), and `MarkdownToResourceFunction[source]` is the `FunctionResource` specialization.

A single template registry drives the layout. `FunctionResource` fills the slots of the official `FunctionResourceDefinition.nb` template (preserving its docked Deploy/Submit toolbar); `Symbol` and `Guide` fill the DocumentationTools authoring templates (`ObjectName`/`Usage`/`Examples`, `GuideTitle`/`GuideAbstract` and so on); and `Default` maps headings and code directly to standard notebook styles. The frontmatter keys mirror each template's metadata, so the author never writes cell styles.

The following options can be given:

| option | default | description |
|---|---|---|
| `"Output"` | `Automatic` | what to return: `"Notebook"`, `"Association"` (the parsed structure), or `"File"` |
| `"Template"` | `Automatic` | override the `Template` frontmatter key |
| `"Cache"` | `True` | reuse cached example outputs instead of re-evaluating |
| `"CacheDirectory"` | `Automatic` | where the example-output cache is written |

With `Automatic` output, `MarkdownToNotebook[source]` returns a `Notebook` and `MarkdownToNotebook[source, target]` writes the file *target*.

This document and its `.wl` implementation live on GitHub, which renders the
markdown directly: [github.com/sw1sh/MarkdownToNotebook](https://github.com/sw1sh/MarkdownToNotebook).

To regenerate the definition notebook: get `MarkdownToNotebook.md` and
`MarkdownToNotebook.wl` from the repository, evaluate `Get["MarkdownToNotebook.wl"]`
to define the function, then `MarkdownToNotebook["MarkdownToNotebook.md", "MarkdownToNotebook.nb"]`.
The `#| file:` include in the Definition section pulls the code back in from the
`.wl`, the example cells are evaluated and cached, and the `FunctionResource`
template is filled, writing `MarkdownToNotebook.nb`. The whole loop (define from
markdown, convert, publish) is what `build.wls` runs.

## Usage

`MarkdownToNotebook[source]` converts a literate-markdown *source* into a Wolfram notebook and returns the `Notebook` expression.

`MarkdownToNotebook[source, target]` writes the notebook to the file *target* and returns the file.

## Basic Examples

Convert a markdown string into a notebook. With one argument the result is the `Notebook` itself:

```wl
MarkdownToNotebook["# Title\n\nA paragraph.\n\n## Section\n\nMore text."]
```

## Scope

A `#` heading becomes a `Title`, `##` a `Section`, and inline `` `code` `` and `*emphasis*` carry their formatting through to the cells:

```wl
MarkdownToNotebook["# Demo\n\nInline `code` and *emphasis* in a paragraph.\n\n## Notes\n\nA second section."]
```

## Options

`"Output"` controls the return value. The default `Automatic` returns a `Notebook` (or writes the file when a *target* is given); `"Association"` instead exposes the parsed structure for inspection:

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
