------------------------------------------------------------------------------
-------------------------------- INTRODUCTION --------------------------------
------------------------------------------------------------------------------

Recent research on parallel functional programming has culminated in a provably
efficient memory manager which has been implemented in the MPL compiler for
Parallel ML and shown to deliver practical efficiency and scalability. The
memory manager relies on a property called **disentanglement** which is closely
related to race-freedom but differs subtly from it. Unlike race-freedom,
however, no techniques are known to check for disentanglement, leaving the task
entirely to the programmer.

In the paper "Entanglement Detection With Near-Zero Cost", we present
techniques for automatically detecting *entanglement* (i.e., violations of
disentanglement) dynamically, while the program is running. Our detection
algorithm is sound, complete, provably efficient, and practical: we implement
our techniques in the MPL compiler and measure overheads of less than 5% on
average on up to 72 processors. These results show that entanglement detection
has negligible cost and can therefore remain deployed with little or no impact
on efficiency, scalability, and space.

------------------------------------------------------------------------------
----------------------------------- CLAIMS -----------------------------------
------------------------------------------------------------------------------

The claims in the paper supported by this artifact include:
  1. The overhead (in terms of both time and space) of entanglement detection
  is close to zero. For time specifically, the overhead is approximately 1%
  on average across the benchmarks, with a max of approximately 7%.
  A majority of benchmarks have less than 2% time overhead.
  2. Entanglement detection is highly scalable: in a comparison with a
  sequential baseline, speedups scale well as the number of processors
  increases.
  3. The performance improvement due to the "entanglement candidates" algorithm
  is significant, due to a large number of unnecessary entanglement checks that
  are eliminated.

------------------------------------------------------------------------------
---------------------------------- OVERVIEW ----------------------------------
------------------------------------------------------------------------------

The artifact is a self-contained Docker (www.docker.com) image containing all
code and scripts necessary for reproducing our results. In particular, this
includes source code for the benchmarks, and experiment scripts. These are
described in detail in the "Reuse and Repurposing" section, below.

For evaluating the artifact, we provide two sets of instructions, one for a
"small" evaluation, and the other for a "full" evaluation. The small evaluation
considers a subset of benchmarks with reduced problem sizes, and takes about
20-30 minutes to run. The full evaluation is intended for fully reproducing our
results in the paper, and takes between 5.5 and 10 hours to run (depending
on how much is reproduced).

Minimum hardware requirements:
- 6GB RAM, 8 cores for the SMALL evaluation.
- 100GB RAM, >=32 cores for the FULL evaluation.

------------------------------------------------------------------------------
------------------------------ GETTING STARTED -------------------------------
------------------------------------------------------------------------------

Step 1: Load docker image. The image is packaged as part of this artifact,
and can be loaded directly:

  $ sudo docker image load -i shwestrick-icfp22-artifact-image.tar.gz

If desired, the image is also available from Docker Hub:

  $ sudo docker pull shwestrick/icfp22-artifact

For the rest of the instructions, we assume the arifact is locally tagged
"shwestrick/icfp22-artifact". This should be the default behavior from
both of the above commands.


Step 2: Start the container. First, make a local directory 'ARTIFACT-RESULTS'
which will be mounted in the docker container (this lets us copy files out of
the container). Then start the container as shown below. This opens a bash
shell inside the container, which has the prompt '#'.

  $ mkdir ARTIFACT-RESULTS
  $ sudo docker run -v $(pwd -P)/ARTIFACT-RESULTS:/ARTIFACT-RESULTS --rm -it shwestrick/icfp22-artifact /bin/bash

------------------------------------------------------------------------------
-------------------------- STEP BY STEP EVAULATIONS --------------------------
------------------------------------------------------------------------------

SMALL EVALUATION (20-30 minutes)
--------------------------------

Requires at least 6GB RAM and 8 cores.

Step 1: Run benchmarks. Run the following commands inside the container
(the prompt inside the container is '#').

  # ./run-small
  # ./report-small | tee /ARTIFACT-RESULTS/small-output
  # cp -r small/figures /ARTIFACT-RESULTS/small-figures

Step 2: Check results. The output of step 1 consists of tables (printed to
stdout, and copied to ARTIFACT-RESULTS/small-output) and a speedup plot
(copied to ARTIFACT-RESULTS/small-figures).
  - The tables (ARTIFACT-RESULTS/small-output) are comparable to Figures 8,
  10, and 11 in the paper, except with a few important differences: the
  problem sizes are reduced, and only 8 cores are used (as opposed to 72 in
  the paper). Please see the captions in ARTIFACT-RESULTS/small-output for
  details on how to interpret these results.
  - The speedup plot (ARTIFACT-RESULTS/small-figures/mpl-detect-speedups.pdf)
  should show that the benchmarks achieve approximately linear speedup as
  the number of processors increases. This is similar to Figure 9 in the
  paper. The speedups will not be as high due to the reduced problem sizes
  and smaller number of cores used.


FULL EVALUATION (5.5-10 hours)
----------------------------------------

Requires at least 100GB RAM and a large number of cores.
(At least 32 cores is okay; 64 or more is preferable).

Step 1: Generate inputs (~2 minutes).

  # ./generate-inputs

