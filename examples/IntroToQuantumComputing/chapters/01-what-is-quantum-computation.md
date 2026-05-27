---
Template: Chapter
Name: What Is Quantum Computation?
ChapterNumber: 1
ShowPageBreaks: true
Context: Wolfram`QuantumFramework`
---

# What Is Quantum Computation?

Welcome to the first lesson of this course. We start by briefly revisiting classical computation through clear, hands-on examples, then shift to the quantum realm where you will explore a few foundational quantum circuits. Each example comes with accompanying code; if it does not all make sense right away, that's expected — as we progress, you will gradually build both your understanding of quantum concepts and your coding skills.

## Key Concepts

- Quantum circuit
- Qubit
- Measurement
- Superposition
- Computational basis

## Classical Computation

In order to understand quantum computation, it helps to compare it to classical computation. To compute something, you have to be able to use rules to determine the output from a list of inputs. You can think of computing as starting with the inputs and following the rules to reach an output.

Consider two binary numbers `"01"` and `"10"`, and let's see how we can add them. First, each bit-string is interpreted as a base-2 number rather than ordinary decimal, so `"01"` becomes one and `"10"` becomes two.

Define the binary strings:

```wl
a = "01"; b = "10";
```

Construct the number from the base-2 digits of `a`:

```wl
FromDigits[a, 2]
```

Construct the number from the base-2 digits of `b`:

```wl
FromDigits[b, 2]
```

Add the numbers with ordinary addition:

```wl
FromDigits[a, 2] + FromDigits[b, 2]
```

Convert the total back into a bit-string:

```wl
IntegerString[FromDigits[a, 2] + FromDigits[b, 2], 2]
```

Now let's add two binary strings `"101"` and `"011"`:

```wl
a = "101"; b = "011";
IntegerString[FromDigits[a, 2] + FromDigits[b, 2], 2]
```

Pay attention to the string length of the initial numbers and the final total. The original bit-strings have length 3, but the answer is a four-bit string. Let's dive in a bit more.

What are all the states of a sequence of three classical bits?

```wl
threeBits = Tuples[{0, 1}, 3]
```

What are the corresponding numbers from those base-2 digits?

```wl
FromDigits[#, 2] & /@ threeBits
```

With a 3-bit string you can represent $0$–$7$; in general, $n$ bits represent $0$ to $2^n - 1$. Adding `101` and `011` gives 8, which exceeds the 3-bit range. This means *in-place* addition is modulo $2^n$, so the sum wraps to `000` unless you provide an extra bit to capture the carry.

If you stay within 3 bits, perform all operations modulo 8 (wrap-around arithmetic):

```wl
Mod[FromDigits[a, 2] + FromDigits[b, 2], 2^3]
```

Then the 3-bit string of that result is:

```wl
IntegerString[0, 2, 3]
```

It is also possible to encode information in such sequences of classical bits to represent problems of interest. For example, each of those bit sequences could also encode a letter character:

```wl
FromLetterNumber[FromDigits[#, 2]] & /@ threeBits
```

With yet another encoding scheme, those same bit sequences could represent colors with opacity:

```wl
Apply[RGBColor, #] & /@ threeBits
```

Having seen how a 3-bit register cleanly enumerates eight distinct states and how different encodings map those states to numbers, letters, or colors, we now move to the quantum setting. There the same eight basis strings exist, but a 3-qubit register can also occupy complex *superpositions* of them, and even *entangled* combinations that have no classical analogue. The rules for storing and extracting information therefore change: measurement reveals a single basis outcome, while computation exploits interference among amplitudes.

## Quantum Circuits and Qubits

Now we dive directly into quantum computation. We introduce common terms and concepts widely used in quantum information. Some details are only briefly mentioned; for each topic we highlight what to focus on for a first exposure, and later we return to expand on each concept in more depth.

The diagram below represents an example of a **quantum circuit**:

```wl
qc = QuantumCircuitOperator[{
    "H", "Z" -> 2, "Y" -> 3, "P"[Pi/4],
    "CNOT" -> {1, 3}, "RY"[Pi/3] -> 2, "CH" -> {2, 3}, Range[3]
}];
qc["Diagram"]
```

Notice how the circuit diagram has several wires, labeled `c`, `1`, `2` and `3`. Wires `1`, `2` and `3` represent **qubits** (quantum bits) instead of classical bits. This is a 3-qubit system, meaning that the state can be described in the complex vector space $\mathbb{C}^8$. The previous eight classical bits can form a convenient basis (usually called the *computational basis*). Those 3-bits in quantum are represented by wrapping them around a notation `Ket[{…}]` which is called a **ket**. In general, a ket is a shorthand representation of a complex-valued vector. A general 3-qubit state is a complex linear combination of those eight basis states.

