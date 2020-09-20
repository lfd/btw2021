# The main binary (measure) is marked phony because it
# depends on the generated DBtoaster code passed in
# via -include. This means we may want to rebuild even
# when measure.cc has not changed.
# 
.PHONY: measure clean libdbtoaster

TPCH ?= 1

measure: libdbtoaster measure.cc
	$(CXX) $(CXXFLAGS) -include generated/Tpch$(TPCH)-V.hpp -o measure measure.cc -Ilib -O3 lib/libdbtoaster.a

libdbtoaster:
	$(MAKE) -C lib

clean:
	$(MAKE) clean -C lib
