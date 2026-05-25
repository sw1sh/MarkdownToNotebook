---
Template: FunctionResource
ResourceType: Function
Name: MarkdownToNotebook
Description: Convert a literate-markdown document into a Wolfram notebook using a template
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [markdown, literate programming, function repository, notebook, documentation, templates]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, CreateNotebook, DefineResourceFunction]
Links: ["[Wolfram/AccessibleColors - an example paclet authored entirely in markdown](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AccessibleColors/)", "[Source on GitHub](https://github.com/sw1sh/MarkdownToNotebook)", "[YAML front matter - the frontmatter convention](https://jekyllrb.com/docs/front-matter/)", "[Quarto cell options - the #| option syntax](https://quarto.org/docs/computations/execution-options.html)", "[CommonMark - the base markdown spec](https://commonmark.org/)"]
EntrySymbol: MarkdownToNotebook
---

This document is the source of truth for the resource function it describes.
The frontmatter above is the [Function Repository](https://resources.wolframcloud.com/FunctionRepository/) metadata; the Definition
section below inlines the implementation from a local `.wl` file; and the
example cells are evaluated (with caching) to build the resource's
documentation. Running the function on this very file reproduces its own
definition notebook, so it publishes itself.

## Definition

The implementation lives across three plain `.wl` files - a tiny shared module
that defines the stash protocol used by both this function and its inverse
([NotebookToMarkdown](https://github.com/sw1sh/MarkdownToNotebook/blob/main/NotebookToMarkdown.md)),
and the main forward converter. Each cell below inlines one file at conversion
time via the `file` option, a general mechanism: any code cell with `#| file: path`
is replaced by the contents of that local file or URL, resolved relative to
this document. The deployed resource therefore carries both files inline.

```wl
#| file: MarkdownTools.wl
```

```wl
#| file: MarkdownToNotebook.wl
```

## Details & Options

- The *source* is a local file path, an `http(s)` URL, or a raw markdown string.
- The layout is the document's own `Template` frontmatter key - `FunctionResource`, `Symbol`, `Guide`, `TechNote`, `Paclet`, `Example`, or `Default` - so the source declares its own layout.
- `FunctionResource` fills the official `FunctionResourceDefinition.nb` template (keeping its docked Deploy/Submit toolbar); `Symbol` and `Guide` fill the DocumentationTools authoring templates; `Default` maps headings and code to standard notebook styles.
- The *frontmatter* is a YAML-style `key: value` header fenced by `---` lines at the very top of the document - the [front matter](https://jekyllrb.com/docs/front-matter/) convention static-site generators use - carrying the resource metadata. Its keys mirror the chosen template's slots (`Name`, `Description`, `Keywords`, `Categories`, `ContributedBy`, `SeeAlso`, `Links`, and so on), so the author fills metadata, never cell styles.
- The optional second argument selects the result: omitted (or `"Notebook"`) returns the [Notebook](), `"Association"` returns the parsed structure, a `.nb` file name writes the notebook, and a `.md` file name writes a *markdown twin* - the same document with every evaluated output rasterized to an image beside it.
- The function takes two options:

| Option | Default | |
|---|---|---|
| `"Evaluate"` | `True` | evaluate the example cells and keep their output; `False` leaves them as input only, which a self-referential document passes to convert its own source without re-running its own examples |
| `"PreserveSource"` | `False` | with `True`, stash the original markdown source in `TaggingRules` so [NotebookToMarkdown]() recovers it verbatim (the notebook becomes self-contained: rendered view + source it came from); default is `False` so the notebook is a strictly-rendered artifact and the inverse falls back to its cell walker |

- A `Flag` frontmatter key flags the whole document and a code cell's `#| flag:` option flags that cell, with one of the documentation build's flags - `Future`, `Excised`, `Obsolete`, `Temporary`, `Preview`, or `Internal` - the front end's Futurize / Excise toolbar buttons, written as the build's banner cell.
- Evaluated example outputs are cached as a [PersistentSymbol]() per cell at the `"Local"` [PersistenceLocation](), keyed by a cumulative hash of the preceding cells, so re-runs reuse them across sessions.
- Manage that cache the standard way: [PersistentObjects]()["MarkdownToNotebook/ExampleOutput/*", "Local"] lists it, [DeleteObject]() clears it, and [$PersistencePath]() / [PersistenceLocation]() relocate it.
- The source lives on GitHub, which renders the markdown directly: [github.com/sw1sh/MarkdownToNotebook](https://github.com/sw1sh/MarkdownToNotebook).
- Running the function on this document - [Get]() the `.wl`, then `MarkdownToNotebook["MarkdownToNotebook.md", "MarkdownToNotebook.nb"]` - reproduces this very definition notebook; that is the loop `build.wls` runs.

Individual code cells carry their own options as `#|` comment lines at the top of the cell - the [Quarto](https://quarto.org/docs/computations/execution-options.html) cell-option convention - one `key: value` per line:

| Option | Effect |
|---|---|
| `eval` | evaluate the cell and keep its output (the default); `eval: false` shows the code without running it |
| `file` | replace the cell body with the contents of a local file or URL |
| `screenshot` | rasterize a produced notebook to an inline image |
| `tear` | render the output as a torn-paper screenshot; a number sets the visible height in points |
| `flag` | mark the cell with a build flag - `Future`, `Excised`, `Obsolete`, `Temporary`, `Preview`, or `Internal` |

## Usage

`MarkdownToNotebook[source]` converts a literate-markdown *source* into a Wolfram notebook and returns the [Notebook]() expression.

`MarkdownToNotebook[source, "Association"]` returns the parsed structure as an [Association]() instead of the notebook.

`MarkdownToNotebook[source, "file.nb"]` writes the notebook to the `.nb` *file* and returns the file.

`MarkdownToNotebook[source, "file.md"]` writes a markdown twin of the document, with each evaluated output rasterized to an image beside it, and returns the file.

## Basic Examples

Convert a markdown string into a notebook. The result is the explicit [Notebook]() expression:

```wl
MarkdownToNotebook["# Title\n\nA paragraph.\n\n## Section\n\nMore text."]
```

---

A whole notebook has no faithful inline form, so to show the produced notebook rendered in the documentation, the cell whose output is the notebook carries the `#| screenshot: true` option - which rasterizes the notebook to an image - and pairs it with `#| tear: N` to crop the image to the top `N` points with a torn-paper edge. Here both options sit *inside the markdown source* on a cell whose output is a literal [Notebook]() expression, so the syntax is visible alongside the rendered effect:

```wl
#| screenshot: true
MarkdownToNotebook["## Headline\n\n```wl\n#| screenshot: true\n#| tear: 100\nNotebook[{Cell[\"Hi\", \"Title\"], Cell[\"A paragraph.\", \"Text\"]}]\n```"]
```

---

Prose formatting, inline code, and lists all carry through:

```wl
#| screenshot: true
MarkdownToNotebook["# Notes\n\nA *key* idea, with inline `code`:\n\n- first\n- second\n- third"]
```

## Scope

The *source* is a file path, an `http(s)` URL, or a raw string, and the layout comes from the `Template` frontmatter key. The subsections below cover the markdown the converter understands and the results it returns.

### Frontmatter

A `---` - delimited block at the very top of the document is the *frontmatter*: `key: value` lines (a YAML-ish header) that carry the resource metadata - the `Name`, `Description`, `Template`, `Keywords`, and so on. Everything below it is content. Read the parsed metadata back with `"Association"`:

```wl
MarkdownToNotebook["---\nName: Demo\nTemplate: Default\nKeywords: [alpha, beta]\n---\n# Demo\n\ntext", "Association"]["Metadata"]
```

### Headings and prose

`#` becomes a `Title`, `##` a `Section`, `###` a `Subsection`; blank-line-separated paragraphs become `Text`:

```wl
#| screenshot: true
MarkdownToNotebook["# Title\n\n## Section\n\n### Subsection\n\nA paragraph of text."]
```

### Inline formatting

Inline `` `code` `` is formatted code; `*italic*` (or `_italic_`) is emphasis, `**bold**` (or `__bold__`) is bold, and `~~struck~~` is strikethrough; a double-backtick ``literal`` is a verbatim span and a `$x$` span is inline TeX math. A backslash escapes the next punctuation, and underscore emphasis is matched only at word boundaries so a `snake_case` name in prose is left untouched:

```wl
#| screenshot: true
MarkdownToNotebook["Inline `Range[3]`, *italic*, **bold**, ~~struck~~, ``verbatim``, and the math $\\sqrt{a^2 + b^2}$."]
```

### Display math

A `$$ … $$` block (on its own line, or fenced across lines) becomes a centered `DisplayFormula` cell - the standard style for a displayed equation:

```wl
#| screenshot: true
MarkdownToNotebook["The Pythagorean identity:\n\n$$ a^2 + b^2 = c^2 $$"]
```

### Links

Three link forms are supported:

- `[label](url)` makes a prose hyperlink.
- `` [Symbol]() `` infers a documentation reference (a backticked label with no target).
- `` [`Symbol`](url) `` makes a code-styled explicit link.

For example:

```wl
#| screenshot: true
MarkdownToNotebook["See [Range]() and the [Wolfram site](https://www.wolfram.com)."]
```

### Lists and tables

`-`, `*`, or `+` lines become bullet items, `1.`/`2.` lines a numbered list, and `- [ ]`/`- [x]` lines a task list (a ballot-box glyph); a GitHub-style pipe table becomes a grid:

```wl
#| screenshot: true
MarkdownToNotebook["1. first\n2. second\n\n- [x] done\n- [ ] todo\n\n| x | y |\n|---|---|\n| 1 | 2 |"]
```

### Blockquotes

Consecutive `>` lines become a quote, set off by a left rule and indent:

```wl
#| screenshot: true
MarkdownToNotebook["> A quoted remark,\n> carried across two lines."]
```

### Evaluated code cells

A fenced `wl` cell is evaluated and its output kept (then cached); a cell may carry options as `#| key: value` comment lines at the top - `#| eval: false` shows the code without running it, `#| screenshot: true` rasterizes a produced `Notebook` to an inline image, `#| tear: h` adds the torn-paper screenshot edge, `#| flag: …` marks the cell with a build flag, `#| file: path` replaces the body with the contents of a local file or URL. Two cells - one evaluated, one held - put the option syntax visibly in the markdown source:

```wl
#| screenshot: true
MarkdownToNotebook["## Evaluated\n\n```wl\nRange[5]^2\n```\n\n## Held\n\n```wl\n#| eval: false\nRange[5]^2\n```"]
```

### Inlining a file

A code cell whose first line is `#| file: path` is replaced by the contents of that local file or URL, resolved relative to the source - the mechanism the Definition section above uses to pull in `MarkdownToNotebook.wl`. Here a snippet written to disk is inlined and evaluated:

```wl
#| screenshot: true
Export[FileNameJoin[{$TemporaryDirectory, "snippet.wl"}], "Range[5]^2", "Text"]; NotebookPut[MarkdownToNotebook[Export[FileNameJoin[{$TemporaryDirectory, "inc.md"}], "## Inlined\n\n```wl\n#| file: snippet.wl\n```", "Text"]]]
```

### Inlining an image

A markdown image `![alt](path)` inlines an image - a local file or URL, resolved relative to the source. The image's *title* is a raw cell-style override: here `"ExampleImage"` styles the function's headline image (markdown in, a notebook out) as a documentation figure:

![MarkdownToNotebook: markdown in, a notebook out](docs/images/headline.png "ExampleImage")

The title defaults to `Output`; the special title `"papertear"` keeps `Output` and adds the front end's Convert To > Paper Tear cell effect for a torn-screenshot look (the same effect a code cell's `#| tear:` option gives its output, used under Applications below).

### Returning a notebook, an association, or a file

Omitted (or `"Notebook"`) returns the [Notebook](); `"Association"` returns the parsed structure for inspection; any other string writes the notebook to that file and returns it. The whole association exposes the notebook, the metadata, the section list, and the chosen template:

```wl
MarkdownToNotebook["---\nName: Demo\nKeywords: [alpha, beta]\n---\n# Demo", "Association"]
```

### Writing a markdown twin

Targeting a markdown file writes a GitHub-renderable *twin* of the document - the same prose and code, but with each evaluated output rasterized to a PNG beside it (under an `images/` folder next to the target). [`MarkdownToNotebook-out.md`](MarkdownToNotebook-out.md) in this repository is exactly that twin, produced this way. Here a small literate doc is converted to a twin and the resulting markdown read back, showing the output image spliced in after its code cell:

```wl
Module[{dir = CreateDirectory[]}, MarkdownToNotebook["## Squares\n\n```wl\nRange[5]^2\n```", FileNameJoin[{dir, "twin.md"}]]; Import[FileNameJoin[{dir, "twin.md"}], "Text"]]
```

### Flagging a document or cell

The documentation build's *flags* - the front end's Futurize / Excise toolbar buttons - mark a page or cell as `Future`, `Excised`, `Obsolete`, `Temporary`, `Preview`, or `Internal`. A `Flag` frontmatter key flags the whole document; a code cell's `#| flag:` option flags that one cell. Each becomes the build's banner cell at the top of the page. Here the same `#| flag:` option syntax used by the converter is visible inside the markdown source, applied to one cell of a tiny demo:

```wl
MarkdownToNotebook["## Demo\n\n```wl\n#| flag: future\nRange[5]^2\n```", "Association"]["Notebook"]
```

---

A paclet `Symbol` page with `Flag: Future` added to its frontmatter renders with the giant pink "FUTURE" banner the front end shows for unreleased pages:

```wl
#| screenshot: true
#| tear: 200
MarkdownToNotebook[StringReplace[
    Import["https://raw.githubusercontent.com/sw1sh/AccessibleColors/main/docs/Symbols/WCAGContrastRatio.md", "Text"],
    "---\nTemplate: Symbol" -> "---\nFlag: Future\nTemplate: Symbol"
]]
```

## Options

### Evaluate

By default every `wl` example cell is evaluated and its output kept. With the default, the converted notebook carries the evaluated output:

```wl
#| screenshot: true
MarkdownToNotebook["## Squares\n\n```wl\nRange[5]^2\n```"]
```

---

`"Evaluate" -> False` builds the notebook from the same source but leaves the example cells unevaluated - the input stays, the output is dropped. A self-referential document (one whose example converts its own source) passes it so converting itself does not re-run its own examples without end:

```wl
#| screenshot: true
MarkdownToNotebook["## Squares\n\n```wl\nRange[5]^2\n```", "Evaluate" -> False]
```

### PreserveSource

By default the produced notebook is a strictly-rendered artifact - the `TaggingRules` it carries hold only the resource template's own metadata. The inverse, [NotebookToMarkdown](), falls back to its cell walker to reconstruct markdown from the rendered cells:

```wl
FreeQ[MarkdownToNotebook["## Demo\n\nA paragraph."], "MarkdownToNotebook" -> _]
```

---

Pass `"PreserveSource" -> True` to stash the original markdown source under `TaggingRules -> {…, "MarkdownToNotebook" -> <|"Source" -> …, "Template" -> …|>}`. The notebook then becomes self-contained (rendered view + the source it came from in one file), and the inverse recovers the source verbatim for an exact round trip:

```wl
First[Cases[MarkdownToNotebook["## Demo\n\nA paragraph.", "PreserveSource" -> True], ("MarkdownToNotebook" -> v_) :> v, Infinity], <||>]
```

## Applications

`MarkdownToNotebook` fills every Wolfram Repository definition notebook from plain markdown, so authors never edit notebook cell styles by hand. The samples below live under [`examples/`](https://github.com/sw1sh/MarkdownToNotebook/tree/main/examples) in the repository; `examples/build.wls` builds each one and `DeployResource`-style `CloudDeploy[ResourceObject[nb], …, Permissions -> "Public"]`s it under a stable public URL, so every link below resolves to the live deployed notebook.

### Function Resource

The [`ReverseAddSequence`](https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/ReverseAddSequence.md) document is a complete [Function Repository](https://resources.wolframcloud.com/FunctionRepository/) submission - usage signature, examples, options, and the function body itself - kept in one markdown file. Converting it fills the official `FunctionResource` notebook with its docked Deploy/Submit toolbar, and the build step deploys it [publicly to the cloud](https://www.wolframcloud.com/obj/nikm/DeployedResources/FunctionResource/ReverseAddSequence). The `#| screenshot: true` cell option rasterizes the produced notebook and `#| tear: 200` gives it a torn-paper screenshot look, keeping the top 200 points of output visible above the tear:

```wl
#| screenshot: true
#| tear: 200
MarkdownToNotebook["https://raw.githubusercontent.com/sw1sh/MarkdownToNotebook/refs/heads/main/examples/ReverseAddSequence.md"]
```

### Paclet

The published [Wolfram/AccessibleColors](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AccessibleColors/) paclet - `PacletInfo.wl`, the guide page, every symbol reference page, and the Paclet Repository submission notebook - is built this way end to end. Here its guide page is converted straight from the markdown on [GitHub](https://github.com/sw1sh/AccessibleColors):

```wl
#| screenshot: true
#| tear: 200
MarkdownToNotebook["https://raw.githubusercontent.com/sw1sh/AccessibleColors/main/docs/Guides/AccessibleColors.md"]
```

### Example

The `Example` template fills the [Example Repository](https://resources.wolframcloud.com/ExampleRepository/) definition notebook. The [`PrimeSpiralPoints`](https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/PrimeSpiralPoints.md) sample ships a `"Points"` content element and a short gallery of derived plots; deployed [here](https://www.wolframcloud.com/obj/nikm/DeployedResources/Example/PrimeSpiralPoints):

```wl
#| screenshot: true
#| tear: 200
MarkdownToNotebook["https://raw.githubusercontent.com/sw1sh/MarkdownToNotebook/refs/heads/main/examples/PrimeSpiralPoints.md"]
```

---

The [Discrete-Time Quantum Walk](https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/QuantumWalk.md) sample is a longer Example doc: it derives the Hadamard-coin walk, plots the two-horned interference distribution against the classical Gaussian, and bundles the simulator as a `"Step"` content function; deployed [here](https://www.wolframcloud.com/obj/nikm/DeployedResources/Example/Discrete-TimeQuantumWalkonaLine):

```wl
#| screenshot: true
#| tear: 200
MarkdownToNotebook["https://raw.githubusercontent.com/sw1sh/MarkdownToNotebook/refs/heads/main/examples/QuantumWalk.md"]
```

### Data

The `Data` template fills the [Data Repository](https://resources.wolframcloud.com/DataRepository/) definition notebook. The [Seventeen Wallpaper Groups](https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/WallpaperGroups.md) sample bundles the classification table, the point-group and lattice columns, and a worked Euler-characteristic check; deployed [here](https://www.wolframcloud.com/obj/nikm/DeployedResources/Data/SeventeenWallpaperGroups):

```wl
#| screenshot: true
#| tear: 200
MarkdownToNotebook["https://raw.githubusercontent.com/sw1sh/MarkdownToNotebook/refs/heads/main/examples/WallpaperGroups.md"]
```

### Prompt

The `Prompt` template fills the [Prompt Repository](https://resources.wolframcloud.com/PromptRepository/) definition notebook for one of three resource types - `Persona`, `Function`, or `Modifier`. The [`AdaLovelace`](https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/AdaLovelace.md) sample is a Persona prompt whose `## Prompt` section is the system message and whose `## Chat Examples` and `## Basic Examples` invoke the persona through [LLMSynthesize]() and [ChatEvaluate](); deployed [here](https://www.wolframcloud.com/obj/nikm/DeployedResources/Prompt/AdaLovelace):

```wl
#| screenshot: true
#| tear: 200
MarkdownToNotebook["https://raw.githubusercontent.com/sw1sh/MarkdownToNotebook/refs/heads/main/examples/AdaLovelace.md"]
```

### Demonstration

The `Demonstration` template fills the [Demonstrations Project](https://demonstrations.wolfram.com/) authoring notebook, complete with its docked HELP / SAVE / UPDATE THUMBNAIL AND SNAPSHOTS / TEST IMAGE SIZE / UPLOAD toolbar. The [Bloch Sphere with a Quantum Gate Sequence](https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/BlochSphereGates.md) sample uses one `## Caption` paragraph, the `## Initialization` definitions (the gate matrices and the Bloch projection), a single `## Manipulate` cell, and three `## Snapshots` panels - the structure the Demonstrations review requires:

```wl
#| screenshot: true
#| tear: 200
MarkdownToNotebook["https://raw.githubusercontent.com/sw1sh/MarkdownToNotebook/refs/heads/main/examples/BlochSphereGates.md"]
```

## Properties and Relations

The Wolfram Language already reads markdown into a plain notebook - <code>[Import]()["doc.md", "Notebook"]</code>, or <code>[ImportString]()[markdown, {"Markdown", "Notebook"}]</code> for a string. `MarkdownToNotebook` builds on that idea and adds the resource layer: the layout chosen from frontmatter, the metadata slots, cell options, and evaluated and cached example cells. The built-in import of the same snippet gives just the bare cells (it does parse inline TeX math, the same `$x$` convention used here):

```wl
ImportString["# Title\n\nText with inline math $\\sin x$.", {"Markdown", "Notebook"}]
```

`FunctionResource` then fills the same template [CreateNotebook]()["FunctionResource"] opens (publishable with [ResourceSubmit]()), and `Symbol`/`Guide` fill the DocumentationTools templates `DocumentationBuild` turns into reference pages.

## Possible Issues

A string that is neither a URL nor an existing file is treated as raw markdown, so a mistyped path silently parses as content rather than erroring:

```wl
MarkdownToNotebook["nonexistent.md", "Association"]["Sections"]
```

## Neat Examples

The neatest example is this very document: running the function on its own GitHub source produces the notebook itself, the one you are reading (its `## Definition` even inlines `MarkdownToNotebook.wl` from the same GitHub directory, so the one URL is self-contained). The example converts its own source, so it passes `"Evaluate" -> False` to leave that copy's example cells unevaluated rather than re-run this very example without end:

```wl
NotebookPut[MarkdownToNotebook["https://raw.githubusercontent.com/sw1sh/MarkdownToNotebook/refs/heads/main/MarkdownToNotebook.md", "Evaluate" -> False]]
```

Because this very document is itself such a literate source - its `## Definition` inlines `MarkdownToNotebook.wl` and its frontmatter is the resource metadata - running the function on it reproduces this definition notebook, so the function publishes itself.

## Tests

Each `wl` cell in this section is an explicit `VerificationTest[code, expected, TestID -> …]` expression that becomes one Input cell in the resource's `VerificationTests` slot (the docked *Run Tests* button evaluates them). These are the regressions the converter has hit; `tests.wls` in the repo runs the same cells out-of-band by parsing this section, so the in-notebook button and the CI script run the same assertions from a single source.

Basic conversion returns a `Notebook` expression:

```wl
VerificationTest[
    Head @ MarkdownToNotebook["# Hi\n\nA paragraph."],
    Notebook,
    TestID -> "basic conversion returns a Notebook"
]
```

A `<code>[Symbol]()</code>` reference in a Usage signature carries a paclet link on the head (regression: the link silently disappeared when the `<code>` rule was rewritten to wrap the whole span in one `InlineFormula` instead of recursing on the inside):

```wl
VerificationTest[
    ! FreeQ[
        MarkdownToNotebook["---\nTemplate: Symbol\nName: Range\nContext: System`\nPaclet: System\nURI: System/ref/Range\n---\n\n## Usage\n\n<code>[Range]()[$n$]</code> gives a list."],
        ButtonBox["Range", BaseStyle -> "Link", ___]
    ],
    True,
    TestID -> "<code>[Symbol]()…</code> in Usage carries a paclet link on the head"
]
```

A bullet list with indented continuation lines folds each continuation into the preceding item, so a three-bullet list with two-line continuations is three items, not six (regression: the list parser used to break at the continuation, producing alternating one-item lists and stray paragraphs):

```wl
VerificationTest[
    Length @ Cases[
        MarkdownToNotebook["## Demo\n\n- First bullet\n  that wraps.\n- Second bullet\n  also wraps.\n- Third bullet."],
        Cell[_, "Notes" | "Item" | "Bullet", ___],
        Infinity
    ],
    3,
    TestID -> "multi-line bullets fold into single items (3, not 6)"
]
```

The `"PreserveSource"` option defaults to `False`, so a notebook the converter writes does *not* carry the source in its `TaggingRules`:

```wl
VerificationTest[
    FreeQ[MarkdownToNotebook["# Hi"], "MarkdownToNotebook" -> _],
    True,
    TestID -> "\"PreserveSource\" defaults to False - no stash in TaggingRules"
]
```

With `"PreserveSource" -> True`, the source is stashed under the `"MarkdownToNotebook"` tagging key and the inverse round-trips it byte-exactly:

```wl
VerificationTest[
    With[{src = "## Demo\n\nA paragraph.\n"},
        First[
            Cases[
                MarkdownToNotebook[src, "PreserveSource" -> True],
                ("MarkdownToNotebook" -> v_) :> v,
                Infinity
            ],
            <||>
        ]["Source"] === src
    ],
    True,
    TestID -> "\"PreserveSource\" -> True stashes the source under \"MarkdownToNotebook\""
]
```
