# Build entry points for native Windows support under WSL.

.PHONY: windows-audio clean-windows-audio windows-outloud clean-windows-outloud \
	windows-dtk clean-windows-dtk

windows-audio:
	$(MAKE) -C servers/windows-audio

clean-windows-audio:
	$(MAKE) -C servers/windows-audio clean

windows-outloud:
	$(MAKE) -C servers/windows-eloquence

clean-windows-outloud:
	$(MAKE) -C servers/windows-eloquence clean

windows-dtk:
	$(MAKE) -C servers/windows-dectalk

clean-windows-dtk:
	$(MAKE) -C servers/windows-dectalk clean
