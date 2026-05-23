# Subtleties and gotchas

Hard-won details behind `MarkdownToNotebook` and the documentation / resource
tooling it drives. Each entry is a trap that cost real debugging; keep them in
mind when extending the converter or authoring docs. (Intended to seed a skill.)

## Wolfram-language traps

### `*` is a wildcard inside string patterns
A bare `"*"` in a `StringExpression` is the *wildcard metacharacter* (any run of
characters), not a literal asterisk. `StringMatchQ["abc def", ("-"|"*"|"+") ~~ " " ~~ ___]`
returns `True` because the `"*"` alternative matches `` `abc `` and then the space.
This silently mis-classified a Usage line as a markdown list item, so the Usage
slot was never filled. Fixes:
- match literal markers with explicit character checks
  (`MemberQ[{"-","*","+"}, StringTake[t,1]] && StringTake[t,{2}] === " "`), or
- wrap the literal in `Verbatim["*"]` (used for the `*italic*` rule).

### `BoxData` reparses a string label into a `RowBox`
`Cell[BoxData[ButtonBox["WCAG 2.1 guide", ...]], "InlineFormula"]` looks fine,
but the front end parses the `BoxData` contents as input, so the multi-word
label becomes `RowBox[{"WCAG"," ","2.1"," ","guide"}]`. The resource scraper's
hyperlink pattern is `ButtonBox[_String, ..., ButtonData -> {_, None}, ...]`, so
a `RowBox` label no longer matches and the link is reported `LinkNotFound`. Put
a labeled hyperlink's `ButtonBox` **directly in `TextData`** (not inside
`BoxData`) so the label stays a `String`.

### `ToBoxes[Defer[…]]` renders display heads; reparse for literal input
To turn a code *string* into an Input cell's boxes, parse it the way typing it
would: `MathLink`CallFrontEnd[FrontEnd`ReparseBoxStructurePacket[code]]`.
`ToBoxes[ToExpression[code, StandardForm, Defer]]` instead *renders* display
heads - `Framed`, `Style`, `Grid`, `Row`, `RGBColor` become frames/swatches - so
the Input cell shows a mangled half-rendered form (and the FE flags a box error).

### Scalar slots in held `TaggingRules` must not be `Sequence@@`-filled
A control's value (a license radio, a guide path) lives in a held `TaggingRules`
option. Filling it through the usual `TemplateSlot[n,o] :> Sequence @@ fillSlot[…]`
leaves a stray `Sequence[…]` wrapper in the held option (e.g.
`"RadioButtonValue" -> Sequence["MIT"]`), so the control never matches. Resolve
such scalar slots in a separate pass that substitutes the raw value directly.

### The license radio: copy a working notebook, don't reverse-engineer it
The `RadioButtonBox` value reads as a list (`{"MIT"}`), which is misleading. A
working definition notebook selects MIT with the cell tagging rule
`"RadioButtonValue" -> "MIT"` (the bare ID **string**), an empty CheckboxData
`"Checked" -> {}`, and the blob's `"Default"` left as an unresolved
`TemplateSlot`. So: set `SelectedLicenseID` to the string, and **leave the
serialized CheckboxData blob untouched** - rewriting `Checked` or resolving the
blob's `TemplateSlot`s does *not* help and diverges from what works. When a
control's encoding is opaque, diff a known-good notebook instead of guessing.

### Separate examples with an explicit `---`, never automatically
An example is one computation, not a list of results. Separate sibling examples
within a section with an **explicit** thematic-break line (`---` or `___` between
blank lines) - it becomes a `Cell["\t", "ExampleDelimiter"]` and restarts the
`In[]`/`Out[]` numbering at 1. Do **not** insert delimiters automatically (e.g. on
each new prose lead-in): that guesses example boundaries and is surprising; let the
author mark them. Detect the break by explicit character checks - in a string
pattern a bare `"*"` is the wildcard, so `StringMatchQ[t, "*"..]` matches anything.
A `Dynamic`/`Manipulate` example in a resource notebook draws a `RasterizeDynamics`
suggestion - benign; publishing rasterizes it.

### Guide function listing: the "1-Line Function" template
A `## Functions` entry must match the docked **1-Line Function** button's output:
`Cell[TextData[{<chip>, " \[LongDash] ", <description>}], "GuideText"]`, where the
chip is `Cell[BoxData[ButtonBox[name, BaseStyle->"Link", ButtonData->"paclet:…/ref/name"]], "InlineGuideFunction", TaggingRules->{"PageType"->"Function"}]`.
The `" \[LongDash] "` (em-dash, spaces both sides) separator between the chip and
the description is required - omitting it is the usual formatting mistake. The
template is `DocumentationTools`Private`$OneLineFunctionTemplate`.

