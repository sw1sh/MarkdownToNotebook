#!/usr/bin/env wolframscript
(* Self-hosting build: define MarkdownToNotebook from its own markdown source,
   run it on that same source to (re)produce its Function Repository definition
   notebook, then deploy that notebook publicly to the cloud. The only
   hand-written part is the tiny Definition-cell extractor below; everything else
   comes from the markdown. *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

(* the definition-notebook template version follows the kernel's
   DefinitionNotebookClient paclet; pull the latest so the generated notebook is
   not flagged "out of date" when opened in a newer front end. *)
Quiet @ PacletInstall["DefinitionNotebookClient", UpdateSites -> True]

dir = DirectoryName[$InputFileName]
src = FileNameJoin[{dir, "MarkdownToNotebook.md"}]
text = Import[src, "Text"]

(* phase 1: pull the code cells under "## Definition" and define them.
   Anchor to the heading at the start of a line (the intro prose mentions
   "## Definition" mid-sentence), and accept any wl-ish fence tag. *)
definitionSection[t_String] := First[
    StringCases[t, StartOfLine ~~ "## Definition" ~~ "\n" ~~ Shortest[s___] ~~ ("\n## " | EndOfString) :> s, 1],
    ""
]

definitionCells[t_String] := StringCases[
    definitionSection[t],
    "```" ~~ ("wl" | "wolfram" | "mathematica") ~~ "\n" ~~ Shortest[c___] ~~ "\n```" :> c
]

(* the Definition section inlines its code via "#| file: path"; resolve those
   includes relative to the document. Fall back to any inline cell code. *)
includeFiles[t_String] := FileNameJoin[{dir, StringTrim[#]}] & /@
    StringCases[definitionSection[t], StartOfLine ~~ "#|" ~~ Whitespace... ~~ "file:" ~~ p : Except["\n"].. :> p]

print["build: defining function from ", FileNameTake[src]]
includes = includeFiles[text]
If[ includes =!= {},
    print["  including: ", FileNameTake /@ includes];
    Scan[Get, includes]
    ,
    bootDefFile = FileNameJoin[{$TemporaryDirectory, "mtrf-bootstrap.wl"}];
    Export[bootDefFile, StringRiffle[definitionCells[text], "\n\n"], "Text"];
    Get[bootDefFile]
]

If[ DownValues[MarkdownToNotebook] === {},
    print["  warn: MarkdownToNotebook has no definition"]
]

(* phase 2: run the function on its own source (cold) *)
print["build: converting itself (cold run)"]
cacheFile = src <> ".cache.wxf"
If[ FileExistsQ[cacheFile], DeleteFile[cacheFile] ]

{coldTime, result} = AbsoluteTiming @ MarkdownToResourceFunction[src, "Output" -> "Association"]
nb = result["Notebook"]

print["  Template:    ", result["Template"]]
print["  Name:        ", result["Metadata"]["Name"]]
print["  Sections:    ", result["Sections"]]
print["  Notebook head:  ", Head[nb]]
print["  Output cells:   ", Count[nb, Cell[_, "Output", ___], Infinity], " (evaluated examples)"]
print["  Unfilled slots: ", Count[nb, _TemplateSlot, Infinity]]
print["  cold run:    ", coldTime, " s"]

(* phase 3: re-run to demonstrate the example cache (no re-evaluation) *)
{warmTime, warmResult} = AbsoluteTiming @ MarkdownToResourceFunction[src, "Output" -> "Association"]
print["  warm run:    ", warmTime, " s (cache ", If[FileExistsQ[cacheFile], "hit", "miss"], ")"]

(* phase 4: write the definition notebook to disk (a file target makes the
   function write rather than just return the Notebook) *)
outNb = MarkdownToResourceFunction[src, FileNameJoin[{dir, "MarkdownToNotebook.nb"}]]
print["  wrote:       ", FileNameTake[outNb], " (", Head @ Quiet @ Get[outNb], ")"]

(* phase 5: deploy the resource function publicly to the cloud (the docked
   Deploy > "Publicly in the cloud" action = DeployResource[..., "CloudPublic"]). *)
print["build: deploying the resource function publicly to the cloud"]
Needs["DefinitionNotebookClient`"]
If[ Not[TrueQ[$CloudConnected]], Quiet @ CloudConnect[] ]
If[ TrueQ[$CloudConnected],
    deployed = UsingFrontEnd @ Block[{nbo = NotebookOpen[File[outNb]], res},
        res = DefinitionNotebookClient`DeployResource["Function", nbo, "CloudPublic"];
        NotebookClose[nbo];
        res
    ];
    print["  deployed: ", Replace[deployed, {
        ro_ResourceObject :> ro["DocumentationLink"],
        a_Association :> Lookup[a, "ResultLink", a]
    }] ]
    ,
    print["  skipped:  not cloud-connected (run CloudConnect[] first)"]
]

(* The source (.md + .wl) lives on GitHub, which renders the markdown directly:
   https://github.com/sw1sh/MarkdownToNotebook . Submit outNb with the docked
   Submit button (or ResourceSubmit) to publish to the Function Repository. *)
print["build: done (source: github.com/sw1sh/MarkdownToNotebook)"]
