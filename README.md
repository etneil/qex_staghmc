# QEX: Quantum EXpressions lattice field theory framework

## Description of QEX fork:
Staggered hybrid Monte Carlo with Pauli-Villars bosons and nHYP smearing. Source code can be found [here](https://github.com/ctpeterson/qex/tree/devel/src/stagg_pv_hmc).

I have also added an XY model cluster code that can be found [here](https://github.com/ctpeterson/qex/tree/devel/src/xy_cluster_mc).

## Description of QEX:
QEX is a high-level framework for lattice field operations
written in the language [Nim](https://nim-lang.org).

It provides optimized lattice field operations, including SIMD support,
for CPU architectures (native GPU support is currently experimental).
Since Nim compiles to native C/C++, directly calling any C/C++ lattice
code or library from QEX is relatively easy to do.

Some simple code examples are here
 [ex0.nim](src/examples/ex0.nim)
 [ex1.nim](src/examples/ex1.nim).

It currently supports
- U(1), SU(2..4) gauge fields in any dimension
- SciDAC I/O
- Gauge fixing
- Staggered solver and forces (Asqtad, HISQ, nHYP)
- Wilson solver (no clover yet)
- Interface for Chroma, Grid, QUDA interoperability

Installation guide: [INSTALL.md](INSTALL.md)

Build guide: [BUILD.md](BUILD.md)

Further examples:
- [tests/examples](tests/examples)