### Prose links are a bare ButtonBox in TextData
An inline `[text](url)` link, a Related Guide, or a Related Link must be a bare
`ButtonBox[text, BaseStyle->"Link"|"Hyperlink", ButtonData->…]` sitting directly
in the cell's `TextData`. Wrapping it in `Cell[BoxData[…], "InlineFormula"]`
renders the link text in code/formula style instead of as a prose link (the
symptom: "the link doesn't format"). A guide's `GuideMoreAbout`/`GuideRelatedLinks`
cell is `Cell[TextData[ButtonBox[name, BaseStyle->"Link", ButtonData->"paclet:…"]], style]`,
and the base guide template has only the Related Links *section header* (no item
placeholder), so the link cells must be inserted after it. Guide links are
context-aware too: a related guide that is not the paclet's own (`Colors`,
`Accessibility`) is `paclet:guide/Name`. (Note: `Color` is not a guide; the
colors overview guide is `Colors`.)

### See Also links must be context-aware
A See Also / More About entry that names a **System** symbol (e.g.
`LightDarkSwitched`, `StandardRed`) links to its system ref page
(`paclet:ref/Name`), while a paclet symbol links to the paclet
(`paclet:Pub/Name/ref/Sym`). DocumentationBuild drops (with a warning) any See
Also link whose ref page is missing from the local doc index - new System
symbols may warn locally yet resolve in a full/published environment.

### Cache example outputs with the persistence framework, not a custom option
Cache evaluated example outputs with the built-in persistence framework - a
`PersistentSymbol[name, "Local"]` per cell, keyed by the cumulative hash - rather
than a custom `"Cache"` option and a `.wxf` file. An unset symbol reads back as
`Missing["Nonexistent", …]` (so `MissingQ` is the cache-miss test), it survives
sessions at the `"Local"` `PersistenceLocation`, and it is managed with the
standard tools: `PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]`
to list, `DeleteObject` to clear, `$PersistencePath`/`PersistenceLocation` to
relocate. (`PersistentValue` is obsolete - use `PersistentSymbol`.)

### Clear the cache when the package definition changes
The cache keys on a cumulative hash of the *code cells*, not the paclet
definitions. Changing a function's behavior (e.g. `WCAGLevel` returning
`Missing[…]` instead of `"Fail"`) with the example code unchanged reuses the stale
cached output - clear the persistent objects (above) before rebuilding.

### A `###` heading inside an example section is a subsubsection
`sectionsFrom` groups on headings of level ≤ 2, so a level-3 `### Title` stays a
block *inside* the section. Render it as a subsubsection (`"Subsubsection"` in a
resource notebook, `"ExampleSubsection"` on a doc page) so each option / sub-topic
gets its own heading like reference pages in the wild; the heading also separates
examples, so reset the `In[]`/`Out[]` counter at it without an `ExampleDelimiter`.

### Demonstrate a fenced cell with an escaped-newline one-liner
To show ` ```wl … ``` ` inside an example (a string the converter then parses),
keep the whole call on **one physical line** using escaped `\n`, e.g.
`MarkdownToNotebook["` `` ``` `` `wl\nRange[5]^2\n` `` ``` `` `"]`. Real newlines
would put a bare ` ``` ` at the start of a line, which both the fence splitter and
GitHub read as a *closing* fence; a mid-line ` ``` ` inside a string literal is
safe because fence detection only triggers at the start of a line.

