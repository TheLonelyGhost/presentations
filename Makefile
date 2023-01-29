SHELL = /bin/sh
REVEALJS_VERSION := 4.4.0
PANDOC := pandoc
PYTHON := python3

PRESENTATIONS = $(shell find ./ -mindepth 2 \( \! -path '*/node_modules/*' \) -and -type f -name '*.md' -print)
export PRESENTATION_LIST_HTML = $(foreach path,$(PRESENTATIONS:.md=.html),<li><a href="$(path)">$(path)</li> )

define pandoc_build
$(PANDOC) --from markdown --to revealjs --standalone --slide-level 3 --output $(2) $(1) -V 'transitionSpeed=fast' -V 'controlsTutorial=false' -V 'controlsLayout=bottom-right' -V 'revealjs-url=/node_modules/reveal.js'
endef

define pandoc_target

$(2): $(1)
	$(call pandoc_build,$(1),$(2))
endef

.PHONY: build
build: clean $(PRESENTATIONS:.md=.html) index.html

index.html: $(PRESENTATIONS:.md=.html)
	envsubst -i ./index.html.tpl -o index.html

.PHONY: http-server
http-server: index.html
	$(PYTHON) -m http.server

.PHONY: clean
clean:
	@rm -f ./index.html
	@find ./ -mindepth 2 \( \! -path '*/node_modules/*' \) -and -type f -name '*.html' -delete

$(foreach presentation,$(PRESENTATIONS),$(eval $(call pandoc_target,$(presentation),$(presentation:.md=.html))))
