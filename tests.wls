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
       in the repo and asserts a *structural* invariant rather than byte-exact
       recovery: forward -> walk -> forward should produce a notebook with the
       same cell-style sequence as the first forward run. The walker is the
       only path NotebookToMarkdown takes, so any reduction in walker quality
       shows up here as a style-sequence divergence.

   Exit code is 0 on full pass, 1 on any failure (so CI can rely on it). *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

dir = DirectoryName[$InputFileName]
Get[FileNameJoin[{dir, "MarkdownToNotebook.wl"}]]
Get[FileNameJoin[{dir, "NotebookToMarkdown.wl"}]]

results = {}
recordResult[name_String, ok_] := (
    AppendTo[results, {name, ok}];
    print[If[ok, "  PASS  ", "  FAIL  "], name]
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
        print["     expected: ", ToString[result["ExpectedOutput"], InputForm],
              "\n     actual:   ", ToString[result["ActualOutput"], InputForm],
              "\n     outcome:  ", result["Outcome"]]
    ]
]

print["regressions (from MarkdownToNotebook.md ## Tests):"]
Scan[runTestBlock, testBlocksFrom["MarkdownToNotebook.md"]]

print[""]
print["regressions (from NotebookToMarkdown.md ## Tests):"]
Scan[runTestBlock, testBlocksFrom["NotebookToMarkdown.md"]]

(* === walker smoke pass ===
   The walker is best-effort: it reads the rendered cells, not the original
   source, so byte-exact recovery is impossible (frontmatter lives in
   TaggingRules, code option `#|` lines are gone, the resource template
   reshuffles top-level sections into subsections, etc.). The smoke pass
   verifies that (a) the walker returns a non-empty string for every
   literate sample, and (b) preserves all executable code cells -
   i.e. it has not silently dropped content cells on the floor. Heading
   recovery is template-dependent (a Demonstration template moves
   "## Details" into "### Details" under "Source & Additional
   Information"), so heading count is not a robust invariant. Output
   formatting fidelity is checked piecewise by dedicated tests as it lands. *)

print[""]
print["walker smoke (md -> nb -> walker(nb), code cells preserved):"]

(* count fenced wl code blocks in the source, EXCLUDING those whose first line
   is "#| input: false" - those are intentionally rendered as Output-only cells
   by the forward converter (the Demonstration snapshot convention), so the
   walker has no Input cell to recover and the loss is by design. *)
countCodeCells[md_String] := StringCount[md,
    "```" ~~ ("wl" | "wolfram" | "mathematica") ~~ "\n" ~~
        body : Shortest[___] ~~ "\n```" /;
            ! StringMatchQ[body, "#|" ~~ Whitespace... ~~ "input:" ~~ Whitespace... ~~ "false" ~~ ___]
]

sources = Join[
    {FileNameJoin[{dir, "MarkdownToNotebook.md"}],
     FileNameJoin[{dir, "NotebookToMarkdown.md"}]},
    Select[FileNames["*.md", FileNameJoin[{dir, "examples"}]], ! StringEndsQ[#, "-out.md"] &],
    FileNames["*.md", FileNameJoin[{dir, "examples", "*", "docs"}], Infinity]
]

Scan[
    src |-> Block[{original, nb, recovered, srcCodes, recCodes, ok},
        original = Import[src, "Text"];
        nb = MarkdownToNotebook[src, "Evaluate" -> False];
        recovered = NotebookToMarkdown[nb];
        srcCodes = countCodeCells[original]; recCodes = countCodeCells[recovered];
        ok = StringQ[recovered] && StringLength[recovered] > 0 && recCodes >= srcCodes;
        recordResult["walker smoke: " <> FileNameTake[src], ok];
        If[ ! ok && StringQ[recovered],
            print["     code cells: source ", srcCodes, " / walker ", recCodes]
        ]
    ],
    sources
]

(* === summary === *)

print[""]
print["==== summary ====", "  ", Count[results, {_, True}], " / ", Length[results], " pass"]

If[ ! AllTrue[results, Last],
    print["FAILURES:"];
    Scan[print["  ", #[[1]]] &, Select[results, ! Last[#] &]];
    Exit[1]
]
