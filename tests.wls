#!/usr/bin/env wolframscript
(* End-to-end test runner. Loads the forward and inverse converters, then runs
   two test suites:

   (1) The regression suite is *extracted from* the "## Tests" section of
       MarkdownToNotebook.md - each fenced wl block in that section is an
       explicit `VerificationTest[code, expected, TestID -> "..."]` expression.
       The exact same cells become the resource's `VerificationTests` slot in
       the produced .nb (the docked Run Tests button evaluates them), so the
       in-notebook tests and this CI script share a single source of truth.

   (2) The walker round-trip suite sweeps over every literate-markdown document
       in the repo and asserts TWO invariants per document: (a) every executable
       code cell survives the walk (no source cell is silently dropped), and
       (b) every code cell's source survives faithfully - the reconstructed
       source text (boxToCode of the Input BoxData) of every cell in nb' (the
       rebuild) equals the reconstructed source of the corresponding cell in nb
       (the forward build). (b) is the faithfulness check: a walker that leaks
       "Subscript[obj, i]" instead of preserving the SubscriptBox, drops a
       handful of tokens, or returns "-Graphics-" instead of the box tree,
       fails here even when (a) still passes. The check normalises through
       boxToCode so a legitimate formatter difference (feInput inserting a
       line-continuation, the FE indenting <| ... |>) does not register; only
       a TOKEN-level change registers.

   Exit code is 0 on full pass, 1 on any failure (so CI can rely on it). *)

dir = DirectoryName[$InputFileName]
Get[FileNameJoin[{dir, "MarkdownToNotebook.wl"}]]
Get[FileNameJoin[{dir, "NotebookToMarkdown.wl"}]]

results = {}
recordResult[name_String, ok_] := (
    AppendTo[results, {name, ok}];
    Print[If[ok, "  PASS  ", "  FAIL  "], name]
)

(* === extracted regression suite ===
   litParse + sectionsFrom give us the parsed "## Tests" section directly; each
   wl block's "Code" field is the VerificationTest source. ToExpression
   evaluates it; a TestResultObject reports its own pass / fail. Both
   MarkdownToNotebook.md (forward-direction tests) and NotebookToMarkdown.md
   (walker tests) carry a ## Tests section that doubles as the resource's
   VerificationTests slot, so we scrape both here. *)

testBlocksFrom[file_String] := With[{
    parsed = litParse @ Import[FileNameJoin[{dir, file}], "Text"]
},
    Cases[Lookup[sectionsFrom[parsed["Blocks"]], "tests", {}], b_ /; codeBlockQ[b]]
]

runTestBlock[b_] := Block[{result, name, ok},
    result = Quiet @ ToExpression[b["Code"]];
    name = If[MatchQ[result, _TestObject], result["TestID"], "(no TestID)"];
    ok = MatchQ[result, _TestObject] && result["Outcome"] === "Success";
    recordResult[name, ok];
    If[ ! ok && MatchQ[result, _TestObject],
        Print["     expected: ", ToString[result["ExpectedOutput"], InputForm],
              "\n     actual:   ", ToString[result["ActualOutput"], InputForm],
              "\n     outcome:  ", result["Outcome"]]
    ]
]

Print["regressions (from MarkdownToNotebook.md ## Tests):"]
Scan[runTestBlock, testBlocksFrom["MarkdownToNotebook.md"]]

Print[""]
Print["regressions (from NotebookToMarkdown.md ## Tests):"]
Scan[runTestBlock, testBlocksFrom["NotebookToMarkdown.md"]]

