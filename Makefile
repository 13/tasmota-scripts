# berry = standalone Berry interpreter, https://github.com/berry-lang/berry
# (clone + make, then put the binary on PATH or pass BERRY=/path/to/berry)
BERRY ?= berry

.PHONY: check deploy list

check:
	$(BERRY) tools/be-check.be

deploy: check
	./deploy.sh --all

list:
	./deploy.sh --list
