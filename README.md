# Entanglement detection experiments

This repository contains all benchmarks and scripts necessary to reproduce
our entanglement detection experiments. The artifact can either be run locally
or through Docker. We recommend using the Docker image if possible, to avoid
any issues with missing dependencies or different software versions.

## Docker instructions

To run the artifact, you first need to either build or acquire the Docker
image. Here are a few options:
  1. You can build the image locally using the provided `Dockerfile` by
  running the command `docker build .`
  2. Alternatively, you can download the image from Dockerhub by running the
  command `docker pull shwestrick/icfp22-artifact`
  3. Another option is to download the image from
  [Zenodo](https://zenodo.org/record/6603649).

Instructions for running the artifact in the container are in
`README-artifact.txt`. To get good performance, the Docker container should
be run on an x86_64 multicore machine.

## Local instructions

To run the artifact locally, you need a multicore x86_64 machine with Linux
with the following installed:

  1. Python 2.7 with `numpy` and `matplotlib` packages
  2. GCC version 9 (or later)
  3. MLton, version [`20210117`](https://github.com/MLton/mlton/releases/tag/on-20210117-release)
  4. [mpl-switch](https://github.com/MPLLang/mpl-switch). (Make sure to
  run `mpl-switch init` once after installing.)

After these have been installed, run the following to initialize this repository
and install the necessary versions of [MPL](https://github.com/MPLLang/mpl).
(The command `./init` may take a long time to run.)

```
$ git clone -b icfp22-artifact https://github.com/MPLLang/entanglement-detect
$ cd entanglement-detect
$ ./init
```

Everything should now be ready. Run the following to double check that
everything is working. The first `bin/...` command runs a nearest-neighbors
benchmark on 1 processor, and the second runs it on 8 processors.
For the first command, you should see approximately 2 seconds of warmup
followed by 5 repetitions of the benchmark, and finally a summary of some
measurements. For the second command, the output should be similar, except
faster, because it uses 8 processors instead of 1. (If your machine does not
have 8 processors, then use fewer.)

```
$ cd mpl
$ make nn.mpl-detect.bin
$ bin/nn.mpl-detect.bin @mpl procs 1 -- -N 1000000 -repeat 5 -warmup 2
$ bin/nn.mpl-detect.bin @mpl procs 8 -- -N 1000000 -repeat 5 -warmup 2
```

At this point, you can follow the instructions inside `README-artifact.txt`
to run experiments. There is one difference however: you should omit running
commands that copy results into `/ARTIFACT-RESULTS`
(this is specific to the Docker container and is not needed when running locally).

For example, you can run the full evaluation locally as follows. Instructions
for `<PROCLIST>` are in the "Full Evaluation" section of `README-artifact.txt`.

```
$ ./generate-inputs
$ ./run --procs <PROCLIST>
$ ./report
```

**Note**: these commands take a long time to run and require a large
amount of free memory and disk space. See `README-artifact.txt` for more
details.
