#!/usr/bin/env wolframscript
(* Self-hosting loop: define MarkdownToNotebook from its own markdown source,
   then run it on that same source to (re)produce its Function Repository
   definition notebook. The only hand-written part is the tiny Definition-cell
   extractor below; everything else comes from the markdown. *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

(* a self-contained page that renders the ORIGINAL markdown with marked.js;
   the markdown is embedded inline, so there is no cross-origin fetch (and
   hence no CORS dependency) and no third-party viewer site. A button links to
   a zip of the raw source (.md + .wl). *)
readerPage[mdText_String, zipUrl_String] := StringJoin[
    "<!doctype html><html><head><meta charset='utf-8'><title>MarkdownToNotebook</title>",
    "<script src='https://cdn.jsdelivr.net/npm/marked/marked.min.js'></script>",
    "<style>body{max-width:760px;margin:40px auto;font:16px/1.6 -apple-system,system-ui,sans-serif;padding:0 20px;color:#1a1a1a}",
    "pre{background:#f5f5f5;padding:12px;border-radius:6px;overflow:auto}code{font-family:Menlo,monospace}",
    "a.dl{display:inline-block;margin:0 0 24px;padding:8px 14px;background:#3b6ea5;color:#fff;text-decoration:none;border-radius:6px;font:14px sans-serif}</style>",
    "</head><body>",
    "<a class='dl' href='", zipUrl, "' download>Download source (.md + .wl)</a>",
    "<div id='c'></div>",
    "<script>document.getElementById('c').innerHTML=marked.parse(", ExportString[mdText, "JSON"], ");</script></body></html>"
]

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

print["bootstrap: defining function from ", FileNameTake[src]]
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
print["bootstrap: converting itself (cold run)"]
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

(* phase 4: write the definition notebook to disk *)
outNb = MarkdownToResourceFunction[src]
print["  wrote:       ", FileNameTake[outNb], " (", Head @ Quiet @ Get[outNb], ")"]

(* phase 5: zip the raw source (.md + .wl) and deploy a public reader page at
   the .md object that renders the original markdown and links to that zip. *)
print["bootstrap: publishing reader + source zip to the cloud"]
If[ Not[TrueQ[$CloudConnected]], Quiet @ CloudConnect[] ]
If[ TrueQ[$CloudConnected],
    zipPath = FileNameJoin[{$TemporaryDirectory, "MarkdownToNotebook.zip"}];
    If[ FileExistsQ[zipPath], DeleteFile[zipPath] ];
    CreateArchive[{src, FileNameJoin[{dir, "MarkdownToNotebook.wl"}]}, zipPath];
    CopyFile[zipPath, CloudObject["MarkdownToNotebook.zip", Permissions -> "Public"], OverwriteTarget -> True];
    zipUrl = First @ CloudObject["MarkdownToNotebook.zip"];
    reader = CloudDeploy[
        Delayed @ HTTPResponse[readerPage[text, zipUrl], <|"ContentType" -> "text/html"|>],
        CloudObject["MarkdownToNotebook.md"],
        Permissions -> "Public"
    ];
    Quiet @ DeleteObject[CloudObject["MarkdownToNotebook.html"]];
    print["  reader (.md): ", First[reader], " (renders the original markdown)"];
    print["  source zip:   ", zipUrl]
    ,
    print["  skipped:      not cloud-connected (run CloudConnect[] first)"]
]

print["bootstrap: done"]
