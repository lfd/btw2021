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
RUN mkdir -p rootfs/examples/data generated

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
RUN cp /home/build/src/dbtoaster-backend/ddbtoaster/srccpp/StreamProgram.cpp   .
RUN cp /home/build/src/dbtoaster-backend/ddbtoaster/srccpp/driver_sequential.cpp .
RUN cp /home/build/src/dbtoaster-backend/ddbtoaster/srccpp/StreamProgram.hpp .

# 9. Build DBToaster header files for all TPCH queries
# NOTE: We deliberately don't use -o Tpch<n>-V.hpp because then the class name
# in the generated code is adapted from query to Tpch<n>-V, which is an
# invalid C++ identifier
WORKDIR /home/build/dbtoaster-dist/dbtoaster/
#RUN /bin/bash -c 'for i in {1..22}; do \
RUN /bin/bash -c 'for i in 1 2 6 12 14; do \
	echo "Generating DBToaster code for TPCH query ${i}"; \
        bin/dbtoaster -l cpp examples/queries/tpch/query${i}.sql > $HOME/dbtoaster/generated/Tpch${i}-V.hpp; \
done'


# 10. Build TPCH example data
WORKDIR /home/build/src/tpch-dbgen
RUN rm -rf *.tbl
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
#RUN /bin/bash -c 'for i in {1..22}; do \
RUN /bin/bash -c 'for i in 1 6; do \
  rm -f build/i386-rtems5-pc586/{StreamDriver,driver_sequential}.*.{o,d}; \
  TPCH=${i} ./waf build; \
  mv build/i386-rtems5-pc586/dbtoaster.exe rtems/dbtoaster${i}.exe; \
done'


# 12. Build Linux binaries for all TPCH queries
WORKDIR /home/build/dbtoaster
RUN mkdir -p linux/
#RUN /bin/bash -c 'for i in {1..22}; do \
RUN /bin/bash -c 'for i in 1 2 6 12 14; do \
  TPCH=${i} make; \
done'

# 13. Generate self-contained measurement package that can
# be deployed on Linux x86_64 targets
WORKDIR /home/build/dbtoaster
RUN ln -s rootfs/examples .
ADD measure/dispatch.sh .
ADD measure/stressors .
RUN tar --transform 's,^,measure/,' -cjhf ~/measure.tar.bz2 dispatch.sh stressors linux/ examples/


########################### Scrap below here ##############################
#USER root
#RUN apt-get install  -y --no-install-recommends ocaml
##libboost-dev \
##                     libboost-filesystem-dev libboost-program-options-dev \
##                     libboost-thread-dev
#USER build

#WORKDIR /home/build/src
#RUN git clone https://github.com/dbtoaster/dbtoaster-a5.git
##ADD patches/dbtoaster-a5/0001-Fix-STL-vs-Boost-bitrot.patch .
#ADD patches/dbtoaster-a5/0002-Fix-makefile.patch .
#ADD patches/dbtoaster-a5/0003-Don-t-statically-link-ocaml-objects.patch .
##ADD patches/dbtoaster-a5/0004-Add-dispatcher-file.patch .
##ADD patches/dbtoaster-a5/0005-Minimise-perturbations-and-system-noise-during-measu.patch .

#WORKDIR /home/build/src/dbtoaster-a5
##RUN cat ../0001-Fix-STL-vs-Boost-bitrot.patch | patch -p1
#RUN cat ../0002-Fix-makefile.patch | patch -p1
#RUN cat ../0003-Don-t-statically-link-ocaml-objects.patch | patch -p1
##RUN cat ../0004-Add-dispatcher-file.patch | patch -p1
##RUN cat ../0005-Minimise-perturbations-and-system-noise-during-measu.patch | patch -p1

#RUN make bin/dbtoaster
##WORKDIR /home/build/src/dbtoaster-a5/lib/dbt_c++
##RUN make -j

# Change relative data input path that is encoded
# into DBToaster-generated header files to data/tpch
#RUN sed -i 's,../../experiments/data/tpch/,data/tpch/,g' test/queries/tpch/schemas.sql

# NOTE: We deliberately don't use -o Tpch<n>-V.hpp because then the class name
# in the generated code is adapted from query to Tpch<n>-V, which is an
# invalid C++ identifier
#WORKDIR /home/build/src/dbtoaster-a5/
#RUN mkdir -p /home/build/src/dbt-headers
#RUN /bin/bash -c 'for i in {1..22}; do \
#    bin/dbtoaster -l CPP test/queries/tpch/query${i}.sql > ~/src/dbt-headers/Tpch${i}-V.hpp; \
#done'

#USER root
#RUN setcap cap_ipc_lock+eip linux/measure1
#RUN setcap cap_ipc_lock+eip linux/measure6
#RUN setcap cap_ipc_lock+eip linux/measure12
#USER build


#    c++ -g -I. -Ilib/dbt_c++ -include query${i}.hpp main.cpp lib/dbt_c++/libdbtoaster.a -lboost_serialization 
#        -lboost_program_options -lboost_thread -lpthread -lboost_filesystem -lboost_iostreams -o linux/measure${i}; 


#echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
#curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add
#sudo apt-get update
#sudo apt-get install sbt