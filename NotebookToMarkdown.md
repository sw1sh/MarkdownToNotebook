---
Template: FunctionResource
ResourceType: Function
Name: NotebookToMarkdown
Description: Recover a markdown approximation of a Wolfram notebook
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [markdown, literate programming, inverse, function repository, notebook, round trip]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, NotebookGet, MarkdownToNotebook]
Links: ["[MarkdownToNotebook - the forward converter](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/)", "[Source on GitHub](https://github.com/sw1sh/MarkdownToNotebook)"]
EntrySymbol: NotebookToMarkdown
---

`NotebookToMarkdown` is the inverse of [MarkdownToNotebook](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/). Given a notebook expression, a [NotebookObject](), or a `.nb` file path, it walks the cells and emits a markdown approximation - recognising the standard cell styles MarkdownToNotebook itself emits (Title / Section / ... / Text / Notes / Item / Input / Code / etc.) plus their inline `TextData` formatting.

## Definition

The implementation is a single plain `.wl` file, inlined here at conversion
time via the `#| file:` option; the deployed resource therefore carries it
inline:

```wl
#| file: NotebookToMarkdown.wl
```

## Usage

<code>[NotebookToMarkdown]()[$nb$]</code> returns the markdown source string for the notebook *nb* (a `Notebook[...]` expression, a [NotebookObject](), or a `.nb` file path).

<code>[NotebookToMarkdown]()[$nb$, "$file$.md"]</code> writes the markdown to *file* and returns the file path.

<code>[NotebookToMarkdown]()[$nb$, "DocPage" -> True]</code> recovers a *faithful* literate-markdown twin of a shipped DocumentationTools reference page (a `Symbol` / `Guide` / `TechNote` authoring notebook): YAML frontmatter, the verbatim typed Input code, Usage signatures, and the Notes / property tables, ready to rebuild with [MarkdownToNotebook](). A trailing `.md` target writes it.

## Details & Options

- The *nb* argument can be a [Notebook]() expression, a [NotebookObject]() open in the front end, or a string `".nb"` file path. The file form `Get`s the notebook off disk; the NotebookObject form `NotebookGet`s the live one.
- `NotebookToMarkdown` always walks the cells - it does not consult any `TaggingRules` stash a forward run might have left behind. Walker quality is therefore the function's responsibility and is exercised on every input.
- Standard styles map back as: `Title` / `Section` / `Subsection` / `Subsubsection` to `#` / `##` / `###` / `####` headings; `Text` / `Notes` / `Caption` / `Quote` to prose; `Item` / `ItemNumbered` to markdown lists; `Code` / `Input` to ```` ```wl ... ``` ```` fenced blocks; `Output` / `Message` are skipped (they regenerate on re-conversion).
- Inline `TextData` is converted back through the same backtick / bold / italic / link rules the forward parser accepts, so the produced markdown re-parses to an equivalent block sequence.
- The walker does not recover frontmatter or resource-template-specific slots from the rendered cells; the markdown it emits is the rendered body only.
- **`"DocPage" -> True`** switches to the *faithful doc-page* path, the reverse of MarkdownToNotebook's `Symbol` / `Guide` / `TechNote` authoring (see `docs/doc-pages.md`). Unlike the general walker it recovers: the **frontmatter** (from the `Categorization` / `Keywords` / `SeeAlso` / `MoreAbout` cells); the **verbatim typed Input code** via the front end's `InputText` export (preserving subscripts, `@`, `//`, `[[…]]`, `%`); **Usage signatures** as <code>[Sym]()[…]</code> spans; and the `Notes` / `2ColumnTableMod` / `3ColumnTableMod` cells as a `## Details & Options` section with pipe tables. It **requires a front end** (for `InputText`); the public entry wraps the call in [UsingFrontEnd]().
- **Table spec column rendering.** In the `2ColumnTableMod` / `3ColumnTableMod` tables, the left column is the literal thing you pass to the symbol. A bare-string spec (`"Bell"`) and a *subscript-free* call-form spec (`"Graph"[g]`, `qco["Diagram"]`) are both backticked as inline code, so the simple rows are uniform instead of a code-styled pill next to plain text. A spec that carries a 2D subscript (`"Multiplexer"[op_1,…]`, `"Liouvillian"[H,{L_1,…},{γ_1,…}]`) can't live in a code span, so it is rendered as a signature with canonical `$op_{1}$` math: a real typeset subscript that round-trips back to the `SubscriptBox`, rather than the linearized literal `Subscript[op, 1]` that backticking would produce.
- **Round-trip contract for signatures.** Subscripted arguments are emitted as canonical inline math with the base *inside* the math, `$obj_{i}$` — the form MarkdownToNotebook's `mathArgsToTemplate` round-trips to a clean subscript. The looser `*obj*$_i$` form (italic base + a separate `$_i$`) renders fine as raw markdown but round-trips *broken* (the forward parser only templates `$base_sub$` / `base~sub~` / `base<sub>sub</sub>`), so the doc-page path never emits it.
- **Three nb→md tools, three jobs.** Use the `nb-reader` skill's Python converter for quick *reading / comprehension* of any notebook (no kernel); the plain `NotebookToMarkdown[nb]` walker for an *approximate* body of an arbitrary notebook; and `NotebookToMarkdown[nb, "DocPage" -> True]` for a *faithful, rebuildable* twin of a shipped reference page. Only the last is round-trip-faithful for doc pages.
- Empty template sections (a placeholder `## Properties & Relations` with no content) are dropped, matching MarkdownToNotebook, which drops empty sections on build.

