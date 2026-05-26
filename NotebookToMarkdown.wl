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
