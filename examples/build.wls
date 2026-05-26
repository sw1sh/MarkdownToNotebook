#!/usr/bin/env wolframscript
(* Build the Example Repository definition notebooks from every examples/*.md
   document. Loads the converter from the parent directory and runs it on each
   top-level example markdown, writing a sibling .nb. The one-level glob skips the
   AccessibleColors submodule (its own .md files are nested) and the generated
   *-out.md twins. After the build each notebook is also deployed publicly to the
   cloud so the Applications section of MarkdownToNotebook.md can link a live URL
   for every template type. *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

(* match the deployed-notebook appearance: pin the front end to light so the
   example-notebook thumbnails rendered during conversion are not darkened. *)
Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"]

dir = DirectoryName[$InputFileName]
Get[FileNameJoin[{ParentDirectory[dir], "MarkdownToNotebook.wl"}]]

(* cold run: clear the persistent example cache so the examples re-evaluate *)
Scan[DeleteObject, PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]]

sources = Select[FileNames["*.md", dir], ! StringEndsQ[#, "-out.md"] &]
print["build: ", Length[sources], " example document(s) in ", FileNameTake[dir]]

(* Same deploy idiom as ../build.wls phase 5: open the notebook in a real front
   end, stamp CellIDs and save so the headless scraper can see every cell, build
   a ResourceObject (the docked-toolbar deploy buttons all go through one), wrap
   it as a ResourceFunction for the FunctionResource template, then CloudDeploy
   to a stable public URL keyed by template + name. Round-tripping through
   ResourceObject is what makes DeployResource[..., "CloudPublic"] from the
   notebook's own toolbar actually capture the right thing in batch mode (a bare
   DeployResource[nbo, ...] re-scrapes empty headlessly). *)
deployResource[outNb_, template_String, name_String] := UsingFrontEnd @ Block[
    {nbObj, ro, payload, target, deployed},
    target = CloudObject["DeployedResources/" <> template <> "/" <> StringReplace[name, " " -> ""]];
    CurrentValue[$FrontEnd, LightDark] = "Light";
    nbObj = NotebookOpen[File[outNb]];
    CurrentValue[nbObj, CreateCellID] = True;
    SelectionMove[nbObj, All, Notebook];
    FrontEndTokenExecute[nbObj, "Save"];
    (* a Computational Essay has no resource-system metadata to scrape - the
       deployable artifact is just the notebook itself, hosted at a public
       CloudObject URL (the way Notebook Archive does for its essay
       collection). For every other template, build a ResourceObject from
       the notebook so the deploy carries the resource definition. *)
    If[template === "ComputationalEssay" || template === "Essay",
        payload = NotebookGet[nbObj]
        ,
        ro = ResourceObject[nbObj];
        payload = If[template === "FunctionResource", ResourceFunction[ro], ro]
    ];
    (* deploy BEFORE closing - ResourceObject lazily reads the example subnotebook
       from the still-open front-end notebook, so closing first triggers
       ResourceObject::depnbcl and drops every Examples cell from the deployed
       resource. *)
    deployed = CloudDeploy[payload, target, Permissions -> "Public"];
    NotebookClose[nbObj];
    deployed
]

deployedURL[obj_] := Replace[obj, {
    co_CloudObject :> First[co],
    ro_ResourceObject :> ro["DocumentationLink"],
    a_Association :> Lookup[a, "ResultLink", a]
}]

cloudReady = TrueQ[$CloudConnected] || (Quiet @ CloudConnect[]; TrueQ[$CloudConnected])
If[ ! cloudReady, print["  warn: not cloud-connected, deploy steps will be skipped"] ]

Scan[
    src |-> Block[{result, nb, outNb, deployed},
        result = MarkdownToNotebook[src, "Association"];
        nb = result["Notebook"];
        outNb = MarkdownToNotebook[src, FileNameJoin[{dir, FileBaseName[src] <> ".nb"}]];
        print["  ", FileNameTake[src]];
        print["    Template:       ", result["Template"]];
        print["    Name:           ", result["Metadata"]["Name"]];
        print["    Output cells:   ", Count[nb, Cell[_, "Output", ___], Infinity], " (evaluated examples)"];
        print["    Unfilled slots: ", Count[nb, _TemplateSlot, Infinity]];
        print["    wrote:          ", FileNameTake[outNb], " (", Head @ Quiet @ Get[outNb], ")"];
        If[ cloudReady,
            deployed = deployResource[outNb, result["Template"], result["Metadata"]["Name"]];
            print["    deployed:       ", deployedURL[deployed]]
        ]
    ],
    sources
]

print["build: done"]
