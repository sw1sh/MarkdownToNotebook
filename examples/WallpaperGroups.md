---
Template: Data
ResourceType: Data
Name: Seventeen Wallpaper Groups
Description: The complete classification of the seventeen plane symmetry groups, with IUC and orbifold notation, lattice type, point group, and rotation / mirror / glide counts
ContributedBy: MarkdownToNotebook
Keywords: [symmetry, wallpaper group, plane group, crystallography, tiling, group theory]
Categories: [Mathematics]
ContentTypes: [Numerical Data, Entity Store]
Author: MarkdownToNotebook
Date: 2026
Publisher: MarkdownToNotebook
GeographicCoverage: Global
TemporalCoverage: Timeless
Language: English
Rights: CC0
Citation: "MarkdownToNotebook (2026). Seventeen Wallpaper Groups. Wolfram Data Repository."
RelatedSymbols: [Polygon, RegularPolygon, GroupOrder, AffineTransform]
Links: ["[Wallpaper group (Wikipedia)](https://en.wikipedia.org/wiki/Wallpaper_group)", "[Orbifold notation (Wikipedia)](https://en.wikipedia.org/wiki/Orbifold_notation)"]
---

The plane has exactly seventeen distinct symmetry groups: any periodic pattern of
the plane belongs to one of them. The classification was completed by Fedorov in
1891 and rediscovered by Polya in 1924. This dataset gives the IUC short and full
symbols, Conway's orbifold notation, the underlying lattice type, the point group,
and the rotation orders / mirror / glide counts per fundamental domain for each
group.

## Details

- The seventeen groups partition by **point group**: $C_1, C_2, C_3, C_4, C_6$ for the rotation-only groups, and $D_1, D_2, D_3, D_4, D_6$ for those that add reflections. Five lattice types appear: oblique, rectangular, centered rectangular, square, and hexagonal.
- Conway's **orbifold notation** encodes the symmetry by enumerating the cone points (digits) and mirror boundaries ($*$, $\times$). Each of the seventeen orbifolds has Euler characteristic zero, the defining condition that makes the symmetry group crystallographic.
- The `RotationOrders` field lists the orders of all rotation centers in one fundamental domain; `Mirrors` and `Glides` count the distinct mirror and glide-reflection axes.
- Two pairs (p3m1 / p31m, p4m / p4g) share rotation orders and isomorphic point groups; they differ in how the mirrors meet the rotation centers - p3m1 has mirrors at every 3-fold center, p31m only at half of them.

## Content

The full classification, keyed by the IUC short symbol.

