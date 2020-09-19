.PHONY: all clean libdbtoaster

all: libdbtoaster measure.cc
	$(CXX) -static -o measure measure.cc -Ilib -O3 lib/libdbtoaster.a

libdbtoaster:
	$(MAKE) -C lib

clean:
	$(MAKE) clean -C lib
