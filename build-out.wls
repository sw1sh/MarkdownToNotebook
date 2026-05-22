#!/usr/bin/env wolframscript
(* Generate the GitHub-renderable markdown twin of the definition document:
   MarkdownToNotebook-out.md, with every evaluated example output rasterized to a
   dark-mode PNG under images/. This is the ".md" target of the converter itself
   (MarkdownToNotebook[source, "out.md"]); the dark renderings are pinned with the
   $lightDark global so the twin reads well against GitHub's dark theme. *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

dir = DirectoryName[$InputFileName];
SetDirectory[dir];
Get[FileNameJoin[{dir, "MarkdownToNotebook.wl"}]];

(* render the example outputs in dark mode *)
$lightDark = "Dark";

(* cold run: clear the persistent example cache so screenshots re-evaluate dark *)
Scan[DeleteObject, PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]];

src = FileNameJoin[{dir, "MarkdownToNotebook.md"}];
out = FileNameJoin[{dir, "MarkdownToNotebook-out.md"}];

(* hold one front-end session (set to dark) open across the whole pass: the
   example evaluation and the per-output rasterizations both need it, and a
   headless session resolves the Automatic appearance to dark anyway. *)
print["build-out: generating ", FileNameTake[out]];
UsingFrontEnd[
    CurrentValue[$FrontEnd, LightDark] = "Dark";
    MarkdownToNotebook[src, out]
];
print["build-out: wrote ", FileNameTake[out], " (+ images/)"];