## Basic Examples

Walk a small notebook and recover the markdown body:

```wl
NotebookToMarkdown @ Notebook[{
    Cell["Demo", "Title"],
    Cell["A paragraph.", "Text"],
    Cell[BoxData["Range[5]^2"], "Input"]
}]
```

<!-- => "# Demo\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n" -->

## Scope

A `.nb` file path is read via `Get` and converted the same way:

```wl
NotebookToMarkdown[FileNameJoin[{$TemporaryDirectory, "no-such-file.nb"}]] === Null
```

<!-- => True (Null because the path does not exist; with a real file it returns the markdown) -->

## Properties and Relations

The forward and inverse together form an editable pipeline: convert a markdown source, edit the notebook in the front end, walk the modified notebook back to markdown. The walker reflects the *current* state of the cells, so hand edits survive the round trip. Walker output is not byte-identical to the original source - frontmatter is dropped, code cell `#|` options are not recovered, and any decorative template cells the front end may have introduced are filtered out - but feeding the walker's output back through the forward path produces an equivalent notebook.

## Possible Issues

Round-trip is *approximate*. The walker reads the rendered cells, not the original source, so:

- Frontmatter is not recovered (it lives in `TaggingRules`, not in cells).
- Code cell options (`#| eval: false`, `#| screenshot: true`, ...) are gone.
- Inline math and decorative formatting may serialize back to a simpler form.

For an arbitrary notebook the walker emits its best guess at the prose / heading / code structure; for a notebook MarkdownToNotebook itself wrote, the body is close to the source but the frontmatter must be added back by hand if needed.

### Doc-page mode (`"DocPage" -> True`): verify the output, and known failure classes

The faithful doc-page path renders far more than the general walker (frontmatter, verbatim code, signatures, tables), and a shipped reference page can carry box shapes that misrender silently. **Verify the generated `.md` source byte-by-byte** — do not trust a rendered preview (it caches, and these failures are invisible until they break KaTeX or dump raw boxes). Check all of:

