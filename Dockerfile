# Replication package for the BTW docker@rtems paper
FROM ubuntu:18.04

MAINTAINER Wolfgang Mauerer "wolfgang.mauerer@othr.de"

ENV DEBIAN_FRONTEND noninteractive
ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"

RUN apt update && apt -y dist-upgrade

RUN apt install -y --no-install-recommends \
	build-essential \
	python \
	python-dev \
	python3 \
	python3-dev \
	unzip \
        sudo \
	joe \
	bison \
	flex \
	ca-certificates \
	curl \
	git \
	openssh-client \
	qemu-system-arm \
	qemu-system-i386 \
	sudo \
	texinfo \
	libz-dev \
	pax \
	u-boot-tools \
	libncurses-dev \
	default-jre

# To build gcc with rsb, we need python 2.7 (otherwise, the build breaks)
# To use waf, we want python 3.6 (otherwise, each command invocations
# stalls for 30'' for some reason before doing anything)
RUN update-alternatives --install /usr/bin/python python /usr/bin/python2.7 2
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1

RUN useradd -m -G sudo -s /bin/bash build && echo "build:build" | chpasswd
USER build
WORKDIR /home/build

# Prepare directory structure
## src/              - to store external source packages
## dbtoaster/       - the measurement code proper (dbtoaster app sources)
## rtems/           - binary toolchain and BSPs for RTEMS
## build/           - temporary directory for out-of-tree builds
## dbtoaster-dist/  - upstream DBToaster distribution including query sources
RUN mkdir -p $HOME/src $HOME/dbtoaster $HOME/rtems $HOME/build $HOME/dbtoaster-dist
WORKDIR /home/build/dbtoaster
RUN curl https://waf.io/waf-2.0.19 > waf
# TODO: Checkout a defined version here
RUN git clone git://git.rtems.org/rtems_waf.git rtems_waf
RUN chmod +x waf


# 1. Obtain RTEMS source builder and kernel sources
WORKDIR /home/build/src
RUN curl https://ftp.rtems.org/pub/rtems/releases/5/5.1/sources/rtems-source-builder-5.1.tar.xz | tar xJf -
RUN curl https://ftp.rtems.org/pub/rtems/releases/5/5.1/sources/rtems-5.1.tar.xz | tar xJf -
RUN mv rtems-source-builder-5.1 rsb

# ... and patch up some things
WORKDIR /home/build/src/rtems-5.1
ADD patches/rtems.diff  /home/build/src
RUN cat ../rtems.diff | patch -p1

WORKDIR /home/build/src/rsb
ADD patches/rsb.diff /home/build/src
RUN cat ../rsb.diff | patch -p1


# 2. Check environment
WORKDIR /home/build/src/rsb/rtems
RUN ../source-builder/sb-check


# 3. Build toolchains for i386 and ARM
WORKDIR /home/build/src/rsb/rtems
RUN ../source-builder/sb-set-builder --prefix=$HOME/rtems/5 5/rtems-i386
RUN ../source-builder/sb-set-builder --prefix=$HOME/rtems/5 5/rtems-arm


# 4. Make toolchain binaries available via PATH
ENV PATH /home/build/rtems/5/bin:$PATH


# 5. Build rtems BSPs for virtual and real measurement systems
WORKDIR /home/build/build
RUN $HOME/src/rtems-5.1/configure --prefix=$HOME/rtems/5 --target=i386-rtems5 --enable-rtemsbsp=pc586 --enable-posix --disable-networking --enable-rtems-debug
RUN make -j && make install
RUN rm -rf /home/build/build/*

RUN $HOME/src/rtems-5.1/configure --prefix=$HOME/rtems/5 --target=arm-rtems5 --enable-rtemsbsp="realview_pbx_a9_qemu beagleboneblack" --enable-posix --disable-networking --enable-rtems-debug
RUN make -j  && make install
RUN rm -rf /home/build/build/*


# 6. Install DBToaster
WORKDIR /home/build/dbtoaster-dist
RUN curl https://dbtoaster.github.io/dist/dbtoaster_2.3_linux.tgz | tar xzf -
ENV PATH /home/build/dbtoaster-dist/dbtoaster/bin:$PATH


# 7. Download and build DbGen
WORKDIR /home/build/src
RUN git clone https://github.com/electrum/tpch-dbgen.git
WORKDIR /home/build/src/tpch-dbgen
RUN make


USER root
RUN update-alternatives --set python /usr/bin/python3.6
USER build

# 8. Integrate measurement dispatch code (and patch DBToaster)
WORKDIR /home/build/dbtoaster
ADD app/*.cc app/wscript app/Makefile ./
RUN mkdir -p lib rootfs/examples/data generated
RUN cp -r /home/build/dbtoaster-dist/dbtoaster/lib/dbt_c++/* lib
WORKDIR /home/build/dbtoaster/lib
ADD patches/dbtoaster_log.diff /home/build/src
RUN cat /home/build/src/dbtoaster_log.diff | patch -p1


# 9. Build DBToaster header files for all TPCH queries
# NOTE: We deliberately don't use -o ... because then the class name
# in the generated code is adapted from query to Tpch-Vn, which is an
# invalid C++ identifier
WORKDIR /home/build/dbtoaster-dist/dbtoaster/
RUN /bin/bash -c 'for i in {1..22}; do \
        echo "Generating DBToaster code for TPCH query ${i}"; \
        bin/dbtoaster -l cpp examples/queries/tpch/query${i}.sql > $HOME/dbtoaster/generated/Tpch${i}-V.hpp; \
done'


# 10. Build TPCH example data
WORKDIR /home/build/src/tpch-dbgen
RUN ./dbgen -s 0.1
# On occasion, the dbgen dungpile seemingly randomly assigns permissions
# 101 to generated tbl files. Dude...
RUN chmod 644 *.tbl
RUN mkdir -p /home/build/dbtoaster/rootfs/examples/data/tpch/
RUN /bin/bash -c 'for file in *.tbl; do \
   f=`basename ${file} .tbl`; \
   cp ${f}.tbl /home/build/dbtoaster/rootfs/examples/data/tpch/${f}.csv; \
done'

# 11. Build the DBToaster RTEMS app for all TPCH queries
WORKDIR /home/build/dbtoaster
RUN mkdir -p rtems
RUN rm lib/libdbtoaster.a  # The distribution provided binary is for x86_64-linux
RUN ./waf configure --rtems=$HOME/rtems/5 --rtems-bsp=i386/pc586
RUN /bin/bash -c 'for i in {1..22}; do \
  rm -f build/i386-rtems5-pc586/measure.cc.*.{o,d}; \
  TPCH=${i} ./waf build; \
  mv build/i386-rtems5-pc586/dbtoaster.exe rtems/dbtoaster${i}.exe; \
done'


# 12. Build Linux binaries for all TPCH queries
WORKDIR /home/build/dbtoaster
RUN mkdir -p linux/
RUN /bin/bash -c 'for i in {1..22}; do \
  TPCH=${i} make; \
done'

# 13. Generate self-contained measurement package that can
# be deployed on Linux x86_64 targets
WORKDIR /home/build/dbtoaster
RUN ln -s rootfs/examples .
ADD measure/dispatch.sh .
ADD measure/stressors .
RUN tar --transform 's,^,measure/,' -cjhf ~/measure.tar.bz2 dispatch.sh stressors linux/ examples/
