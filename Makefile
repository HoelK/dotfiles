# Run `make` alone to list the targets.

SCRIPTS	:= scripts
TESTS	:= tests

.PHONY: help install uninstall test test-shell

help:
	@echo "make install       back up the current config and install the rice"
	@echo "make uninstall     remove the rice and restore the last backup"
	@echo "make test          run the Docker tests (FILTER=word to run only matching cases)"
	@echo "make test-shell    open a shell in a throwaway test container"

install:
	@./$(SCRIPTS)/install.sh

uninstall:
	@./$(SCRIPTS)/uninstall.sh

test:
	@./$(TESTS)/run.sh "$(FILTER)"

test-shell:
	@./$(TESTS)/run.sh --shell
