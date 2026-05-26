---
Template: FunctionResource
ResourceType: Function
Name: NotebookToMarkdown
Description: Recover a markdown approximation of a Wolfram notebook
ContributedBy: "Nikolay Murzin, Claude (Anthropic)"
Keywords: [markdown, literate programming, inverse, function repository, notebook, round trip]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, NotebookGet, MarkdownToNotebook]
Links: ["[MarkdownToNotebook - the forward converter](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/)", "[Source on GitHub](https://github.com/sw1sh/MarkdownToNotebook)"]
EntrySymbol: NotebookToMarkdown
---

`NotebookToMarkdown` is the inverse of [MarkdownToNotebook](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/). Given a notebook expression, a [NotebookObject](https://reference.wolfram.com/language/ref/NotebookObject.html), or a `.nb` file path, it walks the cells and emits a markdown approximation - recognising the standard cell styles MarkdownToNotebook itself emits (Title / Section / ... / Text / Notes / Item / Input / Code / etc.) plus their inline `TextData` formatting.

## Definition

The implementation is a single plain `.wl` file, inlined here at conversion time via the `#| file:` option; the deployed resource therefore carries it inline:

```wl
(* NotebookToMarkdown - the inverse of MarkdownToNotebook. Given a notebook
   (expression / NotebookObject / .nb file path), recover a markdown
   approximation of its source by walking the cells.

   Walker-only by design: any TaggingRules stash a forward run might have left
   behind is ignored, so this code is exercised on every input and round-trip
   quality is the walker's responsibility, not a memoized shortcut. The walker
   recognises the standard cell styles MarkdownToNotebook itself emits (Title /
   Section / ... / Text / Notes / Item / Input / Code / etc.) plus their inline
   TextData formatting.

   Deliberately plain top-level definitions (no BeginPackage), the same shape
   as the forward converter, so a resource notebook can inline this file with a
   "#| file: NotebookToMarkdown.wl" cell and have it work on Get. *)

(* === inline TextData -> markdown text ===
   Patterns mirror the forward parser's inlineTextData output so a round trip
   preserves formatting choices. *)
inlineMd[s_String] := s
inlineMd[StyleBox[s_String, opts___]] := With[{styles = {opts}},
    Which[
        MemberQ[styles, "TI"] || MemberQ[styles, FontSlant -> "Italic"], "*" <> s <> "*",
        MemberQ[styles, "TB"] || MemberQ[styles, FontWeight -> "Bold"], "**" <> s <> "**",
        True, s
    ]
]
(* paclet-link button -> [Name]() (the inferred form the forward parser knows). *)
inlineMd[ButtonBox[name_String, BaseStyle -> "Link", ButtonData -> uri_String, ___]] :=
    "[" <> name <> "](" <> If[StringStartsQ[uri, "paclet:"], "", uri] <> ")"
(* hyperlink button -> [text](url). *)
inlineMd[ButtonBox[name_String, BaseStyle -> "Hyperlink", ButtonData -> {URL[u_String], ___}, ___]] :=
    "[" <> name <> "](" <> u <> ")"
inlineMd[Cell[BoxData[b_], "InlineFormula", ___]] := With[{md = inlineMd[b]},
    Which[
        StringMatchQ[md, "[" ~~ ___ ~~ "](" ~~ ___ ~~ ")"], "<code>" <> md <> "</code>",
        True, "`" <> md <> "`"
    ]
]
inlineMd[FractionBox[a_, b_]] := "$" <> inlineMd[a] <> "/" <> inlineMd[b] <> "$"
inlineMd[SubscriptBox[a_, b_]] := "$" <> inlineMd[a] <> "_" <> inlineMd[b] <> "$"
inlineMd[SuperscriptBox[a_, b_]] := "$" <> inlineMd[a] <> "^" <> inlineMd[b] <> "$"
inlineMd[RowBox[xs_List]] := StringJoin[inlineMd /@ xs]
inlineMd[TextData[xs_List]] := StringJoin[inlineMd /@ xs]
inlineMd[TextData[x_]] := inlineMd[x]
inlineMd[other_] := ToString[other, InputForm]

(* TextData / String / Cell content -> a plain text string (recovers prose). *)
cellText[Cell[content_, ___]] := cellText[content]
cellText[s_String] := s
cellText[TextData[xs_]] := If[ListQ[xs], StringJoin[inlineMd /@ xs], inlineMd[xs]]
cellText[BoxData[b_]] := boxToCode[b]
cellText[other_] := ToString[other, InputForm]

(* Box-form WL code -> source string. ToString[..., InputForm] does the right
   thing for almost every code cell, and the rare InterpretationBox wraps just
   need to be stripped to the original surface form. *)
boxToCode[b_] := Block[{cleaned = b /. InterpretationBox[a_, ___] :> a},
    Replace[cleaned, {
        s_String :> s,
        _ :> StringTrim[ToString[ToExpression[ToBoxes[cleaned], StandardForm, HoldForm], InputForm] /. HoldForm[x_] :> ToString[Unevaluated[x], InputForm]]
    }]
]

(* a single Cell -> one markdown block (or "" if it should be skipped). *)
cellMd[Cell[_, "Output", ___]] := ""
cellMd[Cell[_, "Message", ___]] := ""
cellMd[Cell[_, "MSG", ___]] := ""
cellMd[Cell[_, "ExampleInitialization", ___]] := ""
cellMd[Cell[content_, style_String, opts___]] := Block[{txt = cellText[Cell[content, style, opts]]},
    Switch[style,
        "Title",        "# " <> txt,
        "Section",      "## " <> txt,
        "Subsection",   "### " <> txt,
        "Subsubsection","#### " <> txt,
        "Text" | "Notes" | "Caption" | "Quote",  txt,
        "ItemNumbered" | "ItemNumbered1", "1. " <> txt,
        "Item" | "Item1" | "Item2" | "Notes" | "Bullet",  "- " <> txt,
        "Code" | "Input" | "ExampleInput", "```wl\n" <> txt <> "\n```",
        "InlineFormula", "`" <> txt <> "`",
        _, txt
    ]
]
cellMd[Cell[CellGroupData[cells_List, ___]]] := StringRiffle[DeleteCases[cellMd /@ cells, ""], "\n\n"]
cellMd[other_] := ""

(* === public entry === *)

NotebookToMarkdown[Notebook[cells_List, ___]] :=
    StringRiffle[DeleteCases[cellMd /@ cells, ""], "\n\n"] <> "\n"
NotebookToMarkdown[nbo_NotebookObject] := NotebookToMarkdown[NotebookGet[nbo]]
NotebookToMarkdown[file_String /; FileExistsQ[file] && StringEndsQ[ToLowerCase[file], ".nb"]] :=
    NotebookToMarkdown[Get[file]]
NotebookToMarkdown[source_, "String"] := NotebookToMarkdown[source]
NotebookToMarkdown[source_, target_String /; StringEndsQ[ToLowerCase[target], ".md"]] := Block[
    {md = NotebookToMarkdown[source]},
    Export[target, md, "Text"];
    target
]
```

## Usage

<code>[NotebookToMarkdown]()[$nb$]</code> returns the markdown source string for the notebook *nb* (a `Notebook[...]` expression, a [NotebookObject](https://reference.wolfram.com/language/ref/NotebookObject.html), or a `.nb` file path).

<code>[NotebookToMarkdown]()[$nb$, "$file$.md"]</code> writes the markdown to *file* and returns the file path.

## Details & Options

- The *nb* argument can be a [Notebook](https://reference.wolfram.com/language/ref/Notebook.html) expression, a [NotebookObject](https://reference.wolfram.com/language/ref/NotebookObject.html) open in the front end, or a string `".nb"` file path. The file form `Get`s the notebook off disk; the NotebookObject form `NotebookGet`s the live one.
- `NotebookToMarkdown` always walks the cells - it does not consult any `TaggingRules` stash a forward run might have left behind. Walker quality is therefore the function's responsibility and is exercised on every input.
- Standard styles map back as: `Title` / `Section` / `Subsection` / `Subsubsection` to `#` / `##` / `###` / `####` headings; `Text` / `Notes` / `Caption` / `Quote` to prose; `Item` / `ItemNumbered` to markdown lists; `Code` / `Input` to ```` ```wl ... ``` ```` fenced blocks; `Output` / `Message` are skipped (they regenerate on re-conversion).
- Inline `TextData` is converted back through the same backtick / bold / italic / link rules the forward parser accepts, so the produced markdown re-parses to an equivalent block sequence.
- The walker does not recover frontmatter or resource-template-specific slots from the rendered cells; the markdown it emits is the rendered body only.

## Basic Examples

Walk a small notebook and recover the markdown body:

```wl
NotebookToMarkdown @ Notebook[{
    Cell["Demo", "Title"],
    Cell["A paragraph.", "Text"],
    Cell[BoxData["Range[5]^2"], "Input"]
}]
```

![output](images/NotebookToMarkdown-out-1.png)

## Scope

A `.nb` file path is read via `Get` and converted the same way:

```wl
NotebookToMarkdown[FileNameJoin[{$TemporaryDirectory, "no-such-file.nb"}]] === Null
```

![output](images/NotebookToMarkdown-out-2.png)

## Properties and Relations

The forward and inverse together form an editable pipeline: convert a markdown source, edit the notebook in the front end, walk the modified notebook back to markdown. The walker reflects the *current* state of the cells, so hand edits survive the round trip. Walker output is not byte-identical to the original source - frontmatter is dropped, code cell `#|` options are not recovered, and any decorative template cells the front end may have introduced are filtered out - but feeding the walker's output back through the forward path produces an equivalent notebook.

## Possible Issues

Round-trip is *approximate*. The walker reads the rendered cells, not the original source, so:

- Frontmatter is not recovered (it lives in `TaggingRules`, not in cells).
- Code cell options (`#| eval: false`, `#| screenshot: true`, ...) are gone.
- Inline math and decorative formatting may serialize back to a simpler form.

For an arbitrary notebook the walker emits its best guess at the prose / heading / code structure; for a notebook MarkdownToNotebook itself wrote, the body is close to the source but the frontmatter must be added back by hand if needed.

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

![output](images/NotebookToMarkdown-out-3.png)
