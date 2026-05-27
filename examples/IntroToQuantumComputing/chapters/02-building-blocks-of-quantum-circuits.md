---
Template: Chapter
Name: Building Blocks of Quantum Circuits
ChapterNumber: 2
ShowPageBreaks: true
Context: Wolfram`QuantumFramework`
---

# Building Blocks of Quantum Circuits

In this chapter we review the common procedure for a quantum algorithm: a state is prepared, some quantum operations are applied, and then measurements are taken. We show how this is captured in an object called a *quantum circuit*. Along the way we introduce the supporting concepts of *quantum state*, *quantum operator*, and *quantum basis*, and we explore the geometric picture of one-qubit states given by the *Bloch sphere*.

## Key Concepts

- Quantum state
- Register state
- Quantum operator
- Bloch sphere
- Computational basis
- Bra-ket notation

## Quantum Operations

Let's consider a generic quantum circuit:

```wl
QuantumCircuitOperator[{
    "H", "S" -> 2, "C"["RY"[Pi/3]] -> {1, 2},
    "C"["NOT" -> 2, {}, {1}], "BitFlip", "SWAP", {1}
}]["Diagram"]
```

Let's read this circuit step by step (some details may be unfamiliar; we will return to them later):

- Since no initial state is given, the two qubits are prepared in the register state `Ket[{00}]`.
- A Hadamard gate `H` acts on qubit 1.
- An `S` gate acts on qubit 2.
- A conditional rotation about $Y$ by angle $\pi/3$ acts on both qubits: if qubit 1 is in state `Ket[{1}]`, apply the rotation on qubit 2; otherwise do nothing.
- A conditional-0 `NOT` acts on both qubits: if qubit 1 is in state `Ket[{0}]`, apply an `X` (`NOT`) to qubit 2; otherwise do nothing.
- A bit-flip noise channel acts on qubit 1 with rate $1/2$.
- A `SWAP` gate acts on both qubits.
- Qubit 1 is measured in the computational basis.

In classical computation, we use rules to map input states to output states. Quantum operators serve a similar role: they are the rules that transform one quantum state into another. Unlike classical rules, however, they must obey specific constraints set by the formalism of quantum mechanics; in particular, they are linear and (apart from measurements and noise channels) unitary. In the language of quantum computing you will often hear these operators described as "gates" or "gate operations" — terminology borrowed from classical computer engineering.

## Quantum States

In classical digital computing, states are represented by sequences of $1$s and $0$s. Each classical bit has two possible states, $0$ or $1$. A sequence of two bits has four possible states: `"00"`, `"01"`, `"10"`, or `"11"`. In general, a sequence of $n$ classical bits has $2^n$ possible states.

Quantum states behave differently. When a quantum state is measured, the outcome is always a definite classical result — but the act of measurement inevitably changes the state, a phenomenon known as *state collapse*. Unlike classical states, quantum states can exist in *superpositions*. Still, there are special quantum states called *computational basis states* that always yield the same classical result when measured. These states can be labeled directly by a classical bit string.

If quantum operators in a circuit diagram are the instructions for changing a state, what do we assume about the input state? By convention, most quantum circuit diagrams begin with the *register state* — the special basis state that always yields the classical result of all zeros when the qubits are measured.

The one-qubit register state can be written as follows:

```wl
QuantumState["Register"]
```

The Wolfram Quantum Framework returns a summary box for quantum objects because it is much more convenient in practice. Unless the system is very small, other notations — such as full Dirac expressions — are not especially useful for everyday work.

The traditional form of a quantum state returns the conventional Dirac notation:

```wl
QuantumState["Register"] // TraditionalForm
```

The above state can be written in different equivalent ways:

```wl
QuantumState["0"]
```

Check they are the same:

```wl
QuantumState["Register"] == QuantumState["0"]
```

The two-qubit register state can be written like this:

```wl
QuantumState["Register"[2]] // TraditionalForm
```

And so on:

