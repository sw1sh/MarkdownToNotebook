---
Template: Example
ResourceType: Example
Name: Discrete-Time Quantum Walk on a Line
Description: Probability distributions of a Hadamard-coin quantum walk and its ballistic spreading
ContributedBy: MarkdownToNotebook
Keywords: [quantum walk, Hadamard coin, ballistic transport, random walk, interference]
Categories: [Quantum Computation, Visualization & Graphics]
RelatedSymbols: [NestList, ArrayPlot, RandomWalkProcess, ListStepPlot]
Links: ["[Quantum walk (Wikipedia)](https://en.wikipedia.org/wiki/Quantum_walk)"]
---

The discrete-time quantum walk is the quantum analogue of the classical random
walk. A walker on the integer line carries a two-state *coin*; each step applies a
Hadamard coin flip and then shifts the walker left or right conditioned on the coin
state. Because the amplitudes interfere instead of adding as probabilities, the walk
spreads *ballistically*: its standard deviation grows like $t$ rather than the
classical $\sqrt{t}$, producing the characteristic two-horned distribution.

## Content

The walk acts on the tensor product of a position register (sites $-n \dots n$) and
a coin qubit, in the basis order $\{R, L\}$. One step is the spin-conditioned shift
$S$ applied after the Hadamard coin $H \otimes I$.

```wl
quantumWalk[n_] := Module[{hadamard = {{1, 1}, {1, -1}} / Sqrt[2], psi, step},
    psi = ConstantArray[0, {2 n + 1, 2}];
    psi[[n + 1]] = {1, I} / Sqrt[2];                  (* start at 0, with a symmetric coin *)
    step[s_] := With[{c = s . Transpose[hadamard]},
        Transpose[{RotateRight[c[[All, 1]]], RotateLeft[c[[All, 2]]]}]
    ];
    Total[Abs[#]^2, {2}] & /@ NestList[step, psi, n]  (* P[t, x] for t = 0 to n *)
]
```

The resource stores the full time evolution and the final distribution as content
elements, fetched with [`ResourceData`].

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]], "TimeEvolution"] = quantumWalk[100]
```

```wl
#| eval: false
ResourceData[ResourceObject[EvaluationNotebook[]], "FinalDistribution"] = AssociationThread[Range[-100, 100] -> Last[quantumWalk[100]]]
```

## Examples

After 100 steps the distribution has two sharp peaks near $\pm n / \sqrt{2}$, far
from the origin where a classical walker would concentrate. Only same-parity sites
are occupied at each step, so plot every other site.

```wl
points[p_] := Transpose[{Range[-100, 100], p}][[1 ;; ;; 2]];
distribution = Last[quantumWalk[100]];
ListPlot[points[distribution], Filling -> Axis, PlotRange -> All, AxesLabel -> {"position", "probability"}]
```

The classical random walk of the same length is a binomial distribution: a single
Gaussian peak at the origin. Overlaying the two shows ballistic versus diffusive
transport.

```wl
classical = Table[If[EvenQ[x], Binomial[100, (x + 100) / 2] / 2^100, 0], {x, -100, 100}];
ListPlot[{points[distribution], points[classical]}, Filling -> Axis, PlotRange -> All, PlotLegends -> {"quantum", "classical"}]
```

---

The spreading rates differ qualitatively: the quantum standard deviation grows
linearly in the number of steps, while the classical one grows like $\sqrt{t}$.

```wl
sites = Range[-100, 100];
spread[p_] := Sqrt[p . sites^2 - (p . sites)^2];
evolution = quantumWalk[100];
ListLinePlot[
    {
        Table[{t, spread[evolution[[t + 1]]]}, {t, 0, 100}],
        Table[{t, Sqrt[t]}, {t, 0, 100}]
    },
    PlotLegends -> {"quantum (~ t)", "classical (~ Sqrt[t])"},
    AxesLabel -> {"steps", "std. dev."}
]
```

## Hero Image

```wl
ArrayPlot[Reverse[quantumWalk[100]],
    ColorFunction -> "SunsetColors", Frame -> False, AspectRatio -> 3/5, ImageSize -> 600]
```
