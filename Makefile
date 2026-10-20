NVIM ?= nvim

.PHONY: test
test:
	$(NVIM) --headless -u NONE -l tests/matcher_spec.lua
	$(NVIM) --headless -u NONE -l tests/ui_spec.lua
