# Build entry points for native Windows support under WSL.

.PHONY: windows-audio clean-windows-audio

windows-audio:
	$(MAKE) -C servers/windows-audio

clean-windows-audio:
	$(MAKE) -C servers/windows-audio clean