```wl
wallpaperGroups = <|
    "p1"   -> <|"FullSymbol" -> "p1",   "Orbifold" -> "o",      "Lattice" -> "Oblique",           "PointGroup" -> "C1", "RotationOrders" -> {},        "Mirrors" -> 0, "Glides" -> 0|>,
    "p2"   -> <|"FullSymbol" -> "p211", "Orbifold" -> "2222",   "Lattice" -> "Oblique",           "PointGroup" -> "C2", "RotationOrders" -> {2,2,2,2}, "Mirrors" -> 0, "Glides" -> 0|>,
    "pm"   -> <|"FullSymbol" -> "p1m1", "Orbifold" -> "**",     "Lattice" -> "Rectangular",       "PointGroup" -> "D1", "RotationOrders" -> {},        "Mirrors" -> 2, "Glides" -> 0|>,
    "pg"   -> <|"FullSymbol" -> "p1g1", "Orbifold" -> "xx",     "Lattice" -> "Rectangular",       "PointGroup" -> "D1", "RotationOrders" -> {},        "Mirrors" -> 0, "Glides" -> 2|>,
    "cm"   -> <|"FullSymbol" -> "c1m1", "Orbifold" -> "*x",     "Lattice" -> "Centered Rectangular", "PointGroup" -> "D1", "RotationOrders" -> {},     "Mirrors" -> 1, "Glides" -> 1|>,
    "pmm"  -> <|"FullSymbol" -> "p2mm", "Orbifold" -> "*2222",  "Lattice" -> "Rectangular",       "PointGroup" -> "D2", "RotationOrders" -> {2,2,2,2}, "Mirrors" -> 4, "Glides" -> 0|>,
    "pmg"  -> <|"FullSymbol" -> "p2mg", "Orbifold" -> "22*",    "Lattice" -> "Rectangular",       "PointGroup" -> "D2", "RotationOrders" -> {2,2},     "Mirrors" -> 1, "Glides" -> 2|>,
    "pgg"  -> <|"FullSymbol" -> "p2gg", "Orbifold" -> "22x",    "Lattice" -> "Rectangular",       "PointGroup" -> "D2", "RotationOrders" -> {2,2},     "Mirrors" -> 0, "Glides" -> 2|>,
    "cmm"  -> <|"FullSymbol" -> "c2mm", "Orbifold" -> "2*22",   "Lattice" -> "Centered Rectangular", "PointGroup" -> "D2", "RotationOrders" -> {2,2},  "Mirrors" -> 2, "Glides" -> 2|>,
    "p4"   -> <|"FullSymbol" -> "p4",   "Orbifold" -> "442",    "Lattice" -> "Square",            "PointGroup" -> "C4", "RotationOrders" -> {4,4,2},   "Mirrors" -> 0, "Glides" -> 0|>,
    "p4m"  -> <|"FullSymbol" -> "p4mm", "Orbifold" -> "*442",   "Lattice" -> "Square",            "PointGroup" -> "D4", "RotationOrders" -> {4,4,2},   "Mirrors" -> 4, "Glides" -> 2|>,
    "p4g"  -> <|"FullSymbol" -> "p4gm", "Orbifold" -> "4*2",    "Lattice" -> "Square",            "PointGroup" -> "D4", "RotationOrders" -> {4,4,2},   "Mirrors" -> 2, "Glides" -> 2|>,
    "p3"   -> <|"FullSymbol" -> "p3",   "Orbifold" -> "333",    "Lattice" -> "Hexagonal",         "PointGroup" -> "C3", "RotationOrders" -> {3,3,3},   "Mirrors" -> 0, "Glides" -> 0|>,
    "p3m1" -> <|"FullSymbol" -> "p3m1", "Orbifold" -> "*333",   "Lattice" -> "Hexagonal",         "PointGroup" -> "D3", "RotationOrders" -> {3,3,3},   "Mirrors" -> 3, "Glides" -> 3|>,
    "p31m" -> <|"FullSymbol" -> "p31m", "Orbifold" -> "3*3",    "Lattice" -> "Hexagonal",         "PointGroup" -> "D3", "RotationOrders" -> {3,3,3},   "Mirrors" -> 3, "Glides" -> 3|>,
    "p6"   -> <|"FullSymbol" -> "p6",   "Orbifold" -> "632",    "Lattice" -> "Hexagonal",         "PointGroup" -> "C6", "RotationOrders" -> {6,3,2},   "Mirrors" -> 0, "Glides" -> 0|>,
    "p6m"  -> <|"FullSymbol" -> "p6mm", "Orbifold" -> "*632",   "Lattice" -> "Hexagonal",         "PointGroup" -> "D6", "RotationOrders" -> {6,3,2},   "Mirrors" -> 6, "Glides" -> 6|>
|>;
```

