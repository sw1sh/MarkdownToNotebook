---
Template: FunctionResource
ResourceType: Function
Name: NotebookToMarkdown
Description: Recover a faithful literate-markdown twin of a Wolfram notebook
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [markdown, literate programming, inverse, function repository, notebook, round trip]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, NotebookGet, MarkdownToNotebook]
Links: ["[MarkdownToNotebook - the forward converter](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/)", "[Source on GitHub](https://github.com/sw1sh/MarkdownToNotebook)"]
EntrySymbol: NotebookToMarkdown
---

`NotebookToMarkdown` is the inverse of [MarkdownToNotebook](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/). Given a notebook expression, a [NotebookObject](), or a `.nb` file path, it walks the cells and emits a literate-markdown twin - frontmatter (when the cells indicate a Symbol-template doc page), the verbatim typed Input code, Usage signatures, Notes / property tables, and the standard `Title` / `Section` / `Text` / `Item` / `Code` cell-style sequence mapped back to markdown blocks.

## Definition

The implementation is a single plain `.wl` file, inlined here at conversion
time via the `#| file:` option; the deployed resource therefore carries it
inline:

```wl
#| file: NotebookToMarkdown.wl
```

## Usage

<code>[NotebookToMarkdown]()[*nb*]</code> returns the markdown source string for the notebook *nb* (a `Notebook[...]` expression, a [NotebookObject](), or a `.nb` file path).

<code>[NotebookToMarkdown]()[*nb*, "*file*.md"]</code> writes the markdown to *file* and returns the file path.

## Details & Options

