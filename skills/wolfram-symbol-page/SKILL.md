---
name: wolfram-symbol-page
description: Author a Wolfram Language symbol reference page (a function/symbol documentation page, like the built-in ref/ pages) as a literate-markdown document and build it with MarkdownToNotebook. Use this whenever the user wants to write or generate reference documentation for a Wolfram Language symbol or paclet function - the Usage, Details & Options, Examples, Scope, and Possible Issues of a `ref/` page - rather than hand-editing the DocumentationTools authoring notebook.
---

# Authoring a symbol reference page in markdown

`MarkdownToNotebook` fills the DocumentationTools symbol authoring notebook (which
`DocumentationBuild` turns into a `ref/` reference page) from a literate-markdown
document with the `Symbol` template. The worked examples are the symbol pages of
the AccessibleColors paclet at
https://github.com/sw1sh/AccessibleColors/tree/main/docs/Symbols ; model new pages
on them and read https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/doc-pages.md
for the structure.

A symbol page documents one symbol and belongs to a paclet (author the paclet with
the `wolfram-paclet` skill, the guide with `wolfram-guide-page`).

## Frontmatter

```
---
Template: Symbol
Name: SymbolName
Context: Publisher`PacletName`
Paclet: Publisher/PacletName
URI: Publisher/PacletName/ref/SymbolName
Keywords: [keyword one, keyword two]
SeeAlso: [RelatedSymbol, AnotherSymbol]
RelatedGuides: [GuideName]
---
```

`SeeAlso` and `RelatedGuides` are context-aware links: a **System** symbol links to
its system ref page, a paclet symbol to the paclet's ref page (the converter
resolves this). `URI` is the page's `ref/` path.

## Sections

- `## Usage` - one statement per paragraph beginning with a `` `code` `` span: the
  span is the signature (`` `SymbolName[x$1, x$2]` ``, arguments as `x$1`) and the
  rest is the description.
- `## Details & Options` - bullets become `Notes` cells; pipe tables become grids
  (use one for an options table). Link other symbols inline with `` [`Symbol`] ``.
- `## Basic Examples` then the extended sections `## Scope`, `## Options`,
  `## Applications`, `## Properties and Relations`, `## Possible Issues`,
  `## Neat Examples`. Each example is one computation; separate siblings in a
  section with a `---` line. A `### Heading` inside a section becomes an
  `ExampleSubsection` (one per option / sub-topic, as on real reference pages).

## Examples and outputs

A fenced `wl` cell is evaluated; record the expected result in an
`<!-- => ... -->` HTML comment after the cell (it documents the output and is
stripped from the page). To load the paclet so examples run, give the `Context`
frontmatter; the converter inserts the `Needs[...]` initialization. `#|` cell
options (`eval`, `screenshot`, `tear`, `flag`) work as elsewhere; inline math is
`$...$`.

## Build

```
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"];
mtn["SymbolName.md", "Documentation/English/ReferencePages/Symbols/SymbolName.nb"]
```

Then build the paclet docs with `DocumentationBuild`. DocumentationBuild drops (with
a warning) a See Also link whose ref page is missing from the local index - new
System symbols may warn locally yet resolve in a published environment.
