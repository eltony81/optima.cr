# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Optima.cr is a Crystal algebraic modeling library for Linear Programming (LP) and
Mixed-Integer Linear Programming (MILP), inspired by Python's PuLP. It provides a fluent,
operator-overloaded DSL for building models and binds natively (via FFI) to the **HiGHS**
C++ solver, with CLI-subprocess-based solvers for CBC and GLPK as alternates.

## Commands

```bash
shards install                                # install dependencies (also runs ext/compile_check.sh)
crystal tool format --check                   # CI format check; use `crystal tool format` (no --check) to fix
crystal build --no-codegen spec/optima_spec.cr   # what CI runs to verify compilation (no HiGHS lib needed on CI)
crystal spec                                  # run the full spec suite (requires libhighs installed locally)
crystal spec spec/optima_spec.cr -e "some example description"  # run a single spec by name
crystal run examples/basic_milp.cr            # run an example program
```

The HiGHS C library must be installed locally to actually solve models (`sudo pacman -S highs` /
`brew install highs` / `sudo apt-get install libhighs-dev`) — see README.md for details. CI only
does a format check and a `--no-codegen` compile check, so it does not need HiGHS installed.
The CBC/GLPK solvers additionally require the `cbc` / `glpsol` binaries to be on `PATH` at runtime.

## Architecture

### Modeling layer (backend-agnostic)

- `Variable`, `Expression`, `QuadraticExpression`, `Constraint` form the DSL. Operators
  (`+`, `-`, `*`, `<=`, `>=`, `==`) are overloaded across these types (and `struct Number` is
  reopened in `variable.cr` to support `5 + x`, `2 * x`, etc. on the left-hand side) so that
  arithmetic on variables builds up `Expression`/`QuadraticExpression` objects, and comparisons
  build `Constraint` objects, rather than evaluating anything.
  - `Variable * Variable` / `Variable * Expression` produce a `QuadraticExpression` — this is
    how quadratic objectives get built for QP problems (fed to HiGHS as a Hessian).
  - Range constraints (`(lo <= expr) <= hi`) work by chaining: `expr >= lo` returns a
    `GreaterThanOrEqual` `Constraint`, and `Constraint#<=` on that sets `range_upper`. The
    first comparison **must** be parenthesized — Crystal desugars a bare `a <= b <= c` into
    `(a <= b) && (b <= c)`, and since `<=` returns a `Constraint` (always truthy) rather than
    a `Bool`, that silently discards the lower bound instead of raising or misbehaving loudly.
  - `Variable`/`Expression`/`QuadraticExpression`'s `Hash` keys (`terms`, `quad_terms`,
    `Model#hessian`) must use `Hash#compare_by_identity` (or, for `Tuple(Variable, Variable)`
    keys, the `Tuple#==` override in `quadratic_expression.cr`) instead of the default `==`.
    `Variable#==`/`Expression#==` are overloaded to build DSL `Constraint`s, not booleans, so
    `Hash`'s own key-collision checks would otherwise recurse back into them indefinitely.
