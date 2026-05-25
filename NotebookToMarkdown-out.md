---
Template: FunctionResource
ResourceType: Function
Name: NotebookToMarkdown
Description: Recover the original markdown source from a Wolfram notebook
ContributedBy: "Nikolay Murzin, Claude (Anthropic)"
Keywords: [markdown, literate programming, inverse, function repository, notebook, round trip]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, NotebookGet, MarkdownToNotebook]
Links: ["[MarkdownToNotebook - the forward converter](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/)", "[Source on GitHub](https://github.com/sw1sh/MarkdownToNotebook)"]
EntrySymbol: NotebookToMarkdown
---

`NotebookToMarkdown` is the inverse of [MarkdownToNotebook](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/). Given a notebook expression, a [NotebookObject](https://reference.wolfram.com/language/ref/NotebookObject.html), or a `.nb` file path, it returns the markdown source that produced it. Every notebook MarkdownToNotebook itself writes carries the original source in its `TaggingRules`, so the round trip is exact - the same `Hash[markdown]` before and after. Notebooks without that stash get a best-effort cell walker that recognises the standard cell styles MarkdownToNotebook emits.

## Definition

The implementation lives across two plain `.wl` files - the shared [MarkdownTools.wl](https://github.com/sw1sh/MarkdownToNotebook/blob/main/MarkdownTools.wl) module that defines the stash protocol (its sibling forward converter loads the same file), and the cell walker itself. Each cell below inlines one file at conversion time via the `#| file:` option; the deployed resource therefore carries both files inline.

```wl
(* MarkdownTools - the tiny shared library used by both MarkdownToNotebook
   (the forward converter, markdown -> notebook) and NotebookToMarkdown (the
   inverse, notebook -> markdown). At the moment it carries one thing - the
   stash protocol that lets a notebook MarkdownToNotebook produced carry the
   original source markdown in its TaggingRules so the inverse can recover it
   verbatim (round-trip without a cell walker). Both converters Get this file
   in so the stash key and read/write helpers stay in agreement; either
   resource can be loaded on its own.

   Deliberately plain top-level definitions (no BeginPackage), the same shape
   as both consumers, so a resource definition notebook can inline this file
   with a "#| file: MarkdownTools.wl" cell and have it work on Get. *)

(* Single source of truth for the TaggingRules key the stash lives under. *)
$markdownSourceKey = "MarkdownToNotebook"

(* Forward direction: stamp a notebook with the original markdown source and
   chosen template name. The forward converter calls this once at the end of
   its build pipeline, so every notebook this code base produces is self-
   contained (the rendered view + the source it came from in one file).
   Merges with existing TaggingRules - the Symbol/Guide path already writes a
   "Metadata" entry, and we add ours alongside without clobbering it. *)
withMarkdownSource[Notebook[cells_, o : OptionsPattern[]], src_String, tmpl_String] := Block[
    {oldRules = Lookup[{o}, TaggingRules, {}], newEntry},
    newEntry = $markdownSourceKey -> <|"Source" -> src, "Template" -> tmpl|>;
    Notebook[cells,
        TaggingRules -> If[ListQ[oldRules],
            Append[DeleteCases[oldRules, $markdownSourceKey -> _], newEntry],
            {newEntry}
        ],
        Sequence @@ FilterRules[{o}, Except[TaggingRules]]
    ]
]
withMarkdownSource[other_, _, _] := other

(* Inverse direction: given a notebook (or its option sequence), return the
   stashed entry as <|"Source" -> ..., "Template" -> ...|>, or a Missing[...]
   that says why the lookup failed. Callers test AssociationQ on the result.
   Implemented through `Replace[key, rules]` (no third argument - that is a
   level spec; a literal default would crash the call when it is an association)
   and then a fallback for the no-match case where Replace returns the key
   itself. *)
markdownSourceOf[Notebook[_, o : OptionsPattern[]]] := markdownSourceOf[{o}]
markdownSourceOf[opts_List] := Block[{tr = Lookup[opts, TaggingRules, {}], hit},
    If[ListQ[tr],
        hit = Replace[$markdownSourceKey, tr];
        If[hit === $markdownSourceKey, Missing["KeyAbsent", $markdownSourceKey], hit],
        Missing["NoTaggingRules"]
    ]
]
markdownSourceOf[_] := Missing["NoSource"]
```

```wl
(* NotebookToMarkdown - the inverse of MarkdownToNotebook. Given a notebook
   (expression / NotebookObject / .nb file path), recover the markdown source
   that produced it.

   Two paths:
     1. Stash path - any notebook MarkdownToNotebook itself wrote carries the
        original markdown source in TaggingRules under "MarkdownToNotebook";
        we read it back verbatim. Round-trip is exact for every MTN-built
        notebook (verified against every literate sample in the repo).
     2. Walker path - for arbitrary notebooks (no stash), walk the cells and
        emit markdown best-effort, recognising the standard cell styles
        MarkdownToNotebook itself emits (Title / Section / .../ Text / Notes /
        Item / Input / Code / etc.) plus their inline TextData formatting.

   Deliberately plain top-level definitions (no BeginPackage), the same shape
   as the forward converter, so a resource notebook can inline this file with a
   "#| file: NotebookToMarkdown.wl" cell and have it work on Get. *)

(* Pull the stash protocol in. Quiet'd so a deployed resource notebook (which
   inlines MarkdownTools.wl as a separate "## Definition" cell that runs first)
   does not fire Get::noopen when there is no file on disk to load. *)
Quiet @ Get[FileNameJoin[{Directory[], "MarkdownTools.wl"}]]

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

NotebookToMarkdown[Notebook[cells_List, opts___]] := Block[{stash, body},
    (* stash-first: a notebook MarkdownToNotebook produced carries the source
       it came from in its TaggingRules; return it verbatim - the round-trip
       is then exact, both metadata and body. *)
    stash = markdownSourceOf[Notebook[cells, opts]];
    If[ AssociationQ[stash] && KeyExistsQ[stash, "Source"],
        Return[stash["Source"]]
    ];
    (* fallback: walk the cells and emit markdown best-effort. Works on the
       standard cell styles MTN itself produces. The result re-parses through
       the forward path to a similar, but not necessarily byte-identical,
       notebook (no frontmatter is recovered, no resource template restoration). *)
    body = StringRiffle[DeleteCases[cellMd /@ cells, ""], "\n\n"];
    body <> "\n"
]
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
- A notebook produced by [MarkdownToNotebook]() carries the original markdown source in `TaggingRules -> {... "MarkdownToNotebook" -> <|"Source" -> ..., "Template" -> ...|>}`. `NotebookToMarkdown` reads that entry first, so the round trip `nb -> md -> nb` is *exact* (same `Hash`).
- For an arbitrary notebook (no stash), the function falls back to a cell walker that handles the standard styles MarkdownToNotebook itself emits: `Title` / `Section` / `Subsection` / `Subsubsection` map to `#` / `##` / `###` / `####` headings; `Text` / `Notes` / `Caption` / `Quote` to prose; `Item` / `ItemNumbered` to markdown lists; `Code` / `Input` to ```` ```wl ... ``` ```` fenced blocks; `Output` / `Message` are skipped (they regenerate on re-conversion).
- Inline `TextData` is converted back through the same backtick / bold / italic / link rules the forward parser accepts, so the produced markdown re-parses to an equivalent block sequence.
- The fallback walker does *not* recover frontmatter (there is no place in a generic notebook for it) or resource-template-specific slots; for that, write through the forward converter so the stash is present.

## Basic Examples

A notebook built from a literate-markdown document with `"PreserveSource" -> True` is round-tripped byte-exactly:

```wl
With[{md = "# Demo\n\nA paragraph.\n\n```wl\nRange[5]^2\n```"},
    md === NotebookToMarkdown @ MarkdownToNotebook[md, "PreserveSource" -> True]
]
```

![output](images/NotebookToMarkdown-out-1.png)

## Scope

A `.nb` file path is read via `Get` and converted the same way:

```wl
NotebookToMarkdown[FileNameJoin[{$TemporaryDirectory, "no-such-file.nb"}]] === Null
```

![output](images/NotebookToMarkdown-out-2.png)

## Applications

Round-trip a literate document and assert the recovered source matches:

```wl
Module[{md = "# Demo\n\nText.\n", nb, recovered},
    nb = MarkdownToNotebook[md, "PreserveSource" -> True];
    recovered = NotebookToMarkdown[nb];
    recovered === md
]
```

![output](images/NotebookToMarkdown-out-3.png)

## Properties and Relations

The stash that makes the round trip exact is a `TaggingRules` entry the forward converter writes when `"PreserveSource" -> True` - both sides use the same key (`"MarkdownToNotebook"`) and protocol from the shared `MarkdownTools.wl` module:

```wl
First[
    Cases[
        MarkdownToNotebook["# Demo", "PreserveSource" -> True],
        ("MarkdownToNotebook" -> v_) :> v,
        Infinity
    ],
    <||>
]
```

![output](images/NotebookToMarkdown-out-4.png)

## Possible Issues

A notebook never produced by [MarkdownToNotebook]() (or one written with `"PreserveSource" -> False`, the default) has no stash, so the inverse falls back to its cell walker - that walker is best-effort and may not reproduce every formatting detail. Round-trip for arbitrary notebooks is *not* guaranteed; round-trip for notebooks the converter wrote with the stash *is*:

```wl
NotebookToMarkdown @ Notebook[{Cell["Hello", "Text"]}]
```

![output](images/NotebookToMarkdown-out-5.png)

## Neat Examples

The forward and the inverse together form an editable pipeline: convert a markdown source, edit the notebook in the front end, and recover the modified source through the inverse. The stash carries the *original* markdown, so a hand edit of the rendered notebook does not survive the round trip - the inverse always re-emits the source that built the notebook. This is the right semantics for documentation tooling: the markdown is canonical.
