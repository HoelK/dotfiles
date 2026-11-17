# Run `make` alone to list the targets.

SCRIPTS	:= scripts
TESTS	:= tests

.PHONY: help install uninstall diff check test test-shell

help:
	@echo "make install       back up the current config and install the rice"
	@echo "make uninstall     remove the rice and restore the last backup"
	@echo "make diff          compare the installed config with the repo (FULL=1 for the line by line diff)"
	@echo "make check         check that the programs and fonts the configs use are installed"
	@echo "make test          run the Docker tests (FILTER=word to run only matching cases)"
	@echo "make test-shell    open a shell in a throwaway test container"

install:
	@./$(SCRIPTS)/install.sh

uninstall:
	@./$(SCRIPTS)/uninstall.sh

# diff.sh exits 1 when something differs: that's a result, not a make error
diff:
	@./$(SCRIPTS)/diff.sh $(if $(FULL),--full); [ $$? -le 1 ]

# Same for check.sh: exit 1 means something is missing
check:
	@./$(SCRIPTS)/check.sh; [ $$? -le 1 ]

test:
	@./$(TESTS)/run.sh "$(FILTER)"

test-shell:
	@./$(TESTS)/run.sh --shell
