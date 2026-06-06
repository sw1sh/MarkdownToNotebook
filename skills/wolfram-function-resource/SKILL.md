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

The canonical worked example is the converter's own definition document,
https://github.com/sw1sh/MarkdownToNotebook/blob/main/MarkdownToNotebook.md (the
converter is its own resource). Model new documents on it, and read
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-notebooks.md and
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-guidelines.md for
the slot-by-slot mapping and the Function Repository style rules.

Read first - the canonical guidelines:

- Function Repository style guidelines (the rules a submission is reviewed against): https://resources.wolframcloud.com/FunctionRepository/style-guidelines
- Wolfram Language code style (4-space indent, naming, plot colors, no `For` / `AppendTo`, ...): https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

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

`Categories` fills a fixed checkbox group, so each entry must be one of the official
Function Repository categories (pick the one or few that fit; do not invent names):
Cloud & Deployment, Core Language & Structure, Data Manipulation & Analysis,
External Interfaces & Connections, Geographic Data & Computation, Graphs & Networks,
Knowledge Representation & Natural Language, Notebook Documents & Presentation,
Repository Tools, Social, Cultural & Linguistic Data, Strings & Text,
System Operation & Setup, User Interface Construction, Wolfram Physics Project.
Always set `Categories` - an empty checkbox group is a submission hint.

## Sections (each `## Heading` fills a slot)

- `## Definition` - the implementation. Inline a `.wl` file with a code cell whose
  first line is `#| file: path` (resolved relative to the document), so the code
  keeps full IDE/lint support. The cell carries the `"DefaultContent"` cell tag the
  scraper needs - the converter handles that.
- `## Usage` - one statement per paragraph. The canonical signature form wraps
  the whole signature in an inline `<code>` tag so markdown viewers process the
  nested markdown inside it (links, italics, math) while rendering the whole
  span in code style:

      <code>[MyFunction]()[*x*]</code> gives the foo.
      <code>[MyFunction]()[$x_1$, $x_2$]</code> gives indexed-arg form.

  GitHub and Pandoc render this as a code-styled clickable link (the symbol's
  ref page), then literal brackets, then italic *x* (or *x*₁, *x*₂ via math).
  The converter strips the `<code>` wrapper, peels the `[`Name`](…)` link down
  to the name, drops `*…*` italics around args, and rewrites `$x_i$` to the
  template form `x$i` before handing the signature to the usage template
  parser. Bare backtick / prose / hybrid forms still work as fallbacks.
- `## Details & Options` - bullets, each becomes a `Notes` cell; a markdown pipe
  table becomes a `TableNotes` grid (use it for an options table).
- Example sections, in order: `## Basic Examples` (start with the simplest use),
  then `## Scope`, `## Options`, `## Applications`, `## Properties and Relations`,
  `## Possible Issues`, `## Neat Examples`. The example-authoring rule
  (one demonstration per cell, one-sentence `:`-terminated caption,
  `---` between siblings, `### Heading` becomes a subsubsection) is
  documented once in [docs/examples.md](https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/examples.md) - follow it for every example
  section in a resource.
- `## Author Notes` - optional prose, fills the Author Information panel.
  **Required when the resource was drafted with help from an AI assistant**;
  see [the disclosure rule in resource-guidelines.md](https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-guidelines.md#ai-assisted-authoring-disclosure-author-notes).

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
is `$...$`. To link a documented symbol inline, wrap an inferred ref in `<code>`:
`<code>[Range]()</code>` - the empty parens make markdown viewers (pandoc, GitHub)
render it as a clickable link, and the `<code>` wrapper applies code styling around
that link (markdown forbids nested formatting inside backticked code spans, but
processes markdown *inside* an inline HTML element). The converter routes the
empty-URL link through `linkInferred` to a `paclet:` ref in the notebook; the
`-out.md` twin further rewrites it to the public web URL.

## Definition code conventions

The `## Definition` code is **plain top-level definitions, not a package** - no
`BeginPackage` / `Begin["`Private`"]`. A resource function is a single entry
symbol plus the private helper closure it transitively calls; on deployment the
resource captures that closure, and `MarkdownToNotebook` Gets the inlined cells
into a fresh private context, so wrapping the code in a package context is both
unnecessary and wrong. A large implementation can still be split into several
`#| file:` module cells - they are one flat definition set, loaded in order.

Issue messages with the **`ResourceFunctionMessage`** resource function, not
`Message`. Define the template on the entry symbol as usual, then issue it:

```
MyFunction::badarg = "The argument `1` is not valid.";

MyFunction[x_] := (
    ResourceFunction["ResourceFunctionMessage"][MyFunction::badarg, x];
    $Failed
) /; ! validQ[x]
```

`ResourceFunction["ResourceFunctionMessage"][sym::tag, args...]` attaches the
message to `ResourceFunction[...]` and prints the entry symbol without its
autogenerated deployment context, so the user sees
`ResourceFunction["MyFunction"]::badarg` rather than a
`` FunctionRepository`$<uuid>` `` symbol. Plain `Message` leaks that internal
context once the resource is deployed.

## Convert and deploy

```
(* convert markdown -> the definition notebook *)
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["MyFunction.md", "MyFunction.nb"]
```

To deploy publicly, do **not** rely on a headless `DeployResource` (it scrapes an
empty definition); scrape the notebook into a `ResourceObject` and `CloudDeploy` the
resulting `ResourceFunction` - see the deploy note in
https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/subtleties.md . Submit to
the repository with the docked Submit button or `ResourceSubmit`. Before submitting,
run `DefinitionNotebookClient`CheckDefinitionNotebook[nbo]` and clear its hints
(that doc lists the common ones and their fixes).

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