### "Paper Tear" is a cell option, not an image effect
The front end's Convert To > Paper Tear menu item runs `FE`PaperTearToggle[]`,
which just sets the cell option `BackgroundAppearance -> "PaperTear"` (read the
menu code in `…/SystemFiles/FrontEnd/TextResources/ContextMenus.tr` and
`GetFEKernelInit.tr`). It is **not** `ImageEffect[…, "TornFrame"]` (a different,
unrelated framing effect). So apply it by adding `BackgroundAppearance ->
"PaperTear"` to the Output/image cell, not by transforming the image.

### The resource Definition cell is `"Code"` + `InitializationCell -> True`
The inlined function definition goes in a `Cell[BoxData[code], "Code",
InitializationCell -> True, CellTags -> {"Function"}]` - a Code cell that runs on
load - not a plain `"Input"` cell.

### Markdown images resolve at the document base
`![alt](path)` and `![alt](path "papertear")` import the image (file or URL)
relative to the document, so resolve them in `resolveBlock` (which knows the base),
like a `#| file:` include - not in `inlineTextData`, which has no base. A
`"papertear"` title adds the `BackgroundAppearance -> "PaperTear"` cell option.

### The example section "Options" is for real options only
A reference page's `## Options` section documents function *options*, one
`### "Name"` subsubsection each. If the function has none, do not repurpose it -
put "different uses" (result forms, source kinds, every markdown knob) under
`## Scope`, each its own subsubsection, and drop `## Options` entirely.

### Rasterized images display at half size (DPI metadata)
`Rasterize[expr, ImageResolution -> 144]` makes an image whose `ImageDimensions`
(pixels) are 2x the layout points, but whose *displayed* size (`ImageSizeRaw` in
the boxes) is the original points - so a 1353x500 px image shows as 676x250. Any
size check that reads the displayed size sees half what you rasterized. Force a
deterministic size with `ImageResize`, and prefer a near-1:1 image so pixel and
point measurements agree.

## Inline templating (the "Template Input" button)

### Use the real transform, not a hand-rolled one
The palette's **Template Input** / **Just Format** button is
`DocumentationTools`FunctionTemplate`, which is coupled to the front-end
selection. The transform under it is
`DocumentationTools`Private`ParseTextTemplate[string, thisObject]` - call that
directly (inside `UsingFrontEnd`) for each `` `code` `` span. It applies the full
convention: arguments italic (`StyleBox[…,"TI"]`), `c$1` -> subscript, and leaves
the call head a plain `String` that `DocumentationBuild` linkifies at build time.
A hand-rolled splitter (and `GeneralUtilities`Code`PackagePrivate`fmtUsageString`,
which returns a flat box-string the build does **not** linkify) misses cases.

### Reserve `ParseTextTemplate` for usage signatures, parse prose code literally
`ParseTextTemplate` is built for **signatures** (`f[arg1, arg2]`): it italicizes
every identifier-like token - *including tokens inside string literals*. Run it on
real inline code and `ResourceFunction["…"]["doc.md"]` comes back with the string
mangled to `"…StyleBox[doc,"TI"]….md"`, and it eagerly links every System symbol
it knows (`Notebook`, `ResourceFunction`, …), so prose fills with ugly inline
links. So: use `ParseTextTemplate` only for the `UsageInputs` cells (pure
signatures, no strings), and parse prose `` `code` `` literally with
`ReparseBoxStructurePacket` (preserves strings, adds no italics or links).

### Linking only ever happens on backticked content
Auto-linking every recognized symbol is noise (and double-wraps: `ParseTextTemplate`
links a System symbol, then a re-link pass wraps it again into
`ButtonBox[ButtonBox[…]]`). So inline `` `code` `` is **never** linked, and a link
only ever applies to backticked content:

- `` [`Notebook`] `` (or the empty-target form `` [`Notebook`]() ``) - a backtick
  label with no real URL - infers the ref URL from the name (paclet context ->
  `paclet:Pub/Name/ref/Name`, System -> `paclet:ref/Name`) and renders a code-styled
  reference link. A bare `[Notebook]` with no backticks is **left as literal
  text** - never linked;
- `` [`WCAGContrastRatio`](paclet:Pub/Name/ref/WCAGContrastRatio) `` - an explicit
  URL with a `code`-wrapped label - is also a code-styled reference link;
- `[the docs](https://…)` - a plain label with an explicit URL - is an ordinary
  prose hyperlink (the author gave the URL, so it is intentional);