- **code-cell count** — ` ```wl ` fences equal the nb's `Input`/`Code` cell count (mismatch ⇒ a dropped/truncated section);
- **section list** — the `##`/`###` headings match the nb's `ExampleSection`/`Subsection` list and order;
- **0 PUA glyphs** in the file (`0xE000–0xF8FF`) — a leftover is a dropped Wolfram glyph (script/gothic/double-struck letter);
- **0 orphan subscripts** — no `$…_{…}…$` with no base (`|_{+}_{+}\rangle` ⇒ KaTeX "double subscript");
- **0 prose box-leaks** — none of `StyleBox[`, `Cell[TextData`, `Cell[BoxData`, `RowBox[`, `GridBox[`, `Subscript[`, `\!\(` outside ` ``` ` fences;
- **0 malformed emphasis** — no `***`, `*]*`, `**}`;
- **round-trip** — `MarkdownToNotebook` on the result builds with no `Message` cells and clean subscripts.

Failure classes the converter now handles (recognize them in new pages):

- a **code signature authored inside a TraditionalForm `FormBox`** routes to `$…$` math, where literal `{}`/`[]` are invisible TeX grouping (braces vanish) and code shows italic → must be `<code>`;
- **deeply nested table cells** (`Cell[BoxData[Cell[TextData[…],"TableText"]]]`) → a `ToString` dump of the raw `Cell[…]`;
- **script/gothic letter glyphs** (`\[ScriptX]`, …) sit in the FE structural-PUA band → if dropped, a subscript base vanishes;
- **named math constants** (`\[ExponentialE]`, `\[ImaginaryI]`, `\[ImaginaryJ]`, `\[DifferentialD]`, `\[CapitalDifferentialD]`) also sit in that PUA band → if dropped, `e^{i 2 π λ}` collapses to an orphan `$^{2 π λ}$` (base `e` and exponent `i` deleted); they map to `e i j d D`;
- **Unicode Greek in math** (`\[Pi]`→`π`) is non-canonical TeX → the math leaf rewrites Greek glyphs to commands (`\pi`, `\lambda`, …) only inside `$…$`, never in prose;
- the **`*base*$_i$` subscript form** (italic base + separate `$_i$`) round-trips **broken** — only `$base_{i}$` re-templates;
- **Usage over-split** — split on the cell's `ModInfo` separators, not on every signature-like element (an inline symbol link in a description must not start a new statement);
- **TraditionalForm math fidelity is inherently lossy** — implicit-multiplication spacing (`2 ω`→`2ω`) and multi-letter functions (`Cos`→italic letters) don't survive box→TeX; target "readable & correct", not pixel-identical.

## Neat Examples

A round-trip smoke test: forward, walk, forward again, and check the second forward run produces a notebook with the same set of cell styles in the same order as the first - confirming the walker emits a faithful structural reduction even when byte-exact recovery is not possible:

```wl
With[{md = "# Demo\n\n## Section\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n"},
    Module[{nb1, md2, nb2, styles},
        nb1 = MarkdownToNotebook[md, "Evaluate" -> False];
        md2 = NotebookToMarkdown[nb1];
        nb2 = MarkdownToNotebook[md2, "Evaluate" -> False];
        styles[nb_] := Cases[nb, Cell[_, s_String, ___] :> s, Infinity];
        styles[nb1] === styles[nb2]
    ]
]
```

<!-- => True -->

## Tests

Each `wl` cell in this section is an explicit `VerificationTest[code, expected, TestID -> …]` expression that becomes one Input cell in the resource's `VerificationTests` slot (the docked *Run Tests* button evaluates them). The repo's `tests.wls` scrapes this section and runs the same assertions out-of-band, so the in-notebook button and the CI script share a single source of truth.

An `InlineFormula` cell wrapping a `FormBox` is emitted as `$math$`, not as a backticked code span, and in math mode a Wolfram Greek glyph becomes its canonical TeX command (`\[Theta]` -> `\theta`, not a raw Unicode `θ`) so the output is valid TeX rather than a literal codepoint (regression: the previous handler both wrapped every `InlineFormula` content in backticks, giving ``` `$θ$` ``` with extra delimiters, and left the Greek letter as Unicode):

```wl
VerificationTest[
    StringContainsQ[
        NotebookToMarkdown @ Notebook[{
            Cell[TextData[{"angle ", Cell[BoxData[FormBox["\[Theta]", TraditionalForm]], "InlineFormula"]}], "Text"]
        }],
        "$\\theta"
    ],
    True,
    TestID -> "InlineFormula+FormBox -> $math$ (no backticks)"
]
```

The named math constants `\[ExponentialE]`, `\[ImaginaryI]`, `\[ImaginaryJ]`, `\[DifferentialD]`, `\[CapitalDifferentialD]` occupy the same private-use band as the FE structural markers the converter drops, but they are content. They map to plain ASCII (`e`, `i`, `j`, `d`, `D`) before that drop, so a `SuperscriptBox["\[ExponentialE]", …]` keeps its base instead of collapsing to an orphan `$^{…}$` (regression: `e^{i 2 π λ}` rendered as a bare superscript `^{2 π λ}` with the base `e` and exponent `i` silently deleted):

```wl
VerificationTest[
    With[{md = NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"in the form ", Cell[BoxData[
            SuperscriptBox["\[ExponentialE]", RowBox[{"\[ImaginaryI]", " ", "2", "\[Pi]", " ", "\[Lambda]"}]]],
            "InlineFormula"]}], "Text"]
    }]},
        StringContainsQ[md, "$e^{i"] && StringContainsQ[md, "\\pi"] &&
            StringContainsQ[md, "\\lambda"] && ! StringContainsQ[md, "$^{"]
    ],
    True,
    TestID -> "math constants \[ExponentialE]/\[ImaginaryI] survive in a SuperscriptBox"
]
```

The left "spec" column of a doc table is the literal thing you type, so a subscript-free call-form (`"Graph"[g]`) renders as inline code just like a bare-string entry (`"Bell"`) - no mix of code-styled pill and plain text. A code span cannot hold a 2D subscript, though: a subscript-bearing spec (`"Multiplexer"[op_1,op_2,…]`) is rendered as a signature with canonical `$op_{1}$` math instead, which shows a real subscript and round-trips back to the `SubscriptBox` (backticking it would linearize `op_1` to the literal text `Subscript[op, 1]`):

```wl
VerificationTest[
    {
        gridCellMd["\"Bell\""],
        gridCellMd[RowBox[{"\"Graph\"", "[", StyleBox["g", "TI"], "]"}]],
        gridCellMd[RowBox[{"\"Mux\"", "[", SubscriptBox[StyleBox["op", "TI"], "1"], "]"}]]
    },
    {"`\"Bell\"`", "`\"Graph\"[g]`", "\"Mux\"[$op_{1}$]"},
    TestID -> "table spec column: simple specs inline-code, subscript specs canonical $math$"
]
```

A code cell's original surface layout is preserved by walking the `BoxData` tree directly - so a multi-statement Input cell with literal `"\n"` separators round-trips with its line breaks intact (regression: an earlier `MakeExpression`-based deparse choked on multi-statement boxes and fell back to literal `RawBoxes[RowBox[…]]` output):

```wl
VerificationTest[
    StringContainsQ[
        NotebookToMarkdown @ Notebook[{
            Cell[BoxData[RowBox[{RowBox[{"a", " ", "=", " ", "1"}], ";", "\n", RowBox[{"b", " ", "=", " ", "2"}], ";"}]], "Input"]
        }],
        "a = 1;\nb = 2;"
    ],
    True,
    TestID -> "multi-statement Input cell preserves the \"\\n\" between statements"
]
```

Decoration cells the resource template injects are silently dropped - the help-bubble opener that sits inside a heading's `TextData` is a `Cell[BoxData[PaneSelectorBox[…]]]`, never authored content, so the recovered heading is just the title (regression: the opener leaked through as raw box source jammed onto the heading line):

```wl
VerificationTest[
    StringTrim @ NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"Caption", Cell[BoxData[PaneSelectorBox[{True -> "x"}, Dynamic[True]]], "Section"]}], "Section"]
    }],
    "## Caption",
    TestID -> "drops MoreInfoOpener-shaped decoration cells from heading TextData"
]
```

A code signature authored inside a TraditionalForm `FormBox` renders as a `<code>` span, not `$math$` - in math mode its literal `{}`/`[]` would be invisible TeX grouping (braces vanish) and the code would show italic (regression: a `QuantumEvolve[H,{L1,...},...]` signature wrapped in a FormBox lost its list braces and rendered as big italic math):

```wl
VerificationTest[
    With[{md = NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"have ", Cell[BoxData[FormBox[RowBox[{"Foo", "[", RowBox[{"a", ",", "b"}], "]"}], TraditionalForm]]], " only"}], "Text"]
    }]},
        StringContainsQ[md, "<code>"] && ! StringContainsQ[md, "$Foo"]
    ],
    True,
    TestID -> "a code signature in a FormBox renders as <code>, not $math$"
]
```

A `Cell` nested several levels deep inside `BoxData` (a doc table cell can wrap its prose `Cell[BoxData[Cell[TextData[…],"TableText"]]]`) is recursed into, not `ToString`-dumped as a raw `Cell[…]` (regression: the BoxData handler sent the inner cell to `boxToCode`, leaking the whole `Cell[TextData[…]]` expression into the table):

```wl
VerificationTest[
    ! StringContainsQ[
        NotebookToMarkdown @ Notebook[{
            Cell[TextData[{Cell[BoxData[Cell[TextData[{"plain ", Cell[BoxData[StyleBox["x", "TI"]], "InlineFormula"]}], "TableText"]]]}], "Text"]
        }],
        "Cell["
    ],
    True,
    TestID -> "a Cell nested inside BoxData is unwrapped, not dumped as Cell[...]"
]
```

Nested italic styling does not double-wrap to bold and a styled bracket is not italicized - `StyleBox[StyleBox[x,"TI"],FontSlant->Italic]` gives `*x*` (not `**x**`) and `StyleBox["]",FontSlant->Italic]` gives `]` (not `*]*`), so a signature like `"GlobalPhase"[θ]` stays clean instead of `"GlobalPhase"[**θ***]*` (regression: naive StyleBox handling produced overlapping markdown markers):

```wl
VerificationTest[
    With[{md = NotebookToMarkdown @ Notebook[{
        Cell[TextData[{Cell[BoxData[RowBox[{StyleBox[StyleBox["x", "TI"], FontSlant -> "Italic"], StyleBox["]", FontSlant -> "Italic"]}]], "InlineFormula"]}], "Text"]
    }]},
        ! StringContainsQ[md, "***"] && ! StringContainsQ[md, "*]*"]
    ],
    True,
    TestID -> "nested italic does not double-wrap and brackets are not italicized"
]
```
