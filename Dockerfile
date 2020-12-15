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
RUN chmod +x waf

# TODO: Checkout a defined version here
RUN git clone git://git.rtems.org/rtems_waf.git rtems_waf
# Relocation to 0x200000: patch rtems-waf:
ADD patches/rtems-waf.diff /home/build/src/
WORKDIR /home/build/dbtoaster/rtems_waf
RUN git apply /home/build/src/rtems-waf.diff


# 1. Obtain RTEMS source builder and kernel sources
WORKDIR /home/build/src
RUN git clone https://github.com/RTEMS/rtems-source-builder.git
RUN git -C rtems-source-builder checkout ed5030bc24dbfdfac52074ed78cf4231bf1f353d

ADD patches/rsb-10.diff /home/build/src
WORKDIR /home/build/src/rtems-source-builder/rtems
RUN git apply /home/build/src/rsb-10.diff

# 2. Check environment
RUN ../source-builder/sb-check

# 3. Build toolchains for i386 and ARM
RUN ../source-builder/sb-set-builder --prefix=$HOME/rtems/6 6/rtems-i386
RUN ../source-builder/sb-set-builder --prefix=$HOME/rtems/6 6/rtems-arm

# 4. Make toolchain binaries available via PATH
ENV PATH /home/build/rtems/6/bin:$PATH

# 5. Clone and build for virtual and real measurement systems
RUN git clone https://github.com/lfd/rtems.git $HOME/src/rtems-default
RUN git -C $HOME/src/rtems-default checkout 5dc65ef9f435
RUN cp -av $HOME/src/rtems-default $HOME/src/rtems-jailhouse
RUN git -C $HOME/src/rtems-jailhouse checkout dbtoaster

# 6. bootstrap RTEMS BSP
WORKDIR /home/build/src/rtems-default
RUN ./bootstrap -c
RUN ./rtems-bootstrap
WORKDIR /home/build/src/rtems-jailhouse
RUN ./bootstrap -c
RUN ./rtems-bootstrap

# 7. Build RTEMS Default BSP
WORKDIR /home/build/build

RUN $HOME/src/rtems-default/configure --prefix=$HOME/rtems/6-default --target=i386-rtems6 --enable-rtemsbsp=pc686 --enable-posix --disable-networking --enable-rtems-debug
RUN make -j 20 && make install
RUN rm -rf /home/build/build/*

RUN $HOME/src/rtems-jailhouse/configure --prefix=$HOME/rtems/6-jailhouse --target=i386-rtems6 --enable-rtemsbsp=pc686 --enable-posix --disable-networking --enable-rtems-debug BSP_ENABLE_IDE=0 BSP_ENABLE_VGA=0 USE_COM1_AS_CONSOLE=1 BSP_GET_WORK_AREA_DEBUG=1
RUN make -j 20 && make install
RUN rm -rf /home/build/build/*

RUN $HOME/src/rtems-default/configure --prefix=$HOME/rtems/6-arm --target=arm-rtems6 --enable-rtemsbsp="realview_pbx_a9_qemu beagleboneblack" --enable-posix --disable-networking --enable-rtems-debug
RUN make -j 20  && make install
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
ADD queries/countbids.sql examples/queries/finance/
ADD queries/countone.sql examples/queries/finance/
ADD queries/avgbrokerprice.sql examples/queries/finance/

ARG TPCH_BIN="1 2 6 12 14 11a 18a"
ARG FINANCE_BIN="vwap axfinder pricespread brokerspread missedtrades brokervariance countbids countone avgbrokerprice"

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

# ONLY FOR COUNTONE!
RUN /bin/bash -c 'for i in $(seq 0 95); do cat /home/build/dbtoaster/rootfs/data/finance.csv >> /tmp/foo.dat; done'
RUN mv /tmp/foo.dat /home/build/dbtoaster/rootfs/data/finance.csv

# 11. Build the DBToaster RTEMS app for x86 and all TPCH queries, using
# the TSC for time measurements
WORKDIR /home/build/dbtoaster
RUN mkdir -p rtems-default rtems-jailhouse
RUN rm lib/libdbtoaster.a  # The distribution provided binary is for x86_64-linux

# Configure and build for 6-default
RUN ./waf configure --rtems=$HOME/rtems/6-default --rtems-tools=$HOME/rtems/6 --rtems-bsp=i386/pc686

RUN /bin/bash -c 'for i in ${TPCH_BIN}; do \
  rm -f build/i386-rtems6-pc686/{StreamDriver,driver_sequential}.*.{o,d}; \
  CXXFLAGS=-DUSE_RDTSC QUERY=Tpch${i}-V ./waf build; \
  mv build/i386-rtems6-pc686/dbtoaster.exe rtems-default/tpch${i}.exe; \
done'

RUN /bin/bash -c 'for i in ${FINANCE_BIN}; do \
  rm -f build/i386-rtems6-pc686/{StreamDriver,driver_sequential}.*.{o,d}; \
  CXXFLAGS=-DUSE_RDTSC QUERY=${i} ./waf build; \
  mv build/i386-rtems6-pc686/dbtoaster.exe rtems-default/finance${i}.exe; \
done'
RUN ./waf clean

# Configure and build for 6-jailhouse
RUN ./waf configure --rtems=$HOME/rtems/6-jailhouse --rtems-tools=$HOME/rtems/6 --rtems-bsp=i386/pc686
RUN /bin/bash -c 'for i in ${TPCH_BIN}; do \
  rm -f build/i386-rtems6-pc686/{StreamDriver,driver_sequential}.*.{o,d}; \
  CXXFLAGS=-DUSE_RDTSC QUERY=Tpch${i}-V ./waf build; \
  mv build/i386-rtems6-pc686/dbtoaster.exe rtems-jailhouse/tpch${i}.exe; \
done'

RUN /bin/bash -c 'for i in ${FINANCE_BIN}; do \
  rm -f build/i386-rtems6-pc686/{StreamDriver,driver_sequential}.*.{o,d}; \
  CXXFLAGS=-DUSE_RDTSC QUERY=${i} ./waf build; \
  mv build/i386-rtems6-pc686/dbtoaster.exe rtems-jailhouse/finance${i}.exe; \
done'
RUN ./waf clean

# 12. Build Linux binaries for all TPCH and financial queries
WORKDIR /home/build/dbtoaster
RUN mkdir -p linux/
RUN /bin/bash -c 'for i in ${TPCH_BIN}; do \
  TPCH=${i} make measure; \
done'

RUN /bin/bash -c 'for Q in ${FINANCE_BIN}; do \
  FINANCE=${Q} make finance; \
done'

## 12.b Build Linux binaries with TSC based measurements
WORKDIR /home/build/src/dbtoaster-backend/ddbtoaster/srccpp/lib
RUN make clean
RUN CXXFLAGS="-DUSE_RDTSC" make -j
WORKDIR /home/build/dbtoaster
RUN mkdir -p linux/
RUN /bin/bash -c 'for i in ${TPCH_BIN}; do \
  TPCH=${i} make measure_tsc; \
done'

RUN /bin/bash -c 'for Q in ${FINANCE_BIN}; do \
  FINANCE=${Q} make finance_tsc; \
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
