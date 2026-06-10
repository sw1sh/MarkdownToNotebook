---
name: wolfram-symbol-page
description: Author a Wolfram Language symbol reference page (a function/symbol documentation page, like the built-in ref/ pages) as a literate-markdown document and build it with MarkdownToNotebook. Use this whenever the user wants to write or generate reference documentation for a Wolfram Language symbol or paclet function - the Usage, Details & Options, Examples, Scope, and Possible Issues of a `ref/` page - rather than hand-editing the DocumentationTools authoring notebook.
---

# Authoring a symbol reference page in markdown

`MarkdownToNotebook` fills the DocumentationTools symbol authoring notebook (which
`DocumentationBuild` turns into a `ref/` reference page) from a literate-markdown
document with the `Symbol` template.

**Before authoring, read
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/doc-pages.md** -
the *Conventions across all doc pages* section there covers the rules shared
by Symbol, Guide, and TechNote pages (the `[Symbol]()` / backticks split,
italics for argument names, `EvaluateSeparator` for state-threading, the
`<!-- => ... -->` hints are author-only, the build-and-inspect loop, the
no-`Needs[…]` rule, headless rasterization, ...). The worked examples are
the symbol pages of the AccessibleColors paclet at
https://github.com/sw1sh/AccessibleColors/tree/main/docs/Symbols ; model new
pages on them.

A symbol page documents one symbol and belongs to a paclet (author the paclet with
the `wolfram-paclet` skill, the guide with `wolfram-guide-page`).

Read first - the canonical guidelines (a symbol ref page lives inside a paclet, so
the Paclet Repository rules apply to it):

- Paclet Repository, creating paclets: https://resources.wolframcloud.com/PacletRepository/creating-paclets
- Paclet Repository, submission guidelines: https://resources.wolframcloud.com/PacletRepository/guidelines
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

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

- `## Usage` - one statement per paragraph. Usage lists only
  input/construction signatures — the `DownValues` forms `Sym[args]` that
  call the symbol to build a result. Instance application (`obj[input]`),
  property/method access (`obj["prop"]`), and parameter substitution are
  `SubValues` (behavior of an already-constructed object) and belong in
  `## Details` / `## Scope` / `## Properties and Relations` — never Usage.
  For an object-head symbol, an `obj[…]` action line in Usage is a category
  error. The canonical signature form wraps the whole signature in an inline
  `<code>` tag so markdown viewers process the nested markdown inside it
  (links, italics, math) while rendering the whole span in code style.
  Substitute the actual symbol and argument names; the examples below use a
  hypothetical `MyFunc[x_1, x_2]`:

      <code>[MyFunc]()[$x_1$, $x_2$]</code> gives the result, computed from $x_1$ and $x_2$.

  GitHub and Pandoc render this as a code-styled clickable link (the symbol's
  ref page - here, the `MyFunc` ref page), then literal brackets, then italic
  *x*₁, *x*₂. The converter strips the `<code>` wrapper, peels the
  `[`Name`](…)` link down to the name, drops `*…*` italics around args, and
  rewrites `$x_i$` to the template form `x$i` before handing the reconstructed
  signature to DocumentationTools' usage template-parser. Bare backtick /
  prose / hybrid forms still work as fallbacks.
- `## Details & Options` - bullets become `Notes` cells; pipe tables become grids
  (use one for an options table). Link another symbol inline by wrapping its
  *actual* name in the inferred-link form, e.g. `<code>[Range]()</code>` to
  link `Range`, `<code>[WCAGContrastRatio]()</code>` to link a paclet symbol -
  the literal name goes between the brackets, never the word "Symbol". Two
  things matter here: the empty parens (without them markdown viewers do not
  render the `[…]` as a link element), and the `<code>` wrapper (markdown
  forbids nested formatting inside backticked code spans, but processes
  markdown *inside* an inline HTML element - so the `[link]()` inside `<code>`
  renders as a clickable link with code styling). The converter strips the
  wrapper, routes the empty-URL link to a `paclet:` ref in the notebook, and
  the twin rewrites it to the public web URL.
- `## Basic Examples` then the extended sections `## Scope`, `## Options`,
  `## Applications`, `## Properties and Relations`, `## Possible Issues`,
  `## Neat Examples`. The example-authoring rule (one demonstration per
  cell, one-sentence `:`-terminated caption, `---` between siblings,
  `### Heading` becomes an `ExampleSubsection`) is documented once in
  [docs/examples.md](https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/examples.md) - follow it everywhere example cells appear.

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
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["SymbolName.md", "Documentation/English/ReferencePages/Symbols/SymbolName.nb"]
```

Then build the paclet docs with `DocumentationBuild`. DocumentationBuild drops (with
a warning) a See Also link whose ref page is missing from the local index - new
System symbols may warn locally yet resolve in a published environment.

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
