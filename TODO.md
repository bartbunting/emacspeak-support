# TODO - Emacspeak Support Extensions

## emacspeak-markdown.el

### Voice Personality Improvements

- [ ] **Multiple emphasis markers** (`***text***` or `___text___`)
  - Currently: Not handled, reads all markup characters
  - Goal: Apply combined voice personality (bold + italic) without announcing
  - Implementation: Create or use existing combined voice personality that merges bold and italic characteristics
  - Priority: Medium
  - Notes: Deferred from initial cleanup pass to focus on voice personality system

## Future Extensions

- [ ] Consider adding support for other popular packages
- [ ] Explore integration with org-mode for cross-format navigation

## General Improvements

- [ ] Add automated tests for speech output
- [ ] Implement the [agent-shell accessibility plan](agent-shell-accessibility-plan.md)
- [ ] Document voice personality mappings in user guide
