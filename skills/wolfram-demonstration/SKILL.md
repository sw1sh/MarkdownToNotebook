---
name: wolfram-demonstration
description: Author a Wolfram Demonstration (a deployable interactive Manipulate-based visualization for the Wolfram Demonstrations Project) as a literate-markdown document and convert it to the official authoring notebook with MarkdownToNotebook. Use this whenever the user wants to create, write, draft, or publish a Wolfram Demonstration, an interactive Manipulate, an explorable visualization for demonstrations.wolfram.com - especially when they would rather write markdown than hand-edit notebook cells. Also use it when asked to add snapshots, caption, or metadata to such a Demonstration.
---

# Authoring a Demonstration in markdown

`MarkdownToNotebook` fills the official Wolfram Demonstrations authoring notebook
(the one *File > New > Demonstration* opens, with its docked HELP / EXAMPLE /
SAVE / UPDATE THUMBNAIL AND SNAPSHOTS / TEST IMAGE SIZE / UPLOAD toolbar) from a
literate-markdown document. A Demonstration is built around **exactly one**
`Manipulate[...]` expression that visualizes one concept; the deployable artifact
is a signed `.nbp` (a CDF the free Wolfram Player can run) plus its
auto-generated thumbnail and snapshots. The author writes YAML frontmatter and
`## section` headings; the converter chooses every cell style. Use the
`Demonstration` template.

Model new documents on the worked example -
https://github.com/sw1sh/MarkdownToNotebook/blob/main/examples/BlochSphereGates.md -
and read https://github.com/sw1sh/MarkdownToNotebook/blob/main/docs/resource-notebooks.md
(the "Demonstration" section) for the slot-by-slot mapping.

Read first - the canonical guidelines:

- Demonstrations Project authoring guidelines (the rules a submission is reviewed against): https://demonstrations.wolfram.com/guidelines.html
- Topics taxonomy (the menu Categories must come from): https://demonstrations.wolfram.com/topics.html
- *Create a Demonstration* workflow: https://reference.wolfram.com/language/workflow/CreateADemonstrationForTheWolframDemonstrationsProject.html
- Wolfram Language code style: https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

Fence a `key: value` YAML header with `---` at the very top:

```
---
Template: Demonstration
ResourceType: Demonstration
Name: My Title in Title Case
ContributedBy: Author Name
AuthorNames: Author Name      # one entry, or a list for multi-author submissions
Keywords: [keyword one, keyword two]
Categories: [Mathematics, Geometry]
RelatedDemonstrations: ["[Other Title](http://demonstrations.wolfram.com/OtherTitle/)"]
Links: ["[External resource](https://example.com)"]
SubmissionNotes: One sentence for the reviewer
---
```

`Name` is the page title; use Title Case with all major words capitalized, be
specific (`"Density Map for the 3n+1 Problem"`, not `"3n+1 Problem"`), and use
ASCII only - the URL slug is derived from it.

`Categories` should come from the official [Topics taxonomy](https://demonstrations.wolfram.com/topics.html);
the top-level branches are Mathematics, Computation, Physical Sciences,
Life Sciences, Business & Social Systems, Engineering & Technology,
Systems / Models / Methods, Art & Design, Creative Arts, Everyday Life, and
Kids & Fun (each with its own subtree).

## Sections (each `## Heading` fills a slot)

**Required**:

- `## Caption` - one short paragraph, three to five sentences, that explains what
  the Demonstration shows. Text only - no code, no graphics. Do not copy text from
  books or the web. This shows under the thumbnail on the published page.
- `## Initialization` - one `wl` cell with all helper definitions the Manipulate
  needs. Everything that is not part of `Manipulate[...]` itself must live here -
  the Manipulate cell should be the Manipulate and nothing else. Include
  `SaveDefinitions -> True` on the Manipulate whenever this section is non-empty.
- `## Manipulate` - one `wl` cell whose expression is exactly one `Manipulate[...]`.
  No nested Manipulates, no function that returns a Manipulate. The submission
  review rules forbid `InputField` and `Appearance -> "Open"`. Set
  `Appearance -> "Labeled"` on sliders that should show their numeric value, and
  pick `ImageSize -> {w, h}` so the panel does not jiggle as controls move.
- `## Snapshots` - three or more `wl` cells, each producing one Manipulate panel
  at a distinct parameter set (a static `Show[...]` / `Plot[...]` that reproduces
  what the Manipulate would render at those parameters is fine). The site requires
  *at least three* snapshots and they should illustrate the range of behavior.

**Optional**:

- `## Details` - extended description, formulas (inline math as `$...$`),
  variable definitions, snapshot captions. Text only - no code, no graphics.
- `## References` - one numbered reference per item. Book references go *Author,
  Title (italic), City: Publisher, year*; article references *Author, "Title",
  Journal (italic), Volume(Issue), year, pp. X-Y*.

## Manipulate authoring rules

These come straight from the Demonstrations review checklist; cells that violate
them will be rejected:

- **Exactly one** `Manipulate`, top level, not nested.
- **No `InputField`** and **no `Appearance -> "Open"`** controls.
- **Lower-case descriptive labels** on every control (`"number of subdivisions"`,
  not `"n"`). Only proper nouns and adjectives capitalized.
- **Fixed image size** - the Manipulate panel must not resize as controls move.
  Use `ImageSize -> {w, h}`, `PlotRange -> All`, `ImagePadding`, `Pane`, or
  `Spacers` to keep it stable. For 3D, `SphericalRegion -> True`.
- **Initialization stays in `## Initialization`** - never define a helper inside
  the Manipulate cell. Pair non-empty Initialization with `SaveDefinitions -> True`.
- **Localize** every control variable and helper with `Module` / `DynamicModule` -
  unlocalized variables cause cross-talk between panels.
- For slow updates, `SynchronousUpdating -> False`; for stuttering sliders,
  `ContinuousAction -> False`.

## Code-cell options

A fenced `wl` cell carries `#|` option lines at the top (the Quarto cell-option
convention), one `key: value` per line: `eval: false` (show code without running),
`file: path` (replace the body with a local file or URL), `screenshot: true`
(rasterize a produced `Notebook`), `tear: h` (torn-paper screenshot capped to `h`
points). The Manipulate cell is auto-evaluated and the rendered panel becomes the
Manipulate output below the Input cell, the way the front end shows it.

## Build & deploy

```bash
wolframscript -f build.wls               # converts the .md to .nb
```

The notebook the converter writes carries the same docked HELP / SAVE / UPDATE
THUMBNAIL AND SNAPSHOTS / TEST IMAGE SIZE / UPLOAD toolbar a hand-authored
Demonstration has. Click *UPDATE THUMBNAIL AND SNAPSHOTS* (it regenerates them
in place), then *UPLOAD* to send the `.nb` to the Demonstrations Project review
queue. Submissions are reviewed editorially - allow a few weeks. Successful
submissions are republished as a signed `.nbp` (CDF) at
`demonstrations.wolfram.com/<TitleCamelCase>/` with a thumbnail, snapshots,
caption, and your name.

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