- frontmatter lists (`SeeAlso`, `Links`, `RelatedGuides`) supply the rest.

Order the `StringSplit` rules `[t](u)` **before** `` [`t`] `` so the URL form wins.
For a usage signature, still `stripLinks` (`//. ButtonBox[c_, ___] :> c`) the
`ParseTextTemplate` output so its own eager System links are removed.

### Every builder must run prose through `inlineTextData`
Inline markup (links, `` `code` ``, `*emphasis*`, `$math$`) only renders if the
prose is built with `inlineTextData`, not the raw string. The `Default`
style-map builder emitting `Cell[text, "Text"]` instead of
`Cell[TextData @ inlineTextData[text], "Text"]` is why a `` [`Range`] `` link (or
any inline formatting) shows as literal text when converting a plain string with
no frontmatter (which selects `Default`).

## Documentation pages

### Symbol pages have no `Description`
Unlike a Guide, a Symbol page's summary is its `## Usage` line; there is no
Description cell or frontmatter key.

### Extended example sections are counter cells
Under "More Examples", each `## Scope` / `## Options` / ... maps to an
`ExampleSection` cell of the form
`Cell[BoxData[InterpretationBox[Cell["Scope","ExampleSection"], $Line = 0;]], "ExampleSection", …]`.
The `InterpretationBox` resets the `In[]`/`Out[]` counter per section. To
populate one, wrap the counter cell plus its content in a `CellGroupData`. Drop
empty sections **and** the template's `XXXX` `ExampleSubsection` placeholders, or
`DocumentationBuild` fails (built pages omit empty sections).

### Categorization needs a URI row
The base reference-page template's Categorization section has Entity Type /
Paclet Name / Context but no URI cell; append one
(`Cell[uri,"Categorization",CellLabel->"URI"]`) from the `URI:` frontmatter.

