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

(* pin the front end session to light up front: a headless session resolves the
   Automatic appearance to Dark, which would darken the example notebook thumbnails
   (rendered during conversion) and the deployed page. *)
Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"]

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

(* phase 2: run the function on its own source (cold). Clear the persistent example
   cache first (the built-in mechanism the converter now uses) so this is a true
   cold run. *)
print["build: converting itself (cold run)"]
Scan[DeleteObject, PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]]

{coldTime, result} = AbsoluteTiming @ MarkdownToNotebook[src, "Association"]
nb = result["Notebook"]

print["  Template:    ", result["Template"]]
print["  Name:        ", result["Metadata"]["Name"]]
print["  Sections:    ", result["Sections"]]
print["  Notebook head:  ", Head[nb]]
print["  Output cells:   ", Count[nb, Cell[_, "Output", ___], Infinity], " (evaluated examples)"]
print["  Unfilled slots: ", Count[nb, _TemplateSlot, Infinity]]
print["  cold run:    ", coldTime, " s"]

(* phase 3: re-run to demonstrate the persistent example cache (no re-evaluation) *)
{warmTime, warmResult} = AbsoluteTiming @ MarkdownToNotebook[src, "Association"]
print["  warm run:    ", warmTime, " s (", Length @ PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"], " cached)"]

(* phase 4: write the definition notebook to disk (a file target makes the
   function write rather than just return the Notebook) *)
outNb = MarkdownToNotebook[src, FileNameJoin[{dir, "MarkdownToNotebook.nb"}]]
print["  wrote:       ", FileNameTake[outNb], " (", Head @ Quiet @ Get[outNb], ")"]

(* phase 5: deploy the resource function publicly to the cloud, running exactly the
   docked "Deploy > Publicly in the cloud" button's own code (from
   FunctionResourceDefinitionStyles.nb): set the two button-state globals, then
   DeployResource[notebook, "CloudPublic"]. The earlier 3-argument
   DeployResource["Function", nbo, ...] form is a different overload that did not
   scrape the function definition, so the deployed resource came back empty. *)
print["build: deploying the resource function publicly to the cloud"]
Needs["DefinitionNotebookClient`"]
If[ Not[TrueQ[$CloudConnected]], Quiet @ CloudConnect[] ]
If[ TrueQ[$CloudConnected],
    (* the deployed page is generated through the local front end; pin that session
       to light so the published page is not rendered in dark mode (the build front
       end resolves the Automatic appearance to Dark otherwise). *)
    deployed = UsingFrontEnd @ Block[{nbo, res},
        CurrentValue[$FrontEnd, LightDark] = "Light";
        nbo = NotebookOpen[File[outNb]];
        (* the headless front end does not assign CellIDs on open, so the resource
           scraper cannot find the definition cell and deploys an empty function.
           Turn on CreateCellID and save once to make the front end stamp every cell
           with an ID (what happens automatically when a person edits the notebook),
           so the scrape sees the definition. *)
        CurrentValue[nbo, CreateCellID] = True;
        SelectionMove[nbo, All, Notebook];
        FrontEndTokenExecute[nbo, "Save"];
        DefinitionNotebookClient`$ClickedButton = "Deploy";
        DefinitionNotebookClient`$ClickedAction = "Publicly in the cloud";
        res = DefinitionNotebookClient`DeployResource[nbo, "CloudPublic"];
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
