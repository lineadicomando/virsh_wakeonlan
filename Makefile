# Default target
.DEFAULT_GOAL := install

# Project files
SERVICE_NAME := virsh_wakeonlan.service
SCRIPT_FILES := virsh_wakeonlan_start_vm.sh virsh_wakeonlan_listener.py

# Installation paths
BIN_DIR := /usr/local/bin
SYSTEMD_DIR := /etc/systemd/system

.PHONY: help install uninstall check

check: ## Verify system requirements (systemd present, root privileges, Python >= 3.8, virsh present)
	@echo "Checking system requirements..."
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "Error: this command must be run as root."; \
		exit 1; \
	fi
	@if ! command -v systemctl >/dev/null 2>&1; then \
		echo "Error: systemd (systemctl) is not available on this system."; \
		exit 1; \
	fi
	@if [ ! -x /usr/bin/python3 ]; then \
		echo "Error: /usr/bin/python3 is not installed."; \
		exit 1; \
	fi
	@if ! command -v virsh >/dev/null 2>&1; then \
		echo "Error: virsh (libvirt client) is not installed."; \
		exit 1; \
	fi
	@PY_VERSION=$$(/usr/bin/python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))'); \
	PY_MAJOR=$$(echo $$PY_VERSION | cut -d. -f1); \
	PY_MINOR=$$(echo $$PY_VERSION | cut -d. -f2); \
	if [ "$$PY_MAJOR" -lt 3 ] || { [ "$$PY_MAJOR" -eq 3 ] && [ "$$PY_MINOR" -lt 8 ]; }; then \
		echo "Error: /usr/bin/python3 >= 3.8 is required (found $$PY_VERSION)."; \
		exit 1; \
	fi
	@echo "All checks passed."

install: check ## Install scripts and enable/start the systemd service
	@echo "Installing scripts to $(BIN_DIR)..."
	install -m 755 virsh_wakeonlan_start_vm.sh $(BIN_DIR)/virsh_wakeonlan_start_vm.sh
	install -m 755 virsh_wakeonlan_listener.py $(BIN_DIR)/virsh_wakeonlan_listener.py
	@echo "Installing systemd service..."
	install -m 644 $(SERVICE_NAME) $(SYSTEMD_DIR)/$(SERVICE_NAME)
	@echo "Reloading systemd daemon..."
	systemctl daemon-reload
	@echo "Enabling service $(SERVICE_NAME)..."
	systemctl enable $(SERVICE_NAME)
	@echo "Starting service $(SERVICE_NAME)..."
	systemctl start $(SERVICE_NAME)
	@echo "Installation completed."

uninstall: ## Remove scripts and uninstall/disable/stop the systemd service
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "Error: this command must be run as root."; \
		exit 1; \
	fi
	@echo "Stopping service $(SERVICE_NAME)..."
	-systemctl stop $(SERVICE_NAME)
	@echo "Disabling service $(SERVICE_NAME)..."
	-systemctl disable $(SERVICE_NAME)
	@echo "Removing systemd service..."
	rm -f $(SYSTEMD_DIR)/$(SERVICE_NAME)
	@echo "Removing installed scripts from $(BIN_DIR)..."
	rm -f $(BIN_DIR)/virsh_wakeonlan_start_vm.sh
	rm -f $(BIN_DIR)/virsh_wakeonlan_listener.py
	@echo "Reloading systemd daemon..."
	systemctl daemon-reload
	@echo "Uninstallation completed."

help: ## Show available commands
	@echo "Available commands:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(firstword $(MAKEFILE_LIST)) | sed -n 's/^\([^:]*\):.*## \(.*\)/\1|\2/p' | while IFS='|' read -r target desc; do \
		printf "  %-17s %s\n" "$$target" "$$desc"; \
	done
	@if [ "$(firstword $(MAKEFILE_LIST))" != "$(lastword $(MAKEFILE_LIST))" ]; then \
		echo ""; \
		echo "Additional local commands:"; \
		grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(lastword $(MAKEFILE_LIST)) | sed -n 's/^\([^:]*\):.*## \(.*\)/\1|\2/p' | while IFS='|' read -r target desc; do \
			printf "  %-17s %s\n" "$$target" "$$desc"; \
		done; \
	fi