### Building requires the front end
`DocumentationBuild`DocumentationBuildNotebook[None, nb]` must run inside
`UsingFrontEnd` (it resolves links / metadata via the FE). `FrontEndObject::notavail`
warnings during `Needs["DocumentationTools`"]` are benign as long as the
`ParseTextTemplate` output is correct.

## `CheckDefinitionNotebook` (resource definition notebooks)

### Calling it
- First argument must be `File[path]` or a `NotebookObject`, never a path string.
- Open the **saved** notebook as a `NotebookObject` (`NotebookOpen[path]`) so a
  `"Notebook"`-type paclet directory resolves to the file's own folder. From an
  unsaved/`File` form you get `Error / PacletDirectoryMissing` - that is the
  interactive **Choose** toolbar step, not a metadata bug.
- Pass `"CheckType" -> "Submit"` (or `"Deploy"`) to run the full hint set; the
  default returns only a subset. The first run primes the scrape cache, so run
  it twice and read the second result.
- The result is a `Dataset`; `Normal` gives rows with `Level` (Error / Warning /
  Suggestion), `Tag`, `Parameters`, `CellID`.

### Paclet hints and their fixes
| Tag | Fix |
|---|---|
| `NameMissingPublisherID` | `Name:` includes the publisher, e.g. `Wolfram/AccessibleColors` |
| `DescriptionEndsInPunctuation` | drop the trailing period from `Description:` |
| `UndeclaredSymbols` | list the symbols in `PacletInfo.wl`'s Kernel extension `"Symbols" -> {"Pub`Pkg`Sym", …}` |
| `SuggestedSourceURL` | add `SourceControlURL:` (the check suggests the git remote's URL) |
| `NoGithubRepoFound` | the `SourceControlURL` repo must actually exist - publish it (`gh repo create … && git push`) |
| `StringLink` | give related links as labeled hyperlinks - `Links: ["[label](url)"]`, rendered as a `ButtonBox` in `TextData` |
| `TextURL` | a raw URL in a text/citation cell should be a hyperlink (or dropped - it is usually already in `Links`) |
| `NotAValidSymbolName` (Related Symbols placeholder) | the Related Symbols slot reads `SeeAlso:`; fill it so the `XXXX`/placeholder text is replaced |
| description mismatch | `Description:` in the resource notebook must match `PacletInfo.wl`'s `"Description"` exactly |
| guide missing | `MainGuide` must be the **relative** path `Documentation/English/Guides/<Name>.nb`, not a bare guide name |

### Resource field encodings that bite
- **License radio**: the `RadioButtonBox` value is a one-element **list**
  (`{"MIT"}`, `{"Apache-2.0"}`, ...). Setting `SelectedLicenseID` to the bare
  string `"MIT"` leaves the radio unselected; the `RadioButtonValue` tagging rule
  must equal `{"MIT"}`.
- **Citations**: a `Sources` entry is one bibliographic citation. A naive
  `[...]` list parser splits on the comma *inside* the quoted citation - parse
  list items with a quote-aware splitter so internal commas survive.
- **PrimaryContext / MainGuidePage / license** are driven by scalar slots
  (`Context`, `MainGuidePageString`, `SelectedLicenseID`) through
  `TemplateExpression`/`TemplateIf` and `TaggingRules`, not by editing the visible
  control cell.
- **`MyPublisherID/MyPaclet`** strings left in the notebook are the template's ⓘ
  help-tooltip examples, not unfilled slots.

### `ReadNotebook` is lossy on layout boxes
`ReadNotebook` (and box->markdown export) renders the *visual* form, dropping
`Column`/`Framed`/`Spacer` wrappers and rendering args inline - so a perfectly
valid hero/code Input cell can look mangled in the markdown dump. Verify the cell
by `ToExpression`-ing its boxes, not by reading the exported markdown.

### Hero image (`HeroImage` slot)
- The slot holds graphics boxes (replaces the template's "Image Placeholder").
- Size limits (on `ImageDimensions` of the scraped image): each dimension in
  **[400, 1500] px**; aspect ratio `h/w` in **[0.5, 1.25]**. Out of range gives
  `HeroImageTooSmall` / `HeroImageTooLarge`, and out of the AR band gives
  `HeroImageSquashed` (too wide, `ar < 0.5`) / a stretched variant (`ar > 1.25`).
- Show the image **and** keep the generating code with the open-state idiom
  `Cell[CellGroupData[{Cell[code,"Input"], Cell[image,"Output"]}, {2}]]`: the
  `{2}` displays only cell 2 (the image) and collapses the code, and the scrape
  sees just the image. This is what working paclet definition notebooks do.
  (A `Closed` group, or any visible second cell, makes the scrape rasterize the
  collapsed code's width and trip `HeroImageSquashed`.)
- Generate with `ImageResize[Rasterize[…, ImageResolution -> 144], {Automatic, h}]`
  to pin the size; watch the half-size DPI effect above when reasoning about it.

### The Paclet template's slot names differ from the Function template's
The `DefinitionTemplate["Paclet"]` slots are **not** the Function template's
`Usage` / `Notes` / `Examples`. The Paclet uses:
- `Details` (style `Notes`) instead of `Notes`;
- `LongDescription` for the landing-page prose (there is no `Usage` slot);
- `ExampleNotebook` instead of `Examples`, and its example sub-sections are
  **literal `Subsection` / `Text` / `Input` / `Output` cells**, not a slot - only
  `PacletDirectory`, `Context`, and `ExampleInitialization` are nested
  `TemplateSlot`s inside it. So examples are filled by building the Subsection
  groups (keeping the `ExampleInitialization` group, which holds the
  `PacletDirectoryLoad` + `Needs` init cells) rather than by replacing a slot.

If `fillSlot` only handles the Function names, a Paclet notebook builds without
errors but is **empty of content** (the section titles are template defaults).
Map each Paclet slot explicitly.

### The template version follows the kernel's DefinitionNotebookClient paclet
`DefinitionTemplate[...]` bakes a `TemplateVersion` into the notebook from the
running kernel's `DefinitionNotebookClient`. If the kernel that builds is older
than the front end that opens it, `Check` flags the notebook as out of date.
Build with a current kernel (and `PacletInstall["DefinitionNotebookClient", UpdateSites -> True]`
as a safeguard); note that a custom `wolframscript` may point at a different
Wolfram installation (hence an older paclet) than your front end.

### `DeployResource` needs a `NotebookObject`, not `File[…]`
The docked Deploy > "Publicly in the cloud" action is
`DefinitionNotebookClient`DeployResource[rtype, notebook, "CloudPublic"]`, but
`notebook` must be an **open** `NotebookObject` - pass `File[nb]` and the call
returns unevaluated. Open it first:
`UsingFrontEnd @ Block[{nbo = NotebookOpen[File[nb]], r}, r = DefinitionNotebookClient`DeployResource["Function", nbo, "CloudPublic"]; NotebookClose[nbo]; r]`.

### Force light mode at *both* the notebook and the front-end session
Dark mode bites in two places. (1) Set the notebook option `LightDark -> "Light"`
(a Wolfram 14.2+/15 option; the value is the string `"Light"` - `Light`/`Dark` are
not System symbols) on the built `Notebook[…]`. (2) That alone is **not enough**:
the published page is regenerated through the local front end by `DeployResource`,
and a headless build session resolves the `Automatic` appearance to `Dark`
(`AbsoluteCurrentValue[CreateDocument[…], LightDark]` is `Dark`). So also pin the
session before deploying: `CurrentValue[$FrontEnd, LightDark] = "Light"`. Same for
any `Rasterize` of example output - bake `LightDark -> "Light"` into the rendered
`Notebook[…]` so the image is light regardless of the session.

### Show a produced notebook: both renderings are opt-in cell options
Faithfully splicing a produced notebook's **actual cells** works and is crisp -
the trick is to splice the real `Cell` expressions (Title, Text with inline TeX,
Section, Input/Output) into a **nested cell group** under the input
(`Cell[CellGroupData[{inputCell, Cell[CellGroupData[cells, Open]]}, Open]]`), not
to `RawBoxes` them (that silently drops Text/Input content) and not under the input
flat (that breaks layout). Rendering a notebook output is **opt in** via a `#|`
cell option (never automatic, never a default raster):