```wl
TraditionalForm /@ Table[QuantumState["Register"[n]], {n, 3, 6}]
```

Throughout this course we follow the big-endian (usual Dirac) convention, as opposed to the little-endian (usual IBM) convention. In big-endian, a state such as `Ket[{01}]` means qubit-1 is in the state `Ket[{0}]` and qubit-2 is in the state `Ket[{1}]`.

A register state `Ket[{0^⊗n}]` is shorthand for a unit vector of length $2^n$ whose first element is one and all others are zero:

```wl
Table["n=" <> ToString[n] -> Normal @ QuantumState[
    StringJoin @ ConstantArray["0", n]]["StateVector"], {n, 5}] // Column
```

We will discuss quantum states in much more detail in the following chapters. For now, let's focus on different visualizations of a state, without diving deeply into their full meaning.

## Bloch Sphere

Since qubits are not the same as classical bits, labeling them by classical bit sequences is insufficient to represent all possible qubit states. How then are quantum states represented?

Future lessons will discuss representing quantum states in more detail. In fact, much of the formalism of quantum mechanics is an important application of [linear algebra](https://www.wolfram.com/wolfram-u/courses/mathematics/introduction-to-linear-algebra/). However, there is a very useful graphical representation of one-qubit states called the **Bloch sphere**, named after physicist Felix Bloch.

In this approach a quantum state is represented by a point in 3D space inside a sphere of radius 1 (the Bloch sphere). The point may lie on the surface, in which case we call it a *pure* state, or inside the sphere, in which case we call it a *mixed* state.

Compute the Bloch vector of `Ket[{0}]`:

```wl
QuantumState["0"]["BlochVector"]
```

The Bloch sphere representation of the qubit state `Ket[{0}]`:

```wl
QuantumState["0"]["BlochPlot"]
```

Compute the Bloch vector of `Ket[{1}]`:

```wl
QuantumState["1"]["BlochVector"]
```

Notice that the qubit state `Ket[{1}]` is on the opposite side of the sphere from `Ket[{0}]`.

```wl
QuantumState["1"]["BlochPlot"]
```

The use of a sphere already suggests that the space of one-qubit states is much richer than only $0$ or $1$ as in classical bits. The states labeled `Ket[{+}]`, `Ket[{-}]`, `Ket[{L}]`, and `Ket[{R}]` are other specific states the qubits can attain. However, `Ket[{0}]` and `Ket[{1}]` are the canonical *computational basis* states. To read out a result from the qubits that can be used in digital computation, you must measure the state of the qubit in the chosen computational basis.

Physically, there is some arbitrariness in how the states on the Bloch sphere are labeled. What matters is that the designer of a quantum computer chooses two easily-measurable quantum states to serve as the logical values of a classical $0$ and a classical $1$. Quantum operations can then rotate or transform qubits into other states on the Bloch sphere; this ability is precisely what makes quantum computation more powerful than classical computation. In practice the final step in a quantum circuit is always to measure the qubits in the chosen computational basis, so that the result can be expressed in classical bits.

When thinking about the state of a qubit, you can view it in several equivalent ways:

- As a linear combination (a complex-valued 2-vector) in the computational basis.
- As a 3-vector representing Cartesian coordinates of the Bloch vector $\{x, y, z\}$.
- As the same point in spherical coordinates $\{r, \varphi, \theta\}$.
- For pure states, the Bloch vector lies on the unit sphere ($r = 1$); for mixed states, it lies inside the sphere ($0 \le r < 1$). We will discuss pure and mixed states in more detail later.

Generate different representations of a random state:

```wl
state = QuantumState["RandomPure"];
Grid[Transpose[{
    {"Dirac notation", "State vector", "Bloch vector",
     "Bloch spherical coordinates", "Bloch plot"},
    {TraditionalForm[state], state["AmplitudesList"],
     state["BlochVector"], state["BlochSphericalCoordinates"],
     state["BlochPlot"]}
}], Frame -> All, Alignment -> Left]
```

## Bra-Ket Notation

In the formalism of quantum mechanics, how to represent and write down the various concepts is an important question. For some common quantum operations, bra-ket notation is particularly useful. This is also sometimes called *Dirac notation* after P. A. M. Dirac.

In general, a **ket** `Ket[{…}]` is a shorthand representation for a vector, and a **bra** `Bra[{…}]` is the conjugate transpose of a ket. For example, for a single qubit:

$$ \lvert\psi\rangle = \begin{pmatrix} \alpha \\ \beta \end{pmatrix}, \qquad \langle\psi\rvert = \begin{pmatrix} \alpha^{*} & \beta^{*} \end{pmatrix}. $$

From these definitions, a ket-bra `Ket[{…}]Bra[{…}]` represents a matrix:

```wl
ClearAll[a, b, \[Alpha], \[Beta]];
Row[{
    "Ket[{\[Psi]}]" -> MatrixForm[{a, b}], "  ",
    "Ket[{\[Phi]}]" -> MatrixForm[{\[Alpha], \[Beta]}], " => ",
    "Ket[{\[Psi]}]Bra[{\[Phi]}]" -> MatrixForm[
        KroneckerProduct[{a, b}, {Conjugate[\[Alpha]], Conjugate[\[Beta]]}]]
}]
```

Show the matrix form and the Dirac notation of the NOT gate:

```wl
MatrixForm[QuantumOperator["NOT"]["Matrix"]] -> TraditionalForm[QuantumOperator["NOT"]]
```

Show the elements in the Dirac notation of $R_Y$ rotation by angle $\pi/3$:

```wl
QuantumOperator["RY"[Pi/3]]["Table"]
```

Show the Dirac notation of the controlled-Hadamard gate:

```wl
QuantumOperator["CH"] // TraditionalForm
```

In summary, the ket notation `Ket[{…}]` represents a complex-valued vector, and the bra notation `Bra[{…}]` is its conjugate transpose. A composite state such as `Ket[{00}]` is shorthand for the tensor product `Ket[{0}] ⊗ Ket[{0}]`; similarly, `Ket[{0}]Bra[{1}]` means `Ket[{0}] ⊗ Bra[{1}]`. We will discuss these details further in future chapters.

## Effects of Operations on Qubits

Consider the following circuit:

```wl
QuantumCircuitOperator[{"H", {1}}]["Diagram", ImageSize -> 200]
```

The gate labeled "H" is called a **Hadamard gate**, named after the French mathematician Jacques Salomon Hadamard.

::: solved-example
**Hadamard on the register state.** Apply a Hadamard to the register state `Ket[{0}]` and visualize the resulting state on the Bloch sphere; then add a measurement in the computational basis and visualize the probability distribution.

```wl
With[{circuit = QuantumCircuitOperator[{"H" -> 1}], size = 200},
    Row[{
        circuit["Diagram", ImageSize -> {size, Automatic}],
        circuit[]["BlochPlot", ImageSize -> size]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

```wl
With[{circuit = QuantumCircuitOperator[{"H" -> 1, "M" -> 1}], size = 200},
    Row[{
        circuit["Diagram", ImageSize -> {size, Automatic}],
        circuit[]["ProbabilityPlot", ImageSize -> size]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

After applying a Hadamard to the register state and measuring in the computational basis, you get `Ket[{0}]` and `Ket[{1}]` each with probability $1/2$. The Bloch vector lies in the equatorial plane, halfway between the north pole `Ket[{0}]` and the south pole `Ket[{1}]`; measurement in the computational basis is geometrically the projection of that vector onto the $Z$-axis.
:::

### A Quick Note on Measurement

You might wonder at what point probabilities enter the picture. Does the Hadamard gate introduce the need for probability, or does the measurement? Before answering, what happens if a *different* measurement is performed — one with a special relationship to the Hadamard?

```wl
With[{circuit = QuantumCircuitOperator[{"H" -> 1, "M"["X"] -> 1}], size = 200},
    Row[{
        circuit["Diagram", ImageSize -> {size, Automatic}],
        circuit[]["ProbabilitiesPlot", ImageSize -> size]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

Performing this measurement (in the $X$ basis rather than the computational $Z$ basis) gives the same result with $100\%$ probability after applying the Hadamard. So there are cases where measurement *also* does not lead to probabilistic results.

Probability is only necessary when the quantum state before measurement is not in the same basis as the measurement being performed. If you want precise details about this feature of quantum mechanics, it is typically expressed in terms of eigenvalues and eigenvectors of matrices, which you can learn about in a course on [linear algebra](https://www.wolfram.com/wolfram-u/courses/mathematics/introduction-to-linear-algebra/).

## More Operations on Qubits

You have seen the effects of the Hadamard gate. What about the `NOT` operation? Unsurprisingly, applying `NOT` to the register state changes $0$ to $1$ with $100\%$ probability:

```wl
With[{circuit = QuantumCircuitOperator[{"NOT" -> 1, "M" -> 1}], size = 200},
    Row[{
        circuit["Diagram", ImageSize -> {size, Automatic}],
        circuit[]["ProbabilitiesPlot", ImageSize -> size]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

Many important operations involve more than one qubit. One of the simplest is the `SWAP` operation, which just re-labels two qubits by swapping them:

```wl
With[{circuit = QuantumCircuitOperator[{"NOT" -> 2, "SWAP" -> {1, 2}, "M" -> {1, 2}}]},
    Row[{
        circuit["Diagram", ImageSize -> {200, Automatic}],
        circuit[]["ProbabilitiesPlot", ImageSize -> 200]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

Notice that the result is always the bit sequence `"10"`, even though `NOT` was applied to the second qubit — because a `SWAP` follows the `NOT`. Compare with the unswapped case:

```wl
With[{circuit = QuantumCircuitOperator[{"NOT" -> 2, "M" -> {1, 2}}]},
    Row[{
        circuit["Diagram", ImageSize -> {200, Automatic}],
        circuit[]["ProbabilitiesPlot", ImageSize -> 200]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

**Controlled operations** are another important category. One of the most common examples is the *controlled-NOT* gate, or `CNOT`:

```wl
With[{circuit = QuantumCircuitOperator[{"CNOT" -> {1, 2}, "M" -> {1, 2}}]},
    Row[{
        circuit["Diagram", ImageSize -> {200, Automatic}],
        circuit[]["ProbabilitiesPlot", ImageSize -> 200]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

On this particular input, `CNOT` does not appear to do anything. That's because a controlled gate is conceptually an `if` statement. If the control qubit is `1`, perform the operation on the target qubit; if the control is `0`, do nothing.

```wl
With[{circuit = QuantumCircuitOperator[{"NOT", "CNOT" -> {1, 2}, "M" -> {1, 2}}]},
    Row[{
        circuit["Diagram", ImageSize -> {200, Automatic}],
        circuit[]["ProbabilitiesPlot", ImageSize -> 200]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

Changing the control qubit to a `1` results in the `NOT` operation being applied to the target qubit. In the context of qubits, the `CNOT` gate can be used to generate quantum states with very unique properties if the control qubit is in neither the `0` nor the `1` state:

```wl
With[{circuit = QuantumCircuitOperator[{"Bell", "M" -> {1, 2}}]},
    Row[{
        circuit["Diagram", ImageSize -> {200, Automatic}],
        circuit[]["ProbabilitiesPlot", ImageSize -> 200]
    }, Style[" \[DoubleRightArrow] ", Bold, 20]]
]
```

This circuit no longer produces the same measurement outcome every time. Applying a Hadamard to the first qubit and then a `CNOT` (control on qubit 1, target on qubit 2) creates the **Bell state** $\tfrac{1}{\sqrt 2}(\lvert 00 \rangle + \lvert 11 \rangle)$. The outcomes are `"00"` with probability $1/2$ and `"11"` with probability $1/2$ — and notably, if you obtain $0$ on qubit 1, qubit 2 is certainly $0$, and similarly if qubit 1 is $1$, qubit 2 is certainly $1$. This perfect correlation is a consequence of *entanglement*, a topic we return to in later chapters.

::: theorem
**Bell state.** The two-qubit state $\lvert \Phi^+ \rangle = \tfrac{1}{\sqrt 2}(\lvert 00 \rangle + \lvert 11 \rangle)$ is maximally entangled: every product-state decomposition $\lvert \Phi^+ \rangle = \lvert \psi_1 \rangle \otimes \lvert \psi_2 \rangle$ fails.

::: proof
Suppose $\lvert \Phi^+ \rangle = (a \lvert 0\rangle + b \lvert 1\rangle) \otimes (c \lvert 0 \rangle + d \lvert 1 \rangle) = ac \lvert 00\rangle + ad \lvert 01 \rangle + bc \lvert 10 \rangle + bd \lvert 11 \rangle$. Matching coefficients with $\tfrac{1}{\sqrt 2}(\lvert 00 \rangle + \lvert 11 \rangle)$ requires $ad = 0$ and $bc = 0$, but also $ac \neq 0$ and $bd \neq 0$, which is a contradiction. Hence no product decomposition exists. $\square$
:::
:::

## Vocabulary

| Term | Definition |
|------|------------|
| Register state | The all-zero computational basis state, written `Ket[{0...0}]` or `QuantumState["Register"[n]]`. The conventional starting point of a quantum circuit. |
| Hadamard gate | The one-qubit unitary $H = \tfrac{1}{\sqrt 2}\begin{pmatrix} 1 & 1 \\ 1 & -1 \end{pmatrix}$. It maps `Ket[{0}]` to $\tfrac{1}{\sqrt 2}(\lvert 0\rangle + \lvert 1\rangle)$ and so creates an equal-amplitude superposition. |
| Bloch sphere | A 3D geometric representation of a one-qubit state as a point in (or on) the unit sphere. Pure states lie on the surface; mixed states inside. |
| SWAP gate | A two-qubit unitary that interchanges the states of two qubits. |
| CNOT gate | The two-qubit "controlled-NOT" gate; flips the target qubit iff the control qubit is `1`. |
| Bell state | One of four maximally-entangled two-qubit states; the canonical example is $\lvert \Phi^+ \rangle = \tfrac{1}{\sqrt 2}(\lvert 00 \rangle + \lvert 11 \rangle)$. |
| Entanglement | A property of multi-qubit states that cannot be expressed as a tensor product of single-qubit states; measurements on entangled qubits show correlations classical states cannot reproduce. |

## Exercises

::: exercise
**Hadamard twice.** Compute $H \cdot H \lvert 0 \rangle$ analytically — what state do you get? Confirm with a circuit.

::: solution
$H$ is its own inverse, so $H \cdot H = I$ and $H \cdot H \lvert 0 \rangle = \lvert 0 \rangle$.

```wl
QuantumCircuitOperator[{"H", "H"}][QuantumState["0"]] // TraditionalForm
```
:::
:::

::: exercise
**Inverting CNOT.** What is the effect of applying `CNOT` twice on any two-qubit state? Demonstrate it on the input `Ket[{11}]`.

::: solution
`CNOT` is its own inverse — applying it twice is the identity on every state.

```wl
QuantumCircuitOperator[{"CNOT" -> {1, 2}, "CNOT" -> {1, 2}}][QuantumState["11"]]
```
:::
:::

::: exercise
**Bell-state correlations.** Run the Bell-state circuit with 200 shots and tally the bitstring outcomes. What proportion of shots show qubit 1 and qubit 2 with the same value?

::: solution
The Bell state always produces `"00"` or `"11"`, never `"01"` or `"10"`. The two outcomes occur with equal probability, so the correlation is perfect.

```wl
Module[{circuit = QuantumCircuitOperator[{"Bell", "M" -> {1, 2}}], probs},
    probs = circuit[]["Probabilities"];
    Counts @ RandomChoice[Values[probs] -> Keys[probs], 200]
]
```
:::
:::

## Q&A

Q. *Why does the Hadamard gate not introduce randomness on its own?*

A. The Hadamard gate is a unitary operation — it deterministically transforms a definite quantum state into another definite quantum state. The randomness only appears when you *measure*; the measurement basis decides whether the resulting state lies along a definite axis (deterministic outcome) or sits at some angle to it (probabilistic outcome).

Q. *What's the difference between the `"M"` gate and `"M"["X"]`?*

A. `"M"` measures the qubit in the default computational ($Z$) basis. `"M"["X"]` (or `"M"["Y"]`, etc.) measures in a different Pauli basis — equivalently, you can rotate the state into the $Z$-basis with the appropriate gate (`H` for $X$-basis) before a standard measurement.

Q. *Why is `SWAP` so important if it just renames the qubits?*

A. Physically, quantum hardware often has connectivity constraints — only certain pairs of qubits can interact directly. `SWAP` lets you route a logical qubit to a neighbouring physical location so a two-qubit gate becomes possible. It's also useful for matching the qubit ordering between subroutines.

## Tech Notes

A controlled gate `"C"[op]` takes a *gate symbol* as its argument. To apply a controlled rotation, wrap the rotation gate: `"C"["RY"[Pi/3]] -> {ctrl, target}`.

```wl
QuantumOperator["C"["RY"[Pi/3]] -> {1, 2}]["Diagram"]
```

You can flip the control polarity (fire on `0` instead of `1`) by giving the third argument of `"C"` as the list of "open" controls:

```wl
QuantumCircuitOperator[{"C"["NOT" -> 2, {}, {1}]}]["Diagram"]
```

The Wolfram framework provides shortcut names for common composite circuits — `"Bell"` is one of them. You can recover the shorthand form of any circuit with `QuantumShortcut`:

```wl
QuantumShortcut @ QuantumCircuitOperator["Bell"]
```

## More to Explore

- [QuantumCircuitOperator reference](https://reference.wolfram.com/language/QuantumFramework/ref/QuantumCircuitOperator.html)
- [Bloch sphere on Wolfram MathWorld](https://mathworld.wolfram.com/BlochSphere.html)
- [Wolfram U: Introduction to Quantum Computing](https://www.wolfram.com/wolfram-u/courses/computer-science/introduction-to-quantum-computing/)

## Summary

This chapter introduced the basic building blocks of quantum circuits and the surrounding language:

- A quantum circuit alternates state preparation, unitary gates, and measurements. The register state `Ket[{0...0}]` is the standard starting point.
- The Bloch sphere is a 3D geometric representation of a single qubit's state: pure states lie on the surface, mixed states inside.
- Bra-ket notation is a compact way to write quantum states (kets) and their conjugates (bras); composite states are tensor products of single-qubit kets.
- Common gates (`H`, `NOT`, `SWAP`, `CNOT`) have specific effects on the computational basis; the Hadamard creates a superposition, and the `CNOT` plus a Hadamard creates a Bell state.
- Measurement outcomes are probabilistic in general, but a state that aligns with the measurement basis yields a deterministic outcome.

## References

- M. A. Nielsen and I. L. Chuang, *Quantum Computation and Quantum Information*, 10th Anniversary Edition, Cambridge University Press, 2010, Chapters 1–2.
- J. Preskill, *Lecture Notes on Quantum Computation*, Caltech, accessed 2026. <http://theory.caltech.edu/~preskill/ph229/>
- F. Bloch, "Nuclear Induction", *Physical Review* 70, 460 (1946).

## Initialization

```wl
Needs["Wolfram`QuantumFramework`"]
```
