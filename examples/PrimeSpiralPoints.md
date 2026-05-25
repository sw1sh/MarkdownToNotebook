---
Template: Example
ResourceType: Example
Name: Prime Spiral Points
Description: Planar coordinates that place the first primes on a polar spiral
ContributedBy: MarkdownToNotebook
Keywords: [primes, spiral, polar coordinates, visualization]
Categories: [Visualization & Graphics, Puzzles and Recreation]
RelatedSymbols: [Prime, ListPlot]
Links: ["[Prime spirals](https://en.wikipedia.org/wiki/Ulam_spiral)"]
---

## Content

The resource exposes one content element, `"Points"`: the polar coordinates
$(p_n \cos n, p_n \sin n)$ for the first 200 primes $p_n$. Fetch it with
[`ResourceData`]().

```wl
ResourceData[ResourceObject[EvaluationNotebook[]], "Points"] = Table[{Prime[n] Cos[n], Prime[n] Sin[n]}, {n, 200}];
```

## Examples

The content is a list of 200 planar points.

```wl
points = Table[{Prime[n] Cos[n], Prime[n] Sin[n]}, {n, 200}];
Length[points]
```

<!-- => 200 -->

Plotting them traces a loose spiral, since consecutive primes grow almost
linearly while the angle winds around.

```wl
ListPlot[points, AspectRatio -> 1]
```

## Hero Image

```wl
ListPlot[Table[{Prime[n] Cos[n], Prime[n] Sin[n]}, {n, 200}], AspectRatio -> 1, Axes -> False, PlotStyle -> PointSize[0.012]]
```