- `#| notebook_splice: true` -> frame splice (the cells, crisp). `outputBoxes`
  returns a `splicedNotebook[cells]` marker that `exampleIO` drops into the group.
- `#| screenshot: true` -> rasterize to an image; pair with `#| background:
  papertear` for the torn-paper screenshots under Applications/Neat.

With neither, the result is its normal output boxes (a bare `Notebook` expression,
what `MarkdownToNotebook[source]` returns, shows as itself). The option is named
`notebook_splice`, not `splice` (which is ambiguous).

### Self-referential examples need the converter's context on the path
Example cells evaluate in a private `$Context` with `$ContextPath` of just the
documented paclet's context + `System``. A document whose examples call
`MarkdownToNotebook` itself (this very file) would leave the call **unevaluated**
(the output shows the literal `MarkdownToNotebook[...]` code, or a raster of it) -
because `MarkdownToNotebook` lives in `Global`` (or wherever it was loaded), off
the path. Add `Context[MarkdownToNotebook]` to the example `$ContextPath`.

### `$...$` is TeX, parsed by the built-in Markdown importer
Inline `$math$` is **TeX**, not Wolfram code: `ImportString["$" <> tex <> "$",
"TeX"]` returns a `Notebook` whose `BoxData` is the typeset math (`SqrtBox`, …);
pull that out with `FirstCase[…, Cell[BoxData[b_], …] :> b]`. The Wolfram Language
also imports whole markdown documents itself - `Import[file, "Notebook"]` /
`ImportString[md, {"Markdown", "Notebook"}]` - which handles the same `$…$` TeX;
`MarkdownToNotebook` is the richer layer on top (templates, frontmatter metadata,
cell options, evaluated + cached examples).

### Layout comes from frontmatter; the result form is a positional argument
There is no `"Template"` option and no second function - the document's `Template`
frontmatter key is the single source of truth for layout, and `MarkdownToNotebook`
is the only entry point. Likewise there is no `"Output"` option: the result is
chosen by the optional second argument - omitted/`"Notebook"` returns the
`Notebook`, `"Association"` returns the parsed structure, and any other string is a
file path to write. Keeping the cases positional documents them as distinct usage
lines instead of hiding them in an option value.

### Drop the template's blank standalone usage placeholder
The Function template seeds an empty `UsageInputs` cell beside the `Usage` slot
(for a hand-typed second usage line). Once you fill all usage from the markdown it
renders as a blank line. Drop it - but match it by *content emptiness*
(`StringJoin[Cases[boxes, _String, Infinity]]` is whitespace), not a literal
`Cell[BoxData[], …]`: the template's `BoxData` is a context-shadowed symbol, so
the bare pattern silently misses it.

### `DefinitionMissing` headless = no CellIDs = an empty deployed resource
This is real, not an artifact. The resource scraper finds the definition (and
example) cells through `EvaluatableCells[nbo]`, which it matches **by `CellID`**.
A generated notebook expression has no `CellID`s, and the *headless* front end
does not assign them on `NotebookOpen` (the interactive front end does, the moment
you click into a cell - which is why deploying by hand from the desktop works).
So a headless `DeployResource` scrapes nothing, reports `DefinitionMissing`, and
deploys an **empty** resource whose `ResourceFunction[...][x]` comes back
unevaluated / `$Failed` with `DefinitionData` of length 0.

Fix: make the front end stamp the CellIDs before the scrape. Set
`CreateCellID -> True` on the notebook (the converter does this) and, in the
deploy, force one assignment pass:

```
nbo = NotebookOpen[File[outNb]];
CurrentValue[nbo, CreateCellID] = True;
SelectionMove[nbo, All, Notebook];
FrontEndTokenExecute[nbo, "Save"];   (* now every cell has a CellID *)
```

After this, headless `CheckDefinitionNotebook[nbo]` no longer reports
`DefinitionMissing` and the deployed `ResourceFunction` actually runs.

### Deploy with the docked button's own code, not a guessed overload
The docked **Deploy > Publicly in the cloud** button (in
`FunctionResourceDefinitionStyles.nb`) runs
`$ClickedButton = "Deploy"; $ClickedAction = "Publicly in the cloud";
DeployResource[notebook, "CloudPublic"]` - a **two**-argument
`DeployResource[nbo, "CloudPublic"]`. The three-argument
`DeployResource["Function", nbo, "CloudPublic"]` is a different overload that does
not scrape the definition; it deploys an empty resource. Copy the button code.

### Running the analysis and fixing content hints
`DefinitionNotebookClient`CheckDefinitionNotebook[nbo]` runs the same inspections
the Submit button does and returns a `Dataset` (rows of `Level` / `Tag` /
`Parameters` / `CellID`). This is the hint-correction workflow: deploy/submit runs
it automatically, so run it yourself first and clear the rows. Once CellIDs are
assigned (above) the content hints appear instead of `DefinitionMissing`:

| Tag | Fix (in the converter unless noted) |
|---|---|
| `ThreeDotEllipsis` | a literal `...` should be the `\[Ellipsis]` character; the prose pass rewrites `...` to `…`, but `...` inside an inline-code/`$...$` span must be reworded in the source |
| `ExtraWhitespace` | trim padding spaces - CommonMark keeps the spaces inside a `` `` `x` `` `` verbatim span, so `StringTrim` the span content |
| `FoundUnformattedCode` | a bare System-symbol word in prose (e.g. `Function`) reads as code; make it a hyperlink or reword |
| `LargeCellBounds/CellArea` | a cell (a full-notebook thumbnail) is too tall; cap it with a `CellSize` (the `#| tear:` option) or render it smaller |
| `InputExampleImage` | an example *input* cell rendered as an image; keep example inputs as real input boxes |

## Environment

### `wolframscript` here is a custom wrapper
The `wolframscript` on PATH is a thin wrapper: `-c`/`--code` for code, `-f FILE`
or a bare file argument to run a file, `-t SECONDS` for a timeout. The stock
flags `-script` / `-file` error out.

### Pushing to GitHub uses the wrong identity over HTTPS
The sandbox's HTTPS git credential helper authenticates as `nessie-agent`, which
has no write access, so an HTTPS push to a user repo returns 403. `gh` is logged
in as the user over **SSH**; set the remote to the SSH URL
(`git@github.com:user/repo.git`) to push. (`gh repo create` over the API still
works and creates the repo, which alone clears `NoGithubRepoFound`.)
