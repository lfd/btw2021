# Replication Package
This site provides the replication package for the BTW 2021
paper *Silentium! Run–Analyse–Eradicate the Noise out
of the DB/OS Stack*

*NOTE:* An archival version of the pre-built docker image, together
with a copy of the git repository and the measured data, are available at
the DOI [10.5281/zenodo.4602296](https://doi.org/10.5281/zenodo.4602296).

## Building the Docker image
- Clone the repository
> git clone https://github.com/lfd/btw2021.git
- Build the Docker image from scratch
> cd btw2021

> docker build -t btw2021 .
- Copy measurement package (for x86_64 Linux) to host (i.e., machine
used to build binaries)
> docker run --rm --entrypoint cat btw2021:latest  /home/build/measure.tar.bz2 > /path/to/measure.tar.bz2

## Performing measurements on Linux targets

- Copy `measure.tar.bz2` from host to target (i.e., machine used to
  perform measurements), and untar the content.

  The measurement tarball includes pre-generated TPC-H data files of a
  few 100KiB. However, realistic measurements are usually performed with
  GiB of data. This necessitates running the generator on the target
  system. Create sub-folders tpch_`size` (for instance, tpch_2.0 for
  2 GiB), copy `dbgen` and `dists.dss` from the `data/tpch` subfolder
  into the directory, and run `./dbgen -s 2.0` to create, for instance,
  a data set of 2.0 GiB.
- Additionally, two measurement modes are provided: Pre-calibrated 
  sampling that only records values that exceed an upper or 
  lower bound, or a complete measurement the records every latency
  value (default). Set `CALIBRATED` to 0 or 1 to perform a (non-)
  calibrated run.
- Adapt `doall.sh` (and probably also `dispatch.sh`) for the desired
  scenario. Variable `DATASET` can be set to either `tpch` or
  `finance`. `CALIB_T` specifies the time used for the calibration
  run (on data of size `CALIB_S`, whereas `RUN_T` and `RUN_S` specify
  runtime and data size for the measurement proper.
- Execute `caps.sh` to set capability `cap_ipc_lock` (which allows
  to mlock memory allocations without having to run with root
  privileges) for the measurement binaries.
- Run `doall.sh` (after performing any specific configuration settings
  on your system)
- Visualise using the scenario specific scripts in `plot/`

## Performing measurements on RTEMS on x86_64 targets
- Use the binaries provided in `/home/build/dbtoaster/rtems` in the
  Docker image. These are compiled for bare-metal x86_64, and can be
  booted using grub.

## Performing measurements on RTEMS on BeagleBone Black
- Binaries for the BeagleBone black are built by default in the
  Docker container. Copy the binaries from `/home/build/dbtoaster/bbb`
  to an SD-Card, and boot the bbb into U-Boot. Assume a working
  Linux installation is provided on the internal flash of the bbb
  that provides an appropriate device tree, enter
```u-boot
   load mmc 0:1 0x80800000 axfinder.img
   load mmc 1:1 0x88000000
   /boot/dtbs/4.1.15-ti-rt-r43/am335x-boneblack.dtb bootm 0x80800000 - 0x88000000`
```
  to run, for instance, the axfinder query from the finance dataset.

## Inspecting changes to DBToaster
- See https://github.com/lfd/dbtoaster-backend/tree/btw2021

## Pre-Built image and measured datasets
For convenience, the DOI archived artefacts are also available at
non-archival locations:

- A pre-built Docker image (including a fixed copy of all required
  sources) is available at
  https://cdn.lfdr.de/btw2021/btw2021-docker.tar.bz2 (1.5 GiB
  compressed/5.7 GiB uncompressed)
- Measured observations for all experiments discussed in the paper
  (raw data) are available at
  https://cdn.lfdr.de/btw2021/btw2021-data.tar.bz2 (4.7 GiB
  compressed/9.1 GiB uncompressed)

## Remarks
Please see the paper for a discussion of the structure of our
replication package.
