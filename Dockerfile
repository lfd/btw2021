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
	less \
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
	default-jre \
	stress-ng

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

# 8. Integrate measurement dispatch code
WORKDIR /home/build/dbtoaster
ADD app/*.cc app/wscript app/Makefile ./
RUN mkdir -p rootfs/data generated

# 9. Build the DBToaster backend (i.e., libdbtoaster.a)
RUN echo "Hello, world"
WORKDIR /home/build/src
RUN git clone https://github.com/lfd/dbtoaster-backend.git
WORKDIR /home/build/src/dbtoaster-backend
RUN git checkout btw2021
WORKDIR /home/build/src/dbtoaster-backend/ddbtoaster/srccpp/lib
RUN make -j

WORKDIR /home/build/dbtoaster
RUN ln -s /home/build/src/dbtoaster-backend/ddbtoaster/srccpp/lib .
# TODO: These files should be included in the btw2021 repo and
# be copied into dbtoaster once they are in a mature state
RUN cp /home/build/src/dbtoaster-backend/ddbtoaster/srccpp/driver_sequential.cpp .

# 9. Build DBToaster header files for relevant TPCH and finance queries
# NOTE: We deliberately don't use -o Tpch<n>-V.hpp because then the class name
# in the generated code is adapted from query to Tpch<n>-V, which is an
# invalid C++ identifier
WORKDIR /home/build/dbtoaster-dist/dbtoaster/
RUN sed -i 's,examples/data/tpch/,data/tpch/,g' examples/queries/tpch/schemas.sql
RUN sed -i 's,examples/data/,data/,g' examples/queries/finance/*.sql
ADD queries/countbids.sql examples/queries/financial/
ADD queries/avgbrokerprice.sql examples/queries/financial/

ARG TPCH_BIN="1 2 6 12 14 11a 18a"
ARG FINANCE_BIN="vwap axfinder pricespread brokerspread missedtrades brokervariance countbids avgbrokerprice"

RUN /bin/bash -c 'for i in ${TPCH_BIN}; do \
	echo "Generating DBToaster code for TPCH query ${i}"; \
        bin/dbtoaster -l cpp examples/queries/tpch/query${i}.sql > $HOME/dbtoaster/generated/Tpch${i}-V.hpp; \
done'
RUN /bin/bash -c 'for Q in ${FINANCE_BIN}; do \
	echo "Generating DBToaster code for financial query ${Q}"; \
        bin/dbtoaster -l cpp examples/queries/finance/${Q}.sql > $HOME/dbtoaster/generated/${Q}.hpp; \
done'



# 10. Build TPCH example data, and copy finance data
# (we delibertely only build a very small data set for
# to "smoke test" if compiled binaries work properly)
WORKDIR /home/build/src/tpch-dbgen
RUN rm -rf *.tbl
RUN ./dbgen -s 0.01
# On occasion, the dbgen dungpile seemingly randomly assigns permissions
# 101 to generated tbl files. Dude...
RUN chmod 644 *.tbl
RUN mkdir -p /home/build/dbtoaster/rootfs/data/tpch/
RUN /bin/bash -c 'for file in *.tbl; do \
   f=`basename ${file} .tbl`; \
   cp ${f}.tbl /home/build/dbtoaster/rootfs/data/tpch/${f}.csv; \
done'
RUN curl https://raw.githubusercontent.com/dbtoaster/dbtoaster-experiments-data/master/finance/standard/finance.csv > /home/build/dbtoaster/rootfs/data/finance.csv


# 11. Build the DBToaster RTEMS app for x86 and all TPCH queries, using
# the TSC for time measurements
WORKDIR /home/build/dbtoaster
RUN mkdir -p rtems
RUN rm lib/libdbtoaster.a  # The distribution provided binary is for x86_64-linux
RUN ./waf configure --rtems=$HOME/rtems/5 --rtems-bsp=i386/pc586
RUN /bin/bash -c 'for i in ${TPCH_BIN}; do \
  rm -f build/i386-rtems5-pc586/{StreamDriver,driver_sequential}.*.{o,d}; \
  CXXFLAGS=-DUSE_RDTSC TPCH=${i} ./waf build; \
  mv build/i386-rtems5-pc586/dbtoaster.exe rtems/dbtoaster${i}.exe; \
done'


# 12. Build Linux binaries for all TPCH and financial queries
WORKDIR /home/build/dbtoaOBster
RUN mkdir -p linux/
RUN /bin/bash -c 'for i in ${TPCH_BIN}; do \
  TPCH=${i} make measure; \
done'

RUN /bin/bash -c 'for Q in ${FINANCE_BIN}; do \
  FINANCE=${Q} make finance; \
done'

# 13. Generate self-contained measurement package that can
# be deployed on Linux x86_64 targets
WORKDIR /home/build/dbtoaster
RUN ln -s rootfs/data .
ADD measure/dispatch.sh .
ADD measure/caps.sh .
ADD measure/rename.sh .
ADD measure/lib.r .
ADD measure/collect.r .
ADD measure/gen_arguments.r .
WORKDIR /home/build/dbtoaster/data/tpch
ADD measure/caps.sh .
RUN cp /home/build/src/tpch-dbgen/dbgen .
RUN cp /home/build/src/tpch-dbgen/dists.dss .
WORKDIR /home/build/dbtoaster
RUN tar --transform 's,^,measure/,' -cjhf ~/measure.tar.bz2 *.r *.sh linux/ data/
