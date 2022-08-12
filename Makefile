# Predictable shell behavior
.SHELLFLAGS=-cuef -o pipefail
SHELL=/bin/bash

# What are we building...
LIB_TARGETS=
BIN_TARGETS=hello_c hello_cpp

# What modules goes in hello_c
hello_c_HDR:=$(wildcard hello_c/*.h*)
hello_c_SRC:=$(wildcard hello_c/*.c*)
hello_c_OBJS:=${hello_c_SRC:%.cpp=%.o}

# What modules goes in hello_cpp
hello_cpp_HDR:=$(wildcard hello_cpp/*.h*)
hello_cpp_SRC:=$(wildcard hello_cpp/*.c*)
hello_cpp_OBJS:=${hello_cpp_SRC:%.cpp=%.o}

# Where are we putting the output (for pack later)
LIBOUT:=lib
BINOUT:=bin

# CXX=clang++
CXX=g++

# CXXFLAGS:=${CXXFLAGS} -fconcepts-diagnostics-depth=2 -std=c++17 -g  --coverage -Wall
# CXXFLAGS:=${CXXFLAGS} -std=c++17 -g -fno-inline --coverage -Wall
CXXFLAGS:=${CXXFLAGS} -std=c++17 -O3 -Wall

ARFLAGS:=rcs
INCS=${LIB_TARGETS:%=-I %/include} -isystem /usr/include/eigen3
LIBS=${LIB_TARGETS:lib%=-l%} -lpthread
LDFLAGS=--coverage -g -L${LIBOUT}
# LDFLAGS=-g -L${LIBOUT}
# LDFLAGS=-L${LIBOUT}

# Simplify some of the rules
VPATH:=${LIBOUT}:${BINOUT}

what:
	@echo "   bins: ${BIN_TARGETS:%=${BINOUT}/%}"
	@echo "hello_c: ${hello_c_OBJS}"

${LIBOUT}:
	mkdir -p $@

libs: ${LIB_TARGETS:%=${LIBOUT}/%.a}

${BINOUT}:
	mkdir -p $@

bins: ${BINOUT} ${BIN_TARGETS:%=${BINOUT}/%}

#==== Tests ====
TEST_SRC:=$(wildcard test/*.cpp)
# TEST_SRC:=test/utest.cpp test/test_ioblk.cpp test/test_blocks.cpp

.PHONY: test
test: test/test
	@echo "Running tests ..."
	@test/test

test/test: Makefile ${TEST_SRC:%.cpp=%.o} ${LIB_TARGETS:%=${LIBOUT}/%.a} ${libcodie_HDR}
	@echo "Building tests ..."
	@${CXX} ${LDFLAGS} -o $@ ${TEST_SRC:%.cpp=%.o} ${LIBS}

.PHONY dox: ${DOX_TARGETS:%=dox/%/index.html}

#==== We need to do this for every bin-target ====
define BIN_templ =
$${BINOUT}/$(1): $${$(1)_OBJS} $${$(1)_HDR}
	$$(shell mkdir -p build/bin)
	$${CXX} $${LDFLAGS}  -o $$@ $${$(1)_OBJS} $${LIBS}
endef

# Apply template above to all bin-targets
$(foreach bin,$(BIN_TARGETS),$(eval $(call BIN_templ,$(bin))))

#==== We need to do this for every lib-target ====
define LIB_templ =
$${LIBOUT}/$(1).a: $${$(1)_OBJS}
	$$(shell mkdir -p $${LIBOUT})
	@$${AR} $${ARFLAGS}  $$@ $${$(1)_OBJS}

#  include $${$(1)_OBJS:%.o=%.d}
endef

# Apply template above to all lib-targets
$(foreach bin,$(LIB_TARGETS),$(eval $(call LIB_templ,$(bin))))

#==== Generic compile rules ====
%.o: %.cpp
	@${CXX} ${CXXFLAGS} ${INCS} -o $@ -c $<

%.o: %.c
	@${CXX} ${CXXFLAGS} ${INCS} -o $@ -c $<

cov: test/test
	test/test
	@mkdir -p cov
	gcovr -k -e test --html --html-details --exclude-throw-branches --exclude-unreachable-branches --html-title "Coverage"  --output cov/index.html

clean:
	@echo "Cleaning up C++ build ..."
	@rm -rf ${LIBOUT}/* ${BINOUT}/* ./codie.tgz tmp.png bw.png sharp.png
	@[ -d lib ] && find lib/ -type f -delete || true
	@[ -d bin ] && find bin/ -type f -delete || true
	@find . -name '*.o' -delete
	@find . -name '*.gc??' -delete
	@find . -name '*.d' -delete

purge: clean
	@echo "Cleaning up Doxygen and Coverage ..."
	@rm -rf cov ${LIBOUT} ${BINOUT}
