# Render pipeline.mmd to PNG and SVG for RFC embedding.
# Canonical source: skills/cicd-golden-pipeline/SKILL.md
# See AGENTS.md in this directory for when to rebuild.

MMD  := pipeline.mmd
PNG  := pipeline.png
SVG  := pipeline.svg
MMDC := npx --yes -p @mermaid-js/mermaid-cli mmdc

.PHONY: all diagrams clean

all: diagrams

diagrams: $(PNG) $(SVG)

$(PNG): $(MMD)
	$(MMDC) --input $< --output $@ --backgroundColor white --scale 2

$(SVG): $(MMD)
	$(MMDC) --input $< --output $@ --backgroundColor white

clean:
	rm -f $(PNG) $(SVG)
