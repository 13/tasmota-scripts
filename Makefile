# berry = standalone Berry interpreter, https://github.com/berry-lang/berry
# (clone + make, then put the binary on PATH or pass BERRY=/path/to/berry)
BERRY ?= berry

.PHONY: check test deploy list fleet

check:
	$(BERRY) tools/be-check.be
	./tools/check-map.sh

test:
	$(BERRY) tools/test_hz_ww.be
	$(BERRY) tools/test_wifi_watchdog.be
	$(BERRY) tools/test_autoexec.be

deploy: check
	DEPLOY_ALL=yes ./deploy.sh --all

list:
	./deploy.sh --list

fleet:
	./tools/fleet-check.sh
