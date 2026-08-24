.PHONY: test check

test:
	lua tests/run.lua
	lua tests/hyprland_adapter.lua
	lua tests/omarchy_integration.lua

check: test
	luac -p layout/*.lua integration/*.lua tests/*.lua
