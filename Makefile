IDRIC ?= idris2
CHEZ ?= chezscheme
CC ?= cc

.PHONY: all check test clean

all: build/exec/ish

build/exec/ish: runtime/launch.c build/exec/ish-backend
	$(CC) -std=c11 -Wall -Wextra -Werror -o $@ $<

build/exec/ish-backend: src/Ish.idric ish.ipkg libish_runtime.so
	CHEZ=$(CHEZ) $(IDRIC) --build ish.ipkg

libish_runtime.so: runtime/execute.c
	$(CC) -std=c11 -Wall -Wextra -Werror -fPIC -shared -o $@ $<

test/probe: test/probe.c
	$(CC) -std=c11 -Wall -Wextra -Werror -o $@ $<

check: libish_runtime.so
	$(IDRIC) --source-dir src --check src/Ish.idric

test: build/exec/ish test/probe
	sh test/acceptance.sh

clean:
	$(IDRIC) --clean ish.ipkg
	rm -f libish_runtime.so test/probe
