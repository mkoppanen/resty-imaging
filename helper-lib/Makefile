# Makefile template for shared library

CPP        = g++
CXXFLAGS   = -fPIC -Wall -Wextra -O3 -g `pkg-config vips-cpp --cflags`
LDFLAGS    = -shared `pkg-config vips-cpp --libs`
RM         = rm -f 
TARGET_LIB = libimaginghelpers.so

SRCS = imaging.cc # source files
OBJS = $(SRCS:.cc=.o)

.PHONY: all
all: ${TARGET_LIB}

$(TARGET_LIB): $(OBJS)
	$(CPP) -o $@ $^ ${LDFLAGS}

$(SRCS:.cc=.d):%.d:%.cc
	$(CPP) $(CXXFLAGS) -MM $< >$@

include $(SRCS:.cc=.d)

install: all
	cp *.so /usr/local/lib

dylib: ${TARGET_LIB}
	$(CPP) -dynamiclib *.o -o libimaginghelpers.dylib ${LDFLAGS}
	cp libimaginghelpers.dylib ../test/libimaginghelpers.dylib

test: dylib
	cd ../test && luajit test.lua && luajit test_params.lua

.PHONY: clean
clean:
	-${RM} ${TARGET_LIB} ${OBJS} $(SRCS:.cc=.d)