# Makefile for tt-oops System Diagnostic Data Collector

SHELL := /bin/bash
SHELLCHECK := shellcheck
SHELLCHECK_OPTS := -x -e SC2034 -e SC1090
SHELLCHECK_FILES := tt-oops.sh

.PHONY: all check build test clean install uninstall

# Default target
all: check

# Run shellcheck on script files
check:
	@echo "Running shellcheck on script files..."
	@if command -v $(SHELLCHECK) > /dev/null; then \
		$(SHELLCHECK) $(SHELLCHECK_OPTS) $(SHELLCHECK_FILES); \
		echo "Shellcheck passed!"; \
	else \
		echo "Error: shellcheck not found. Please install shellcheck."; \
		exit 1; \
	fi

# Build target (validates script syntax)
build:
	@echo "Validating script syntax..."
	@bash -n $(SHELLCHECK_FILES)
	@echo "Syntax validation passed!"

# Run the tool with basic options for testing
test:
	@echo "Running basic test..."
	@./tt-oops.sh --level basic --no-compress --log-level info

# Run with more detailed output
test-detailed:
	@echo "Running detailed test..."
	@./tt-oops.sh --level detailed --logs last-hour --no-compress --log-level debug

# Clean generated files
clean:
	@echo "Cleaning up..."
	@rm -rf tt-oops-output-* tt-oops-*.tar.gz

# Install script to /usr/local/bin
install:
	@echo "Installing tt-oops to /usr/local/bin..."
	@mkdir -p $(DESTDIR)/usr/local/bin
	@cp tt-oops.sh $(DESTDIR)/usr/local/bin/tt-oops
	@chmod 755 $(DESTDIR)/usr/local/bin/tt-oops
	@echo "Installation complete."

# Uninstall script
uninstall:
	@echo "Uninstalling tt-oops..."
	@rm -f $(DESTDIR)/usr/local/bin/tt-oops
	@echo "Uninstallation complete."

# Help target
help:
	@echo "Available targets:"
	@echo "  all           - Run the check target (default)"
	@echo "  check         - Run shellcheck on script files"
	@echo "  build         - Validate script syntax"
	@echo "  test          - Run basic test of the tool"
	@echo "  test-detailed - Run test with detailed collection"
	@echo "  clean         - Remove generated files"
	@echo "  install       - Install script to /usr/local/bin"
	@echo "  uninstall     - Remove script from /usr/local/bin"
	@echo "  help          - Show this help message"