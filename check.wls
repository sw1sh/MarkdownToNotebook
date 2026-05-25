#!/usr/bin/env wolframscript
(* Run DefinitionNotebookClient`CheckDefinitionNotebook on every built .nb in
   the repo and print a hint summary per file. Mirrors the docked "Check"
   button on each resource notebook; CellIDs are stamped on open so the
   scraper can find cells (the headless build does not assign them). *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

Needs["DefinitionNotebookClient`"]

checkNb[path_String] := UsingFrontEnd @ Block[{nbo, ds},
    CurrentValue[$FrontEnd, LightDark] = "Light";
    nbo = NotebookOpen[File[path]];
    CurrentValue[nbo, CreateCellID] = True;
    SelectionMove[nbo, All, Notebook];
    FrontEndTokenExecute[nbo, "Save"];
    ds = Quiet @ DefinitionNotebookClient`CheckDefinitionNotebook[nbo];
    NotebookClose[nbo];
    Normal[ds]
]

paths = Select[Join[
    FileNames["*.nb", DirectoryName[$InputFileName]],
    FileNames["*.nb", FileNameJoin[{DirectoryName[$InputFileName], "examples"}]]
], FreeQ[#, "-out"] &]

Scan[
    p |-> Module[{hints = checkNb[p]},
        print[""];
        print["==== ", FileNameTake[p], " (", Length[hints], " hint", If[Length[hints] == 1, "", "s"], ") ===="];
        Scan[
            h |-> print["  [", h["Level"], "] ", h["Tag"], "  ", ToString[h["Parameters"], InputForm]],
            hints
        ]
    ],
    paths
]