- The *nb* argument can be a [Notebook]() expression, a [NotebookObject]() open in the front end, or a string `".nb"` file path. The file form `Get`s the notebook off disk; the NotebookObject form `NotebookGet`s the live one.
- `NotebookToMarkdown` always walks the cells - it does not consult any `TaggingRules` stash a forward run might have left behind. Walker quality is therefore the function's responsibility and is exercised on every input.
- Standard styles map back as: `Title` / `Section` / `Subsection` / `Subsubsection` to `#` / `##` / `###` / `####` headings; `Text` / `Caption` / `Quote` / `ExampleText` / `CodeText` to prose; `Item` / `ItemNumbered` to markdown lists; `Code` / `Input` / `ExampleInput` to ```` ```wl ... ``` ```` fenced blocks; `Program` cells (`#| eval: false`, or non-`wl` fenced source) to a no-language fenced block; `Output` / `Message` / `Print` are skipped (they regenerate on re-conversion).
- The doc-template scaffolding cells - the `Usage` slot, `Notes`, `2ColumnTableMod` / `3ColumnTableMod` property tables, `ExampleSection` / `Subsection` titles, the `PrimaryExamplesSection` opener - all round-trip with their template-implied markdown shape: `## Usage`, `## Details & Options`, a pipe-table per `*TableMod`, `## Basic Examples`, etc.
- **Frontmatter is recovered** when the notebook carries an `ObjectName` cell (the Symbol-template marker): the `Categorization` / `Keywords` / `SeeAlso` / `MoreAbout` cells feed a YAML block at the top of the output, so a shipped reference page round-trips to a rebuildable literate-markdown twin. Notebooks without an `ObjectName` cell (an arbitrary `.nb`) get no frontmatter, just the body.
- **Code cells are verbatim** when a front end is available: the implementation calls the FE's `InputText` export packet so subscripts, `@`, `//`, `[[…]]`, `%`, and 2D-box content survive as their linear-syntax forms. Without a FE the walker falls back to a kernel-only `boxToCode` tree walk - still faithful for plain WL but less so for exotic 2D shapes. Either way the cell text wraps in a fence whose backtick run is one longer than the longest backtick run inside the cell body, so a cell that shows a ` ``` ` fence inside its own source still produces valid markdown.
- **Signature recovery.** An `InlineFormula` cell whose box tree is a call form (`Sym[...]`, an inferred-link `ButtonBox`) renders as <code>[Sym]()[*x*, *y*]</code> - a clickable head with code styling, italic args, subscripts as canonical inline math (`$obj_{i}$`, the form [MarkdownToNotebook]()'s forward parser round-trips to a clean subscript). 2D math without a call shape renders as `$math$` with Greek letters and operators mapped to their TeX commands (`\theta`, `\pi`, `\dagger`, `\cdot`).
- **Empty placeholder sections** (a doc-template `## Properties & Relations` heading with no following content) are dropped from the output when frontmatter is being emitted, matching MarkdownToNotebook's forward-path behaviour. For an arbitrary notebook every heading is kept.
- **Round-trip contract for signatures**: subscripted arguments emit as `$obj_{i}$` (base inside the math). The looser `*obj*$_i$` form (italic base plus a separate `$_i$`) renders fine raw but round-trips broken through MTN, so the walker never emits it.

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

---

Recover a shipped reference page (a `Symbol` / `Guide` / `TechNote` authoring notebook) as a rebuildable literate-markdown twin:

```wl
#| eval: false
NotebookToMarkdown[
    "/path/to/Documentation/English/ReferencePages/Symbols/MyFn.nb",
    "/path/to/MyFn.md"
]
```

## Scope

A `.nb` file path is read via `Get` and converted the same way as the in-memory `Notebook[…]` form. Round-trip an authored notebook through disk to demonstrate:

```wl
With[{tmp = FileNameJoin[{$TemporaryDirectory, "ntm-scope-demo.nb"}]},
    Put[Notebook[{Cell["Demo", "Title"], Cell["A paragraph.", "Text"], Cell[BoxData["Range[5]^2"], "Input"]}], tmp];
    NotebookToMarkdown[tmp]
]
```

<!-- => "# Demo\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n" -->

## Properties and Relations

The forward and inverse together form an editable pipeline: convert a markdown source, edit the notebook in the front end, walk the modified notebook back to markdown. The walker reflects the *current* state of the cells, so hand edits survive the round trip. Walker output is not byte-identical to the original source - cell `#|` options are not recovered, fenced-block language tags for non-`wl` fences are lost (the .nb cell only remembers it's `"Program"` styled, not the original language), and the FE may have introduced decorative cells the walker filters out - but feeding the walker's output back through the forward path produces an equivalent notebook.

## Possible Issues

- Frontmatter is recovered only when the notebook has an `ObjectName` cell (the Symbol-template marker). A FunctionResource / Data / TechNote / Demonstration notebook walks to a bare body; add the `Template:` / `Name:` / etc. block back by hand if you need a rebuildable twin.
- The fenced-block language tag is lost for non-`wl` fences (a `text` / `ebnf` / `python` block becomes a Program-styled cell in the .nb, which walks back to a no-language fence). The block round-trips structurally but the syntax-highlighting hint doesn't.
- The faithful Input recovery uses the front end's `InputText` packet. In a session with no FE link available, the walker falls back to a kernel-only `boxToCode` tree walk; the cell still recovers, but subscripts, the `@` / `//` shorthand, and other 2D-input niceties are returned in their box-source rather than the typed form.

## Neat Examples

A round-trip smoke test: forward, walk, forward again, and check the second forward run produces a notebook whose Input cells (by reconstructed source text, normalised) match the first:

```wl
With[{md = "# Demo\n\n## Section\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n"},
    Module[{nb1, md2, nb2, normWS, sourceTexts},
        nb1 = MarkdownToNotebook[md, "Evaluate" -> False];
        md2 = NotebookToMarkdown[nb1];
        nb2 = MarkdownToNotebook[md2, "Evaluate" -> False];
        normWS[s_String] := StringDelete[StringReplace[s, "\\\n" -> ""], Whitespace];
        sourceTexts[nb_] := normWS @ boxToCode[#] & /@
            Cases[nb, Cell[BoxData[b_], "Input" | "Code" | "ExampleInput" | "Program", ___] :> b, Infinity];
        sourceTexts[nb1] === sourceTexts[nb2]
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
    TestID -> "code signature in FormBox renders as <code>, not $math$"
]
```
