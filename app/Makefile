# The main binary (measure) is marked phony because it
# depends on the generated DBtoaster code passed in
# via -include. This means we may want to rebuild even
# when measure.cc has not changed.
# 
.PHONY: measure finance clean libdbtoaster

TPCH ?= 1
FINANCE ?= vwap

measure: libdbtoaster
	$(CXX) $(CXXFLAGS) -include generated/Tpch$(TPCH)-V.hpp -o linux/tpch$(TPCH) driver_sequential.cpp -Ilib/ -O3 lib/libdbtoaster.a -lrt

finance: libdbtoaster
	$(CXX) $(CXXFLAGS) -include generated/$(FINANCE).hpp -o linux/finance$(FINANCE) driver_sequential.cpp -Ilib/ -O3 lib/libdbtoaster.a -lrt

libdbtoaster:
	$(MAKE) -C lib

clean:
	$(MAKE) clean -C lib
