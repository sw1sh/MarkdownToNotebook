---
name: wolfram-tech-note
description: Author a Wolfram Language tech note / tutorial (a free-flowing prose-and-code documentation page, like the built-in tutorial/ pages) as a literate-markdown document and build it with MarkdownToNotebook. Use this whenever the user wants to write or generate a tutorial, a tech note, a how-to or walkthrough, or narrative documentation for a Wolfram paclet - prose interleaved with runnable examples - rather than hand-editing the DocumentationTools tutorial authoring notebook.
---

# Authoring a tech note (tutorial) in markdown

`MarkdownToNotebook` fills the DocumentationTools tech-note authoring notebook (which
`DocumentationBuild` turns into a `tutorial/` page) from a literate-markdown document
with the `TechNote` template. Unlike a symbol or guide page, a tech note has **no
fixed sections** - it is free-flowing prose and code, like a tutorial.

**Before authoring, read
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/doc-pages.md** -
the *Conventions across all doc pages* section there covers the rules shared
by Symbol, Guide, and TechNote pages (the `[Symbol]()` / backticks split,
italics for argument names, `EvaluateSeparator` for state-threading multi-part
tutorials, the `<!-- => ... -->` hints are author-only, the build-and-inspect
loop, the no-`Needs[…]` rule, headless rasterization, ...). The worked example
is the AccessibleColors tutorial at
https://github.com/sw1sh/AccessibleColors/blob/main/docs/Tutorials/DesigningAccessibleColorSchemes.md ;
model new tech notes on it.

Read first - the canonical guidelines (a tech note lives inside a paclet, so the
Paclet Repository rules apply to it):

- Paclet Repository, creating paclets: https://resources.wolframcloud.com/PacletRepository/creating-paclets
- Paclet Repository, submission guidelines: https://resources.wolframcloud.com/PacletRepository/guidelines
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

```
---
Template: TechNote
Name: TechNoteName
Title: A Readable Tech Note Title
Context: Publisher`PacletName`
Paclet: Publisher/PacletName
URI: Publisher/PacletName/tutorial/TechNoteName
Keywords: [keyword one, keyword two]
RelatedGuides: [GuideName]
RelatedTutorials: [OtherTechNote]
---
```

## Body

After the frontmatter, write the tutorial as ordinary markdown - the converter maps
it directly to documentation cell styles:

- `##` headings become `Section`s, `###` become `Subsection`s, `####` become
  `Subsubsection`s (a `#` Title is taken from the `Title` frontmatter).
- Blank-line-separated paragraphs become `Text`; `-`/`*`/`+` lines become items;
  pipe tables become grids; `![alt](path)` inlines an image.
- Fenced `wl` cells are evaluated and shown as `Input`/`Output`; record expected
  results in `<!-- => ... -->` comments. Give the `Context` frontmatter so the
  paclet loads and examples run. Tech-note example cells follow the same
  per-cell rule the resource pages use: one demonstration per cell,
  one-sentence `:`-terminated caption, `---` between siblings - see
  [docs/examples.md](https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/examples.md).

Structure the note as a narrative: lead with the problem, show the simplest
approach, then build up. Use concrete, runnable examples throughout. Inline math is
`$...$`, inline code is `` `code` ``, and `<code>[Range]()</code>` infers a
documentation link to a symbol's reference page. The `<code>` wrapper applies code
styling around the inferred-link (markdown viewers process markdown inside an
inline HTML element but not inside backticked code spans), and the empty parens
make pandoc / GitHub render the `[...]()` as a link element.

## Build

```
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["TechNoteName.md", "Documentation/English/Tutorials/TechNoteName.nb"]
```

Then build the paclet docs with `DocumentationBuild`, and list the tech note under
the paclet's guide / related pages (author those with the `wolfram-guide-page` and
`wolfram-paclet` skills).

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
