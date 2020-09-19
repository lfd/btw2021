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
ADD rtems.diff  /home/build/src
RUN cat ../rtems.diff | patch -p1

WORKDIR /home/build/src/rsb
ADD rsb.patch /home/build/src
RUN cat ../rsb.patch | patch -p1


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
RUN rm -rf /home/build/build

RUN $HOME/src/rtems-5.1/configure --prefix=$HOME/rtems/5 --target=arm-rtems5 --enable-rtemsbsp="realview_pbx_a9_qemu beagleboneblack" --enable-posix --disable-networking --enable-rtems-debug
RUN make -j  && make install
RUN rm -rf /home/build/build


# 6. Install DBToaster
WORKDIR /home/build/dbtoaster-dist
RUN curl https://dbtoaster.github.io/dist/dbtoaster_2.3_linux.tgz | tar xzf -
ENV PATH /home/build/dbtoaster-bin/bin:$PATH


# 7. Download and build DbGen
WORKDIR /home/build/src
RUN git clone https://github.com/electrum/tpch-dbgen.git
WORKDIR /home/build/src/tpch-dbgen
RUN make


# 8. Build the DBToaster RTEMS app
WORKDIR /home/build/dbtoaster
RUN mkdir -p lib
RUN cp -r /home/build/dbtoaster-dist/lib/dbt_c++/* lib/
RUN rm lib/libdbtoaster.a
# ADD dbtoaster/ .
# RUN ./waf configure --rtems=$HOME/rtems/5 --rtems-bsp=arm/realview_pbx_a9_qemu 
# RUN ./waf build 1>&2
