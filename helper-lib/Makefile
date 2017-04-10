# Makefile template for shared library

CPP        = g++ # C compiler
CXXFLAGS   = -fPIC -Wall -Wextra -O3 -g `pkg-config vips-cpp --cflags`
LDFLAGS    = -shared `pkg-config vips-cpp --libs`
RM         = rm -f  # rm command
TARGET_LIB = libimaginghelpers.so # target lib

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
	ldconfig

.PHONY: clean
clean:
	-${RM} ${TARGET_LIB} ${OBJS} $(SRCS:.cc=.d)