The resource stores the classification as primary content (so `$$Data` is the whole
association) and the per-group lattice / point-group / orbifold fields as named
content elements, fetched with [`ResourceData`].

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]]] = wallpaperGroups
```

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]], "ByLattice"] = GroupBy[Values[wallpaperGroups], #["Lattice"] &, Length]
```

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]], "ByPointGroup"] = GroupBy[Values[wallpaperGroups], #["PointGroup"] &, Length]
```

## Basic Examples

Look up a single group. p4m, the symmetry group of a square grid with mirrors and
diagonals, has $D_4$ point symmetry and four mirror axes plus two glide axes per
fundamental domain.

```wl
wallpaperGroups["p4m"]
```

The dataset is a flat association of 17 entries:

```wl
Length[wallpaperGroups]
```

<!-- => 17 -->

## Scope & Additional Elements

The seventeen groups distribute across five lattice types. The hexagonal lattice
hosts five of them (the only one that supports 3- and 6-fold rotations); the
oblique lattice, having the least symmetry, hosts only two.

```wl
Dataset @ ReverseSort @ Counts[Values[wallpaperGroups][[All, "Lattice"]]]
```

By point group, the C / D pairs reflect whether reflections are added to the
rotations.

```wl
Dataset @ KeySort @ Counts[Values[wallpaperGroups][[All, "PointGroup"]]]
```

## Visualizations

The mirror / glide counts per fundamental domain, ordered by IUC symbol, highlight
which groups carry many reflection axes (p4m, p6m) versus only rotations (p1, p2,
p3, p4, p6).

```wl
keys = Keys[wallpaperGroups];
BarChart[
    {wallpaperGroups[#, "Mirrors"], wallpaperGroups[#, "Glides"]} & /@ keys,
    ChartLayout -> "Grouped",
    ChartLegends -> {"mirrors", "glides"},
    ChartLabels -> {keys, None},
    PlotLabel -> "Reflection axes per fundamental domain"
]
```

A simple geometric showcase: render the rotation lattices of the three highest-symmetry
groups by placing rotation-center markers on the appropriate unit cell.

```wl
latticePlot[name_String, poly_, centers_] := Graphics[{
        FaceForm[None], EdgeForm[GrayLevel[0.6]], Polygon[poly],
        AbsolutePointSize[8], RGBColor[0.85, 0.35, 0.1], Point[centers]},
    PlotLabel -> Style[name, Bold], ImageSize -> 220];
square = {{0,0}, {1,0}, {1,1}, {0,1}};
squareCenters = {{0,0}, {1,0}, {1,1}, {0,1}, {0.5,0.5}, {0.5,0}, {0,0.5}, {1,0.5}, {0.5,1}};
hex = Table[{Cos[t], Sin[t]}, {t, 0., 2 Pi - 0.01, Pi/3}];
hexCenters = Table[{Cos[t]/Sqrt[3], Sin[t]/Sqrt[3]}, {t, Pi/6, 2 Pi, Pi/3}];
Row[{
    latticePlot["square (p4m centers)", square, squareCenters],
    Spacer[20],
    latticePlot["hexagon (p6m centers)", hex, hexCenters]
}]
```

## Analysis

Conway's orbifold notation makes the Euler-characteristic computation explicit.
For a wallpaper group with cone points of orders $n_1, n_2, \dots$ (digits before
the first `*`), mirror boundaries with corner orders $m_1, m_2, \dots$ (digits
after `*`), and counts of `*` (boundary components) and `x` (cross-caps), the
orbifold Euler characteristic is

$$ \chi = -k_* - k_\times + \sum_i \left(1 - \frac{1}{n_i}\right) + \frac{1}{2}\sum_j \left(1 - \frac{1}{m_j}\right) + 2 $$

(here written with the conventional factor of $2$ for the underlying sphere); all
seventeen groups must satisfy $\chi = 0$, since they are exactly the planar
period groups. Verifying numerically for a few representative entries:

```wl
orbifoldChi[sig_String] := Block[{
        stars = StringCount[sig, "*"],
        crosses = StringCount[sig, "x"],
        oContrib = 2 StringCount[sig, "o"],     (* the torus base costs 2 *)
        mark, before, after
    },
    mark = First[StringPosition[sig, "*", 1], {StringLength[sig] + 1, 0}][[1]];
    before = ToExpression /@ StringCases[StringTake[sig, mark - 1], DigitCharacter];
    after = ToExpression /@ StringCases[StringDrop[sig, mark - 1], DigitCharacter];
    2 - stars - crosses - oContrib - Total[1 - 1/before] - Total[1 - 1/after]/2
];
orbifoldChi /@ {"o", "2222", "*632", "*442", "333", "*333"}
```

<!-- => {0, 0, 0, 0, 0, 0} -->

All seventeen orbifolds have characteristic zero, the equation that classifies them
as the wallpaper groups.

```wl
ReverseSort @ Counts[orbifoldChi /@ Values[wallpaperGroups][[All, "Orbifold"]]]
```