A quantum circuit is read from left to right. The first operation — represented by the blue box labeled **H** — acts only on the first wire, while some operations act on more than one wire; they are multi-qubit gates. The boxes that look like gauges on the right represent **measurement** and point to the wire labeled `c`. The wire labeled `c` represents a classical system (such as part of a regular computer) where the results of the measurements on qubits are stored. All operations shown except measurements are **unitary and reversible**, a key feature we explore in more detail later. You can think of each box as performing a transformation on the quantum state of one or more wires. These transformations must obey fundamental principles dictated by quantum theory.

What are the results of running this circuit? Since measurements are included at the end, executing the circuit returns a quantum measurement object in the Wolfram Quantum Framework. This object contains the probability distribution over possible bitstrings and can be sampled to generate measurement outcomes:

```wl
measurements = qc[]
```

Note that by executing the code above we performed a quantum computation — but it was carried out on a classical computer (your PC). This is exactly what a quantum simulator does: it mimics quantum behavior and performs computations using the rules of quantum mechanics, all within classical hardware.

What are the results of the measurement in this circuit?

```wl
measurements["ProbabilitiesPlot"]
```

Notice that the possible outcomes of a quantum measurement are simply classical bit sequences. In the earlier classical computation examples, the rules were deterministic: each input led to a definite output. In contrast, quantum computation typically yields a *range* of possible outcomes, each with a certain probability. This is because quantum theory provides a probabilistic description of measurement results, with the distribution determined by the state just before measurement (and the chosen measurement basis).

For a quantum program to be useful, you arrange things so that the probability of measuring a result that encodes a desired solution to your problem is high.

Additionally, you can track how the quantum state evolves as gates are applied. Although we have not yet discussed the state in full detail, for now focus on the linear combination of computational-basis bitstrings and examine the *amplitude* of each term. These amplitudes update linearly under gates, and their squared magnitudes determine the probabilities of the corresponding bitstrings upon measurement.

```wl
Grid[
    Prepend[
        Transpose[{
            {"Initial", "H", "Z", "Y", "P[\[Pi]/4]", "CNOT", "RY[\[Pi]/3]", "CH", "Measurements"},
            TraditionalForm /@ FoldList[#2[#1] &, QuantumState["000"], qc["Operators"]]
        }],
        Style[#, Bold] & /@ {"Step", "State"}
    ],
    Frame -> All, Alignment -> Left
]
```

Keep in mind that, in the end, the most important information we extract from a quantum system is its measurement results (and their statistics). We will discuss this in more detail in future chapters.

::: solved-example
**Counting outcomes in a small circuit.** Apply a Hadamard to a single qubit in the register state, then measure in the computational basis. What is the probability of each outcome?

```wl
With[{c = QuantumCircuitOperator[{"H", "M" -> 1}]},
    c[]["Probabilities"]
]
```

After the Hadamard, the qubit is in the equal-amplitude superposition $\tfrac{1}{\sqrt{2}}(\lvert 0\rangle + \lvert 1\rangle)$, so measuring in the computational basis gives `"0"` or `"1"` each with probability $1/2$.
:::

## Vocabulary

| Term | Definition |
|------|------------|
| Quantum circuit | A diagrammatic representation of a quantum algorithm; a sequence of unitary gates (and optional measurements) applied to one or more qubit wires, read left-to-right. |
| Qubit | A two-level quantum system, the quantum analogue of a classical bit; its state lives in $\mathbb{C}^2$ and can be a superposition of the two computational-basis states `Ket[{0}]` and `Ket[{1}]`. |
| Ket | The notation `Ket[{…}]` for a quantum state; shorthand for a complex column vector. A multi-qubit ket `Ket[{01}]` is the tensor product `Ket[{0}] ⊗ Ket[{1}]`. |
| Computational basis | The set of basis states `{Ket[{0}], Ket[{1}]}` (single qubit) or `{Ket[{0...0}], …, Ket[{1...1}]}` (multi-qubit) used for read-out. Measurement in this basis returns a classical bitstring. |
| Measurement | The act of reading a qubit, which collapses its state to a basis state and returns a classical bit; outcomes are probabilistic in general. |
| Amplitude | The complex coefficient of a basis ket in a superposition; its squared magnitude is the probability of obtaining that basis outcome on measurement. |
| Unitary | A linear, reversible operator whose inverse is its conjugate transpose; all isolated gate operations in a quantum circuit are unitary. |

## Exercises

::: exercise
**Bitstring range.** Without running any code, what is the largest non-negative integer representable by a 5-bit string? Verify your answer with `FromDigits`.