(* === walker round-trip pass ===
   For each literate-markdown document in the repo, build the notebook, walk
   it back to markdown, and rebuild from that. The walker passes when:

     (a) every code cell survives the walk: the rebuild's wl-fence count is
         at least the forward build's (a dropped cell would lower it);

     (b) every code cell's source survives faithfully: the BoxData of each
         Input cell in nb' (the rebuild) equals the BoxData of the
         corresponding Input cell in nb (the original forward build) at the
         same source index. A walker that leaks "Subscript[obj, i]" instead
         of preserving the SubscriptBox, or that returns "-Graphics-"
         instead of the box tree, fails (b) even when (a) still passes.

   Heading recovery is template-dependent (a Demonstration template moves
   "## Details" into "### Details" under "Source & Additional Information"),
   so heading-count is not a robust invariant; we don't assert on it. *)

Print[""]
Print["walker round-trip (md -> nb -> walker -> nb', cells survive + BoxData equal):"]

(* normalise away formatter differences so a legitimate whitespace tweak
   (feInput inserting a line-continuation backslash, the FE indenting an
   association at a different column, an auto-inserted space around `:` /
   `,`) doesn't register as a content regression. The comparison is
   token-level: strip line-continuations, then strip *all* whitespace and
   strip the FE box-escape lead-ins / closers so an output-cell wrapped in
   `\!\(...\)` compares against the inner boxes. *)
(* Wolfram named-character escapes ↔ Unicode glyphs that the FE's InputText
   export canonicalises one way and the reparser canonicalises the other -
   they're the same character on both sides, the test should not flag the
   surface form. The resolver evaluates each `\[Name]` by parsing it as a
   WL string literal; an unknown name falls back to the literal escape. *)
resolveNamedChar[name_String] := Module[{c},
    c = Quiet @ ToExpression["\"\\[" <> name <> "]\""];
    If[StringQ[c] && StringLength[c] === 1, c, "\\[" <> name <> "]"]
]
namedEscapeReplace[s_String] := StringReplace[s,
    "\\[" ~~ n : (LetterCharacter ..) ~~ "]" :> resolveNamedChar[n]
]
(* `\:NNNN` and `\.NN` short hex escapes in a string literal are the same
   character as the literal Unicode glyph - the FE's InputText returns one
   form, the reparser may store the other, so the test normalises both
   sides to the actual char before comparing. *)
hexEscapeReplace[s_String] := StringReplace[s, {
    "\\:" ~~ h : Repeated[HexadecimalCharacter, {4}] :> FromCharacterCode[FromDigits[h, 16]],
    "\\." ~~ h : Repeated[HexadecimalCharacter, {2}] :> FromCharacterCode[FromDigits[h, 16]]
}]
normWS[s_String] := StringDelete[
    hexEscapeReplace @ namedEscapeReplace @ StringReplace[s, "\\\n" -> ""],
    Whitespace | "\\!\\(" | "\\)"
]
(* an Input cell whose entire BoxData is a GraphicsBox / Graphics3DBox /
   RasterBox is FE-decoration (a hero image, an output snapshot, a doc
   template's PlaceholderImage), not authored source - the walker drops
   them, so the round-trip comparison must skip them too. *)
sourceBoxQ[(GraphicsBox | Graphics3DBox | RasterBox)[___]] := False
sourceBoxQ[TagBox[(GraphicsBox | Graphics3DBox | RasterBox)[___], ___]] := False
sourceBoxQ[_] := True
sourceTexts[nb_] := normWS @ boxToCode[#] & /@ Select[
    Cases[nb, Cell[BoxData[b_], "Input" | "Code" | "ExampleInput" | "Program", ___] :> b, Infinity],
    sourceBoxQ]

sources = Join[
    {FileNameJoin[{dir, "MarkdownToNotebook.md"}],
     FileNameJoin[{dir, "NotebookToMarkdown.md"}]},
    Select[FileNames["*.md", FileNameJoin[{dir, "examples"}]], ! StringEndsQ[#, "-out.md"] &],
    FileNames["*.md", FileNameJoin[{dir, "examples", "*", "docs"}], Infinity]
]

(* Multiset comparison: the forward-path template reshuffles cells into the
   template's section order (Demonstration moves "## Details" into a
   subsection, etc.), so a doc that round-trips through a template that
   re-sorts sections lands with different cell positions in nb2 vs nb1 even
   when every authored Input cell is preserved. Compare as multisets so
   reordering doesn't register - only a missing or changed cell does.
   The check: every nb1 Input cell text must appear in nb2 with at least
   the same multiplicity. nb2 may have extras (the template can introduce
   placeholder Input cells the source didn't have); we don't flag those. *)
multisetSubsetQ[a_, b_] := And @@ (Count[b, #] >= Count[a, #] & /@ DeleteDuplicates[a])
checkRoundTrip[label_String, nb1_, nb2_] := Block[{codes1, codes2, surviveOk, matchOk, missing},
    codes1 = sourceTexts[nb1]; codes2 = sourceTexts[nb2];
    surviveOk = Length[codes2] >= Length[codes1];
    matchOk = surviveOk && multisetSubsetQ[codes1, codes2];
    recordResult[label, surviveOk && matchOk];
    If[ ! surviveOk,
        Print["     code cells: source ", Length[codes1], " / actual ", Length[codes2]]];
    If[ surviveOk && ! matchOk,
        missing = Select[DeleteDuplicates[codes1], Count[codes2, #] < Count[codes1, #] &];
        Print["     ", Length[missing], " of ", Length[DeleteDuplicates[codes1]], " distinct cells missing"];
        If[missing =!= {},
            Print["       missing: ", StringTake[First[missing], UpTo[180]]]]
    ]
]

Scan[
    src |-> Block[{nb1, recovered, nb2},
        nb1 = MarkdownToNotebook[src, "Evaluate" -> False];
        recovered = NotebookToMarkdown[nb1];
        nb2 = MarkdownToNotebook[recovered, "Evaluate" -> False];
        checkRoundTrip["walker round-trip: " <> FileNameTake[src], nb1, nb2]
    ],
    sources
]

(* === twin .md round-trip ===
   MarkdownToNotebook[src, "twin.md"] writes a viewer-friendly twin (output
   cells rasterised as ![](images/...)). The twin is a NEW markdown source,
   so feeding it back through MarkdownToNotebook should produce a notebook
   whose Input cells match the original build's Input cells - same source-text
   invariant as the walker pass, just routed through the twin emitter
   (markdownWithImages) instead of NotebookToMarkdown. "Evaluate" -> False
   skips the per-cell rasterisation so the twin still emits its code-fence
   structure for input cells. *)

Print[""]
Print["twin .md round-trip (md -> nb -> twin.md -> nb', Input source survives):"]

twinDir = FileNameJoin[{$TemporaryDirectory, "mtn-twin-tests"}]
Quiet @ CreateDirectory[twinDir, CreateIntermediateDirectories -> True]

Scan[
    src |-> Block[{twinPath, nb1, nb2},
        twinPath = FileNameJoin[{twinDir, FileBaseName[src] <> "-twin.md"}];
        nb1 = MarkdownToNotebook[src, "Evaluate" -> False];
        MarkdownToNotebook[src, twinPath, "Evaluate" -> False];
        nb2 = MarkdownToNotebook[twinPath, "Evaluate" -> False];
        checkRoundTrip["twin round-trip: " <> FileNameTake[src], nb1, nb2]
    ],
    sources
]
Quiet @ DeleteDirectory[twinDir, DeleteContents -> True]

(* === summary === *)

Print[""]
Print["==== summary ====", "  ", Count[results, {_, True}], " / ", Length[results], " pass"]

If[ ! AllTrue[results, Last],
    Print["FAILURES:"];
    Scan[Print["  ", #[[1]]] &, Select[results, ! Last[#] &]];
    Exit[1]
]
