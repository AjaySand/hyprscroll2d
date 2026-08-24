.PHONY: test check

test:
	lua tests/run.lua
	lua tests/hyprland_adapter.lua
	lua tests/omarchy_integration.lua
	bash tests/installer.sh

check: test
	luac -p layout/*.lua integration/*.lua tests/*.lua
	bash -n install.sh uninstall.sh tests/installer.sh