::: solution
A 5-bit string represents $0$ to $2^5 - 1 = 31$.

```wl
FromDigits[ConstantArray[1, 5], 2]
```
:::
:::

::: exercise
**Three-bit wrap.** Compute `"110" + "011"` modulo $2^3$ and convert the result back to a 3-bit string.

::: solution
The sum of $6$ and $3$ is $9$, and $9 \bmod 8 = 1$, so the wrapped 3-bit string is `"001"`.

```wl
IntegerString[Mod[FromDigits["110", 2] + FromDigits["011", 2], 2^3], 2, 3]
```
:::
:::

::: exercise
**One Hadamard, one outcome.** Build the one-qubit circuit `{"H", "M" -> 1}`, run it, and confirm that the measurement returns `"0"` or `"1"` with roughly equal frequency over 100 shots.

::: solution
The circuit produces an equal superposition and then measures, so the outcomes should be roughly 50/50.

```wl
Module[{c = QuantumCircuitOperator[{"H", "M" -> 1}], probs},
    probs = c[]["Probabilities"];
    Counts @ RandomChoice[Values[probs] -> Keys[probs], 100]
]
```
:::
:::

## Q&A

Q. *Why does the same quantum circuit not always return the same answer?*

A. Quantum measurement is intrinsically probabilistic. Unless the pre-measurement state happens to coincide with one of the measurement basis states, the outcome is drawn from a distribution determined by the state's amplitudes. Repeating the circuit (often called *shots*) lets you estimate that distribution.

Q. *Is the simulator doing real quantum mechanics or just bookkeeping?*

A. Bookkeeping — but the bookkeeping follows the exact rules of quantum theory. The simulator carries the full state vector (or density matrix) and applies the gates as linear operators on a classical computer. A real quantum processor produces the same probability distribution physically; the simulator computes that distribution numerically.

Q. *Why use `Ket[{0}]` instead of just `{1, 0}`?*

A. The ket notation makes the *label* of the basis state explicit and composes cleanly under tensor products (`Ket[{01}]` for two qubits, `Ket[{010}]` for three, …). The underlying object is still a complex vector, and the framework lets you switch to `state["StateVector"]` whenever you want the raw amplitudes.

## Tech Notes

The Wolfram Quantum Framework prints quantum objects as summary boxes by default. To see the full Dirac expression, wrap the object in `TraditionalForm`:

```wl
QuantumState["+"] // TraditionalForm
```

To get the raw amplitudes as a flat list rather than a `SparseArray`, use the `"AmplitudesList"` property:

```wl
QuantumState["+"]["AmplitudesList"]
```

You can sample bitstring outcomes from a circuit by combining its `"Probabilities"` distribution with `RandomChoice`:

```wl
With[{probs = qc[]["Probabilities"]},
    RandomChoice[Values[probs] -> Keys[probs], 10]
]
```

## More to Explore

- [Wolfram Quantum Framework documentation](https://reference.wolfram.com/language/QuantumFramework/guide/QuantumFrameworkGuide.html)
- [Wolfram U: Introduction to Linear Algebra](https://www.wolfram.com/wolfram-u/courses/mathematics/introduction-to-linear-algebra/)
- [Quantum Computation Framework GitHub](https://github.com/WolframResearch/QuantumFramework)

## Summary

In this chapter you saw how classical bits are interpreted as base-2 digits, encoded as numbers, letters, or colors, and saw the bit-width constraint that forces in-place addition to be modular. We then introduced the quantum analogue:

- A quantum circuit is a sequence of unitary operations and (optionally) measurements applied to one or more qubits.
- A qubit's state is a complex linear combination of the computational basis states, and the squared amplitude of each basis term is the probability of obtaining that bitstring on measurement.
- Measurement in the computational basis returns a classical bitstring; the *distribution* of outcomes is what carries the result of a quantum computation.
- A quantum simulator computes the rules of quantum theory on classical hardware, so the output bitstrings have the same statistics as a real quantum processor would produce.

## References

- M. A. Nielsen and I. L. Chuang, *Quantum Computation and Quantum Information*, 10th Anniversary Edition, Cambridge University Press, 2010.
- S. Aaronson, *Quantum Computing Since Democritus*, Cambridge University Press, 2013.
- Wolfram Research, *Wolfram Quantum Framework*, paclet documentation, accessed 2026. <https://www.wolfr.am/DevWQCF>

## Initialization

Install the Wolfram Quantum Framework:

```wl
PacletInstall["Wolfram/QuantumFramework"]
Needs["Wolfram`QuantumFramework`"]
```