- `Model` owns the lists of `variables`/`constraints`, the `objective` (or multi-objective via
  `add_objective` with weights), and an optional `hessian` (`Hash(Tuple(Variable, Variable), Float64)`)
  for QP. Variable IDs are assigned sequentially at creation time (`@variable_counter`) and are
  what solvers use as column indices — do not reorder `model.variables` after solving.
  - `Model#to_lp` / `Model.from_lp` implement a self-contained CPLEX-LP-format reader/writer used
    by the CLI solvers (CBC/GLPK) to hand off problems and by `read_model`/`write_model` on HiGHS.
  - `Model#compute_iis` and `Model#sensitivity_analysis` are solved-model diagnostics implemented
    by repeatedly mutating and re-solving the model with a given `Solver` (deletion filter for IIS,
    finite-difference perturbation for ranging) — they are solver-agnostic, working purely through
    the `Solver` interface. `HighsSolver#sensitivity_analysis` is a separate, solver-specific
    override that calls HiGHS's native `Highs_getRanging` once instead — exact and much faster, but
    reports the actual coefficient/RHS range rather than `Model#sensitivity_analysis`'s
    delta-perturbed objective value; see the doc comment on each before assuming they match.
  - `Model#remove_constraint`/`#remove_variable` renumber the remaining `.id`s to keep matching
    their array position — the same invariant `compute_iis` relies on (see below) — and
    `#remove_variable` raises if the variable is still referenced by the objective, a constraint,
    or the Hessian, since nothing here can guess how to patch up a dangling reference.
  - `Model#dup` deep-clones variables/objective/constraints/hessian with entirely fresh `Variable`
    instances (not `Reference#dup`'s shallow copy) so the clone and original can't cross-talk.
- `vectorized.cr` layers `num.cr` (`Tensor`) support on top of the DSL: it reopens `Tensor(T, S)`
  to add matrix/vector multiplication (`Float64 Tensor * Variable/Expression Tensor` → element-wise
  dot-product `Expression`s) and element-wise `<=`/`>=`/`==` producing `Constraint` tensors. This is
  what `Model#variable_vector` and the `examples/vectorized_*.cr` files build on.

### Solver layer

- `Solver` (`solver.cr`) is the abstract interface every backend implements: `solve(model)`,
  `value(variable)`, `objective_value`. Concrete solvers add extras like `reduced_cost`,
  `shadow_price`, `active_variables`.
- `HighsSolver` (`native/highs_solver.cr` + `native/highs.cr`) is the primary backend: it FFI-binds
  directly to `libhighs` (`@[Link("highs")]` lib binding), building the problem via
  `Highs_addCol`/`Highs_addRow` column-by-column/row-by-row using `Variable#id` as the column index.
  It destroys and recreates the underlying `Highs_create` handle on every `solve` call to avoid
  state leaking between solves, and uses `Box(HighsSolver)` to pass `self` through the C callback
  (`on_message`) for streaming solver log lines. Only ~25 of HiGHS's ~176 exported `Highs_*`
  functions are bound (`native/highs.cr`) — when adding more, get the exact signature from
  `/usr/include/highs/interfaces/highs_c_api.h` (installed alongside `libhighs` on Arch) rather
  than guessing; an FFI signature mismatch is a memory-safety bug, not just a wrong answer.
  `threads=`/`presolve=` are applied fresh in `#solve` (`Highs_setIntOptionValue`/
  `Highs_setStringOptionValue`) since the handle itself is recreated every call;
  `warm_start_basis=`/`#get_basis` wrap `Highs_setBasis`/`Highs_getBasis`.
- `CbcCliSolver` / `GlpkCliSolver` (`cbc_cli_solver.cr`, `glpk_cli_solver.cr`) instead shell out to
  the `cbc`/`glpsol` binaries: they write `model.to_lp` to a temp `.optima_tmp/` file, run the
  process, and parse the resulting solution file. These key solutions by variable *name* rather
  than ID (unlike HighsSolver, which keys by integer ID). Both also parse the dual-value column
  their solution file formats already include (CBC's "dj" 4th column → `reduced_cost` only, no
  row duals in that file format at all; GLPK's plain-format 3rd column on both row and column
  lines → `reduced_cost` and `shadow_price`, `0.0` for MIP solutions which have no dual values).
- `SolverPool` is a thread-safe `Deque(HighsSolver)` pool (checkout/checkin, or `use(&block)`) for
  reusing solver instances/handles across concurrent solves.

### Everything is JSON-serializable

`Model`, `Variable`, `Expression`, `Constraint` all `include JSON::Serializable` (and
`QuadraticExpression` implements custom `to_json`/`from_json` by hand) so models can be persisted
or transmitted as JSON, independent of the `.lp`/`.mps` file I/O paths used by the solvers.

## Style notes

- No trailing README/CHANGELOG-style comment blocks — keep doc comments on public methods short
  (see existing `///`-less single-line comments in `model.cr` on methods like `compute_iis`).
- Match the existing `.editorconfig`-free formatting convention: run `crystal tool format` before
  committing: CI enforces it exactly (`crystal tool format --check`).
