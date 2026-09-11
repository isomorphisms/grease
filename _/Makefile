IDRIC ?= idris2
CHEZ ?= chezscheme
CC ?= cc
IDRIC_SOURCES := $(shell find src/Ish.idric src/Ish -type f -name '*.idric')

.PHONY: all check test acceptance clean

all: build/exec/ish

build/exec/ish: runtime/launch.c build/exec/ish-backend
	$(CC) -std=c11 -Wall -Wextra -Werror -o $@ $<

build/exec/ish-backend: $(IDRIC_SOURCES) ish.ipkg libish_runtime.so
	CHEZ=$(CHEZ) $(IDRIC) --build ish.ipkg

libish_runtime.so: runtime/execute.c
	$(CC) -std=c11 -Wall -Wextra -Werror -fPIC -shared -o $@ $<

test/probe: test/probe.c
	$(CC) -std=c11 -Wall -Wextra -Werror -o $@ $<

check: libish_runtime.so
	$(IDRIC) --source-dir src --check src/Ish.idric

test: build/exec/ish test/probe
	sh test/acceptance.sh

acceptance: clean
	$(MAKE) test
	$(MAKE) clean

clean:
	$(IDRIC) --clean ish.ipkg
	rm -rf build test/tmp
	rm -f libish_runtime.so runtime/*.o test/probe
