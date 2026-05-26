---
name: wolfram-guide-page
description: Author a Wolfram Language guide page (a paclet's documentation home page that lists its functions, like the built-in guide/ pages) as a literate-markdown document and build it with MarkdownToNotebook. Use this whenever the user wants to write or generate a guide page, a paclet landing/overview page, or a curated function index for a Wolfram paclet - rather than hand-editing the DocumentationTools guide authoring notebook.
---

# Authoring a guide page in markdown

`MarkdownToNotebook` fills the DocumentationTools guide authoring notebook (which
`DocumentationBuild` turns into a `guide/` page) from a literate-markdown document
with the `Guide` template. A guide page is a paclet's documentation home: an
abstract plus a curated, annotated list of the paclet's functions. The worked
example is the AccessibleColors guide at
https://github.com/sw1sh/AccessibleColors/blob/main/docs/Guides/AccessibleColors.md ;
model new guides on it and read
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/doc-pages.md .

Read first - the canonical guidelines (a guide page lives inside a paclet, so the
Paclet Repository rules apply to it):

- Paclet Repository, creating paclets: https://resources.wolframcloud.com/PacletRepository/creating-paclets
- Paclet Repository, submission guidelines: https://resources.wolframcloud.com/PacletRepository/guidelines
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

```
---
Template: Guide
Name: GuideName
Title: Guide Title
Context: Publisher`PacletName`
Paclet: Publisher/PacletName
URI: Publisher/PacletName/guide/GuideName
Description: One-line summary of the paclet
Keywords: [keyword one, keyword two]
RelatedGuides: [OtherGuide, Accessibility]
Links: ["[label](https://example.com)"]
---
```

`RelatedGuides` are context-aware: a guide that is not the paclet's own (e.g. a
System overview guide like `Colors`) links to `paclet:guide/Name`.

## Sections

- `## Abstract` - several sentences of context under the title. (If omitted, the
  `Description` frontmatter is used.)
- `## Functions` - a markdown list, one item per function, each
  `` `Symbol` description ``. Each item becomes a docked "1-Line Function" entry: a
  chip linking to the symbol's `ref/` page, an em-dash, and the inline-formatted
  description. The backticked symbol at the start is required for the link.

Group functions under `### Subheadings` if the guide has sections of related
functions. Keep the page a concise overview, not full documentation - the symbol
reference pages (the `wolfram-symbol-page` skill) carry the detail.

## Build

```
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["GuideName.md", "Documentation/English/Guides/GuideName.nb"]
```

Then build the paclet docs with `DocumentationBuild`. The guide is usually the
paclet's `MainGuide` (set that relative path in the paclet's frontmatter; author the
paclet with the `wolfram-paclet` skill).

## Check

Before submission, run the docked *Check* button (top of every resource
definition notebook) - it lints the document against the submission
guidelines and reports hints by level. Headless, the same lint runs through
`DefinitionNotebookClient`CheckDefinitionNotebook[nbo]` after stamping
CellIDs and saving (the headless build does not assign CellIDs, and the
scraper needs them to locate cells):

```wl
Needs["DefinitionNotebookClient`"]
UsingFrontEnd @ Block[{nbo = NotebookOpen[File["MyResource.nb"]]},
    CurrentValue[nbo, CreateCellID] = True;
    SelectionMove[nbo, All, Notebook];
    FrontEndTokenExecute[nbo, "Save"];
    Normal @ DefinitionNotebookClient`CheckDefinitionNotebook[nbo]
]
```

Each row is `<|"Level" -> ..., "Tag" -> ..., "Parameters" -> ...|>` with
`Level` one of `Suggestion` / `Warning` / `Error`. Common tags to address
before submission: `DescriptionTooLong` (shorten to under 128 chars),
`ExampleTextLastCharacter` (end an example caption with `:`),
`FoundUnformattedCode` (wrap a stray WL symbol in `` `backticks` `` or in
an inferred link with empty parens like `[Range]()` (substitute the actual symbol name for `Range`), `ThreeDotEllipsis` (use `…` not `...`),
`NotASystemSymbol` (link foreign function-repo names instead of formatting
them as system symbols), `LargeCellBounds/CellHeight` (rasterized output too
big - crop it with `#| tear: h` or shrink the source). The repo's
`check.wls` runs the same lint on every built `.nb` and prints a per-file
summary.