Step 2: Full experiments. Run the following commands inside the container.

  # ./run --procs <PROCLIST>
  # ./report | tee /ARTIFACT-RESULTS/full-output
  # cp -r figures /ARTIFACT-RESULTS/full-figures

The `run` script takes an argument `--procs <PROCLIST>` which is a
comma-separated (no spaces) list of processor counts to consider. We recommend
choosing a maximum number of processors corresponding to physical cores, to
avoid complications with hyperthreading. We also recommend choosing a range
of intermediate processor counts, to see informative speedup curves.

For example, in the paper we used `--procs 1,10,20,30,40,50,60,72` on a
machine with 72 physical cores. With 32 cores, we would recommend
`--procs 1,10,20,32`. With 64 cores, we recommend `--procs 1,10,20,30,40,50,64`.

For reference, on our machine, the command `./run --procs 1,72` takes 5.5
hours. This is the minimum required for reproducing Figures 8, 10, and 11 in
the paper. Figure 9 requires longer (for more intermediate amounts of
processors).

Step 3: Check results. Similar to the small evaluation, the tables produced
(ARTIFACT-RESULTS/full-output) are comparable to Figures 8, 10 and 11, and the
speedup plot (ARTIFACT-RESULTS/full-figures/mpl-detect-speedups.pdf) is
comparable to Figure 9. If a large number of processors (e.g. >=64) were used,
these results should be similar to those reported in the paper, modulo
hardware differences and containerization overheads.

-----------------------------------------------------------------------------
--------------------------- REUSE AND REPURPOSING ---------------------------
-----------------------------------------------------------------------------

All code is additionally available on GitHub:
  * The MPL Compiler, including our updates for this paper, is available
  at https://github.com/MPLLang/mpl
  * The experiments for this paper are available at
  https://github.com/MPLLang/entanglement-detect

The source code (benchmarks and experiment scripts) used in the artifact can
easily be adapted for other uses, as described below.

The benchmarks are available in the `entanglement-detect` repository, in the
mpl/bench subdirectory. Each subfolder of mpl/bench defines one benchmark.

There are multiple compiler configurations used in this benchmark suite. Each
is defined by a file in mpl/config. The three main configurations are as
follows.
  * The `mpl-detect` configuration is our new version of the MPL compiler,
  developed for this project. This has entanglement detection enabled by
  default.
  * The `mpl` configuration uses the vanilla MPL compiler (no entanglement
  detection).
  * The `mlton` configuration compiles using the MLton compiler. This is
  used as the sequential baseline in our experiments.

The file mpl/Makefile has targets of the form `BENCHMARK.CONFIG.bin`, where
BENCHMARK is the name of a benchmark (i.e. a subfolder within mpl/bench) and
CONFIG is the name of a compiler configuration to use. When making a benchmark,
the resulting binary is placed in the mpl/bin subdirectory.

For example, within the `mpl` directory, the command
`make delaunay.mpl-detect.bin` creates an executable
`bin/delaunay.mpl-detect.bin`.

After building an executable, it can be run with the following syntax,
where <N> is the number of threads (processors) to use, <ARGS> are
benchmark-specific arguments, <R> is the number of repetitions, and <W> is
the length (in seconds) of the warmup period. Each benchmark program proceeds
first with a warmup period (performed by executing the benchmark back-to-back
until the period has expired), and then by running the benchmark back-to-back
for the number of repetitions specified.

  [entanglement-detect/mpl]$ bin/<BENCHMARK>.<CONFIG>.bin @mpl procs <N> -- <ARGS> -repeat <R> -warmup <W>

Many of the benchmarks take arguments of the form `-N <SIZE>` to define a
problem size. This makes it easy to test performance across a range of problem
sizes. For example, here are the commands for running the "nearest-neighbors"
benchmark (named `nn`), with entanglement detection enabled, on 16 processors,
across a range of sizes, with 10 repetitions and 3 seconds of warmup.

  $ cd mpl
  $ make nn.mpl-detect.bin
  $ bin/nn.mpl-detect.bin @mpl procs 16 -- -N 10000 -repeat 10 -warmup 3
  $ bin/nn.mpl-detect.bin @mpl procs 16 -- -N 100000 -repeat 10 -warmup 3
  $ bin/nn.mpl-detect.bin @mpl procs 16 -- -N 1000000 -repeat 10 -warmup 3

However, note that not all benchmarks take exactly the same arguments. In the
top-level folder, there is a JSON file, `exp.json`, which specifies
benchmark-specific arguments and parameters used in our experiments. In the
field "specs", there is an array of entries, one for each benchmark. Each of
these entries has a field "args" which shows an example of arguments that
can be passed for that benchmark.

The `exp.json` file also defines other parameters used in the experiments.
This file is passed to `scripts/gencmds` which produces "rows" of key-value
pairs, where each row describes one experiment. Examples of keys include
"config", "tag", etc. The config is the name of compiler configuration to
use, the tag is a unique name for each benchmark, etc.

The output of `scripts/gencmds` is then piped into `scripts/runcmds` to
produce results. See the `run` script for more detail.

Finally, the `report` script parses the results are produces tables and
figures.

