#!/usr/bin/env wolframscript
(* Self-hosting build: define MarkdownToNotebook from its own markdown source,
   then build and deploy *both* the forward converter (MarkdownToNotebook) and
   its inverse (NotebookToMarkdown) - each is a FunctionResource whose own
   markdown document inlines the shared MarkdownTools.wl plus its own .wl file.
   The only hand-written part is the tiny Definition-cell extractor below;
   everything else comes from the markdown. *)

(* the definition-notebook template version follows the kernel's
   DefinitionNotebookClient paclet; pull the latest so the generated notebook is
   not flagged "out of date" when opened in a newer front end. *)
Quiet @ PacletInstall["DefinitionNotebookClient", UpdateSites -> True]

(* pin the front end session to light up front: a headless session resolves the
   Automatic appearance to Dark, which would darken the example notebook thumbnails
   (rendered during conversion) and the deployed page. *)
Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"]

dir = DirectoryName[$InputFileName]

(* phase 1: pull every `#| file: path` reference out of the "## Definition" section
   of the markdown document and Get each in order. The forward and inverse docs
   both inline MarkdownTools.wl first (shared protocol) and then their own .wl,
   so this loop is the entire bootstrap for either resource. *)
definitionSection[t_String] := First[
    StringCases[t, StartOfLine ~~ "## Definition" ~~ "\n" ~~ Shortest[s___] ~~ ("\n## " | EndOfString) :> s, 1],
    ""
]
definitionCells[t_String] := StringCases[
    definitionSection[t],
    "```" ~~ ("wl" | "wolfram" | "mathematica") ~~ "\n" ~~ Shortest[c___] ~~ "\n```" :> c
]
includeFiles[t_String] := FileNameJoin[{dir, StringTrim[#]}] & /@
    StringCases[definitionSection[t], StartOfLine ~~ "#|" ~~ Whitespace... ~~ "file:" ~~ p : Except["\n"].. :> p]

loadDefinition[src_String] := Block[{text = Import[src, "Text"], includes},
    includes = includeFiles[text];
    If[ includes =!= {},
        Print["  including: ", FileNameTake /@ includes];
        Scan[Get, includes]
        ,
        Block[{boot = CreateFile[]},
            Export[boot, StringRiffle[definitionCells[text], "\n\n"], "Text"];
            Get[boot]
        ]
    ]
]

(* phase 2-5: convert one resource document end to end: define it from its own
   .wl includes, run the forward converter on it (cold + warm to demonstrate
   the persistent example cache), write the .nb, deploy it publicly to the
   cloud at the chosen stable URL. *)
buildOne[mdName_String, entrySymbol_Symbol, cloudPath_String] := Block[
    {src, text, coldTime, result, nb, warmTime, outNb, deployed},
    src = FileNameJoin[{dir, mdName}];
    text = Import[src, "Text"];
    Print[""];
    Print["build: ", mdName];
    loadDefinition[src];
    If[ DownValues[entrySymbol] === {},
        Print["  warn: ", SymbolName[entrySymbol], " has no definition after include"]
    ];
    Print["  converting (cold run)"];
    {coldTime, result} = AbsoluteTiming @ MarkdownToNotebook[src, "Association"];
    nb = result["Notebook"];
    Print["    Template:    ", result["Template"]];
    Print["    Name:        ", result["Metadata"]["Name"]];
    Print["    Sections:    ", result["Sections"]];
    Print["    Output cells:   ", Count[nb, Cell[_, "Output", ___], Infinity], " (evaluated examples)"];
    Print["    Unfilled slots: ", Count[nb, _TemplateSlot, Infinity]];
    Print["    cold run:    ", coldTime, " s"];
    warmTime = First @ AbsoluteTiming @ MarkdownToNotebook[src, "Association"];
    Print["    warm run:    ", warmTime, " s (", Length @ PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"], " cached)"];
    outNb = MarkdownToNotebook[src, FileNameJoin[{dir, FileBaseName[src] <> ".nb"}]];
    Print["    wrote:       ", FileNameTake[outNb], " (", Head @ Quiet @ Get[outNb], ")"];
    If[ TrueQ[$CloudConnected],
        deployed = UsingFrontEnd @ Block[{nbo, ro, rf},
            CurrentValue[$FrontEnd, LightDark] = "Light";
            nbo = NotebookOpen[File[outNb]];
            CurrentValue[nbo, CreateCellID] = True;
            SelectionMove[nbo, All, Notebook];
            FrontEndTokenExecute[nbo, "Save"];
            (* Quiet swallows ExpandFileName::badfile that the framework's
               fastPathHash cache fires when an Example notebook reference
               resolves to None during scraping. The message looks fatal
               but isn't; with it surfaced, the whole ResourceObject call
               returns $Failed and the deploy aborts. *)
            ro = Quiet @ ResourceObject[nbo];
            rf = ResourceFunction[ro];
            NotebookClose[nbo];
            CloudDeploy[rf, CloudObject[cloudPath], Permissions -> "Public"]
        ];
        Print["    deployed:    ", Replace[deployed, {
            co_CloudObject :> First[co],
            ro_ResourceObject :> ro["DocumentationLink"],
            a_Association :> Lookup[a, "ResultLink", a]
        }]]
        ,
        Print["    skipped:     not cloud-connected"]
    ]
]

(* clear the per-cell evaluation cache once up front so the cold-run numbers
   are honest; the warm-run inside buildOne measures the hit rate against the
   entries this cold run just wrote. *)
Print["build: clearing example cache"]
Scan[DeleteObject, PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]]

Print["build: connecting cloud"]
Needs["DefinitionNotebookClient`"]
If[ Not[TrueQ[$CloudConnected]], Quiet @ CloudConnect[] ]
If[ Not[TrueQ[$CloudConnected]], Print["  warn: not cloud-connected, deploy steps will be skipped"] ]

buildOne["MarkdownToNotebook.md", MarkdownToNotebook, "DeployedResources/Function/MarkdownToNotebook"]
buildOne["NotebookToMarkdown.md", NotebookToMarkdown, "DeployedResources/Function/NotebookToMarkdown"]

Print[""]
Print["build: done (source: github.com/sw1sh/MarkdownToNotebook)"]
