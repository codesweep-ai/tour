# simple-tools-demo
#
# Two modes, and they resolve differently.
#
# DEV MODE covers the tools this repository is edited with. They come from npm,
# pinned in package.json and package-lock.json, invoked from node_modules/.bin.
#
# USE MODE covers cs-campaign, whose output this repository consumes. It has no
# npm package and no published release, so it is installed from the Go module
# proxy into tools/ at the version pinned below. That needs a Go toolchain.

CS_LEDGER  ?= ./node_modules/.bin/cs-ledger
CS_LINT    ?= ./node_modules/.bin/cs-lint
LEDGER_DIR ?= ledger

# CAMPAIGN_VERSION is the only version to choose. The cs-sandbox, cs-tracer and
# cs-vcr it needs are derived from that campaign's own go.mod on the module proxy,
# so the chain cannot drift apart here. Set SANDBOX_VERSION to override.
CAMPAIGN_VERSION ?= v0.0.0-20260917015214-48a6d6745bb3
SANDBOX_VERSION  ?=
TOOLSDIR         := $(abspath tools)
CAMPAIGN_MOD     := https://proxy.golang.org/github.com/codesweep-ai/campaign/@v/$(CAMPAIGN_VERSION).mod

CAMPAIGN_NAME ?= hello
CAMPAIGN_SRC  := $(CURDIR)/campaign/hello
WORKDIR       := $(CURDIR)/.work
CAMPAIGN_WS   := $(WORKDIR)/$(CAMPAIGN_NAME)
APP_REPO      := $(WORKDIR)/hello-app
FW_MODEL      ?= fireworks-ai/accounts/fireworks/models/kimi-k2p7-code
VM_PORT       ?= 5173
FORWARD_PID   := $(WORKDIR)/forward.pid
VIEW_PID      := $(WORKDIR)/view.pid
SANDBOX       := $(TOOLSDIR)/cs-sandbox

# One invocation for cs-campaign, so no part of the chain comes from elsewhere:
# tools/ first on PATH supplies the pinned cs-sandbox and the agent tools it
# validates, and CS_CAMPAIGN_GUEST_BIN supplies the member binary that a
# proxy-installed cs-campaign carries only as a placeholder.
CAMPAIGN = PATH="$(TOOLSDIR):$$PATH" \
           CS_SANDBOX_BIN="$(TOOLSDIR)/cs-sandbox" \
           CS_CAMPAIGN_GUEST_BIN="$(TOOLSDIR)/cs-campaign-member" \
           $(TOOLSDIR)/cs-campaign

.DEFAULT_GOAL := help

.PHONY: help help-all setup check doctor clean clean-all demo-clean \
        demo demo-start demo-watch demo-stop demo-destroy show-reports show-app \
        lint ledger ledger-render no-local-paths \
        demo-preflight demo-profile demo-validate demo-reset demo-wait \
        demo-fetch demo-archive demo-dispatch-page demo-trajectories

## help: the commands you are likely to want
help:
	@echo ""
	@echo "  simple-tools-demo"
	@echo ""
	@echo "  just cloned it            make setup"
	@echo "  check before spending     make demo-validate"
	@echo "  run it                    make demo          (follow: make demo-watch)"
	@echo "  read the reports          make show-reports"
	@echo "  clean up the demo         make demo-clean"
	@echo "  back to nothing           make demo-clean clean-all"
	@echo ""
	@echo "  commands"
	@echo ""
	@grep -hE '^## [a-z][a-z-]*:' $(MAKEFILE_LIST) | sed 's/^## //' \
	  | awk -F': ' '{printf "  %-16s %s\n", $$1, substr($$0, index($$0,": ")+2)}'
	@echo ""
	@echo "  individual stages:  make help-all"
	@echo ""

## help-all: the above, plus every individual stage
help-all: help
	@echo "  stages"
	@echo ""
	@grep -hE '^### [a-z][a-z-]*:' $(MAKEFILE_LIST) | sed 's/^### //' \
	  | awk -F': ' '{printf "  %-20s %s\n", $$1, substr($$0, index($$0,": ")+2)}'
	@echo ""

## setup: install both sets of tools, prove the chain, and name what is missing
##
## The tools are only half of it. The demo lends a Fireworks key from a host file,
## so this ends by saying whether that file is there. Lending reads a file rather
## than an environment variable, which is why an exported key is not enough.
setup:
	npm install
	@$(MAKE) --no-print-directory tools
	@$(MAKE) --no-print-directory doctor
	@echo ""
	@if [ -s "$$HOME/.cs-keys/fireworks" ]; then \
	  echo "  credential  ~/.cs-keys/fireworks is present"; \
	  echo "  next        make demo-validate, then make demo"; \
	else \
	  echo "  credential  ~/.cs-keys/fireworks is MISSING, and the demo needs it"; \
	  echo ""; \
	  echo "              mkdir -p ~/.cs-keys && chmod 700 ~/.cs-keys"; \
	  echo "              printf '%s' \"\$$FIREWORKS_API_KEY\" > ~/.cs-keys/fireworks"; \
	  echo "              chmod 600 ~/.cs-keys/fireworks"; \
	  echo ""; \
	  echo "  next        make demo-validate, then make demo"; \
	fi
	@echo ""

### tools: fetch the pinned use-mode binaries into tools/
tools:
	GOBIN=$(TOOLSDIR) go install github.com/codesweep-ai/campaign/cmd/cs-campaign@$(CAMPAIGN_VERSION)
	GOBIN=$(TOOLSDIR) go install github.com/codesweep-ai/campaign/cmd/cs-campaign-member@$(CAMPAIGN_VERSION)
	GOBIN=$(TOOLSDIR) go install github.com/codesweep-ai/campaign/dispatch-viewer/cmd/cs-dispatch-viewer@$(CAMPAIGN_VERSION)
	@sbx="$(SANDBOX_VERSION)"; \
	if [ -z "$$sbx" ]; then \
	  sbx="$$(curl -fsS $(CAMPAIGN_MOD) | awk '$$1=="github.com/codesweep-ai/sandbox"{print $$2}')"; \
	fi; \
	[ -n "$$sbx" ] || { echo "cannot determine the cs-sandbox $(CAMPAIGN_VERSION) names" >&2; exit 1; }; \
	echo "cs-sandbox $$sbx (named by campaign $(CAMPAIGN_VERSION))"; \
	GOBIN=$(TOOLSDIR) go install github.com/codesweep-ai/sandbox/cmd/cs-sandbox@$$sbx
	@for t in tracer vcr; do \
	  v="$$(curl -fsS $(CAMPAIGN_MOD) | awk -v m="github.com/codesweep-ai/$$t" '$$1==m{print $$2}')"; \
	  [ -n "$$v" ] || { echo "cannot determine the cs-$$t $(CAMPAIGN_VERSION) names" >&2; exit 1; }; \
	  echo "cs-$$t $$v"; \
	  GOBIN=$(TOOLSDIR) go install github.com/codesweep-ai/$$t/cmd/cs-$$t@$$v; \
	done
	PATH="$(TOOLSDIR):$$PATH" $(SANDBOX) install-agent-tools $(TOOLSDIR)

## doctor: prove cs-campaign and the sandbox it needs agree with the pins
doctor:
	$(CAMPAIGN) doctor

## check: everything that must pass before a commit
check: lint ledger no-local-paths

### lint: the two linters that read the tree and nothing else
lint:
	$(CS_LINT) prose
	$(CS_LINT) refs

### ledger: validate the records and prove ledger.html is current
ledger:
	$(CS_LEDGER) check $(LEDGER_DIR)

### ledger-render: rewrite ledger.html, then validate it
ledger-render:
	$(CS_LEDGER) render $(LEDGER_DIR)
	$(CS_LEDGER) check $(LEDGER_DIR)

### no-local-paths: refuse any absolute path from this machine in a committed file
no-local-paths:
	@bad=$$(git ls-files --cached --others --exclude-standard 2>/dev/null \
	  | grep -vE '^(node_modules|tools|\.work)/' \
	  | xargs -r grep -lE '/home/[a-z]|/Users/[a-z]' 2>/dev/null); \
	if [ -n "$$bad" ]; then \
	  echo "these files carry an absolute path from this machine:" >&2; \
	  echo "$$bad" >&2; exit 1; \
	fi; \
	echo "no local paths in committable files"

## demo-validate: check the profile, the mission and the briefs, spending nothing
demo-validate: demo-profile
	$(CAMPAIGN) validate $(CAMPAIGN_WS)/profile.yaml

## demo: the whole cycle, ending with the app and both reports on a URL
demo: demo-start demo-wait demo-fetch demo-archive demo-dispatch-page demo-trajectories show-app
	@echo ""
	@echo "the app is on the URL above. For the reports:  make show-reports"
	@echo "when you are done:                             make demo-destroy"

### demo-start: create the campaign and dispatch the mission. THIS SPENDS.
##
## Destroy and create is the whole strategy. `create` is documented as resumable,
## and this does not resume it: a resumed create shows that resume works rather
## than that a clean create works. A readback that misses its fixed 15 minute
## bound fails the run, and ~/.cs-opencode-remote-logs says why.
demo-start: demo-preflight
	@$(MAKE) --no-print-directory demo-reset
	@$(MAKE) --no-print-directory demo-validate
	$(CAMPAIGN) create $(CAMPAIGN_NAME) --profile $(CAMPAIGN_WS)/profile.yaml

## demo-watch: follow progress and health until the run ends or breaks
##
## Reads the derived member states, the orchestrator's claims as they happen, and
## each member's agent log. That last one matters: a member that cannot reach its
## provider still reports node-working, so only its log shows the failure.
demo-watch:
	@CS_CAMPAIGN_BIN=$(TOOLSDIR)/cs-campaign PATH="$(TOOLSDIR):$$PATH" \
	  CS_SANDBOX_BIN=$(TOOLSDIR)/cs-sandbox \
	  ./scripts/campaign-watch $(CAMPAIGN_NAME)

## show-reports: serve the dispatch page and the trajectories, from the archive
##
## Both are self-contained HTML that opens from disk, so this exists only to reach
## them from another machine. It serves .work, which also exposes the archive and
## the harvested app: your own evidence on your own tailnet.
show-reports:
	@[ -f $(WORKDIR)/viewer.html ] || { echo "no dispatch page yet. Run: make demo-archive demo-dispatch-page" >&2; exit 1; }
	@if [ -f $(VIEW_PID) ]; then kill "$$(cat $(VIEW_PID))" 2>/dev/null; rm -f $(VIEW_PID); fi
	@ts="$$(tailscale ip -4 2>/dev/null | head -1)"; \
	[ -n "$$ts" ] || { echo "no Tailscale IPv4 address. Is tailscale up?" >&2; exit 1; }; \
	port="$$(python3 -c 'import socket;s=socket.socket();s.bind((str(),0));print(s.getsockname()[1]);s.close()')"; \
	( cd $(WORKDIR) && nohup python3 -m http.server "$$port" --bind "$$ts" >view.log 2>&1 & echo $$! >$(VIEW_PID) ); \
	echo ""; \
	echo "  dispatch page   http://$$ts:$$port/viewer.html"; \
	[ -f $(WORKDIR)/traces/site/index.html ] \
	  && echo "  trajectories    http://$$ts:$$port/traces/site/index.html"; \
	echo ""; \
	echo "stop serving with: make demo-stop"

### show-app: publish the running app from the orchestrator, on your Tailscale IP
##
## The member-side port is fixed, because the role briefs name it. The host side is
## whatever is free. The orchestrator's sandbox name comes from the LIVE campaign
## record, not from `plan`: a fresh plan recomputes an id from the current profile
## and repository, which drifts the moment the members commit.
show-app:
	@mkdir -p $(WORKDIR)
	@rec="$${CS_CAMPAIGN_STATE_DIR:-$$HOME/.config/cs-campaign/campaigns}/$(CAMPAIGN_NAME).json"; \
	[ -f "$$rec" ] || { echo "no live campaign $(CAMPAIGN_NAME)" >&2; exit 1; }; \
	ts="$$(tailscale ip -4 2>/dev/null | head -1)"; \
	[ -n "$$ts" ] || { echo "no Tailscale IPv4 address. Is tailscale up?" >&2; exit 1; }; \
	port="$$(python3 -c 'import socket;s=socket.socket();s.bind((str(),0));print(s.getsockname()[1]);s.close()')"; \
	sbx="$$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(next(m["sandbox"] for m in d["members"] if m["role"]=="orchestrator"))' "$$rec")"; \
	grp="$$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["group"])' "$$rec")"; \
	name="$$sbx.$$grp"; \
	$(SANDBOX) ls 2>/dev/null | awk -v g="$$grp" -v n="$$sbx" '$$1==g && $$2==n && $$3=="running"{f=1} END{exit !f}' \
	  || { echo "sandbox $$name is not running. Look with: $(SANDBOX) ls" >&2; exit 1; }; \
	$(CAMPAIGN) ssh $(CAMPAIGN_NAME)/orchestrator "ss -ltn 2>/dev/null | grep -q ':$(VM_PORT) '" \
	  || { echo "nothing is listening on port $(VM_PORT) inside the orchestrator." >&2; \
	       echo "The mission asks it to leave the application servable. It did not." >&2; exit 1; }; \
	nohup $(SANDBOX) forward "$$name" "$$port:$(VM_PORT)" --bind "$$ts" \
	  >$(WORKDIR)/forward.log 2>&1 & echo $$! >$(FORWARD_PID); \
	sleep 3; \
	if grep -qiE "no such sandbox|error" $(WORKDIR)/forward.log 2>/dev/null; then \
	  echo "forward failed:" >&2; cat $(WORKDIR)/forward.log >&2; exit 1; \
	fi; \
	echo ""; \
	echo "  the app         http://$$ts:$$port"; \
	echo ""

### demo-stop: stop serving, and leave the members running
demo-stop:
	-@if [ -f $(VIEW_PID) ]; then \
	  kill "$$(cat $(VIEW_PID))" 2>/dev/null && echo "stopped serving the reports"; \
	  rm -f $(VIEW_PID); \
	fi
	-@if [ -f $(FORWARD_PID) ]; then \
	  kill "$$(cat $(FORWARD_PID))" 2>/dev/null && echo "stopped forwarding the app"; \
	  rm -f $(FORWARD_PID); \
	fi
	@rec="$${CS_CAMPAIGN_STATE_DIR:-$$HOME/.config/cs-campaign/campaigns}/$(CAMPAIGN_NAME).json"; \
	if [ -f "$$rec" ]; then \
	  echo "the members are still running. Drop them with: make demo-destroy"; \
	else \
	  echo "nothing is serving, and no campaign is running"; \
	fi

### demo-destroy: stop serving, then destroy the members
##
## This does NOT archive. The cycle archives at the right moment, while the member
## channels and transcripts still exist and the audit can run beside them. Archiving
## again here would repeat that work and would depend on the profile still sitting
## where the campaign record says it does.
##
## It refuses when no archive exists, because a destroy without one loses the
## evidence for good. Run `make demo-archive` first, or FORCE=1 to accept the loss.
demo-destroy: demo-stop
	@rec="$${CS_CAMPAIGN_STATE_DIR:-$$HOME/.config/cs-campaign/campaigns}/$(CAMPAIGN_NAME).json"; \
	if [ -f "$$rec" ] && [ ! -f "$$(find $(WORKDIR)/archive -name campaign.json -print -quit 2>/dev/null)" ] && [ -z "$(FORCE)" ]; then \
	  echo "no archive for $(CAMPAIGN_NAME), so destroying now would lose the evidence." >&2; \
	  echo "Keep it with:  make demo-archive" >&2; \
	  echo "Or accept the loss with:  make demo-destroy FORCE=1" >&2; \
	  exit 1; \
	fi
	@rec="$${CS_CAMPAIGN_STATE_DIR:-$$HOME/.config/cs-campaign/campaigns}/$(CAMPAIGN_NAME).json"; \
	if [ ! -f "$$rec" ]; then \
	  echo "no $(CAMPAIGN_NAME) campaign to destroy"; \
	else \
	  $(CAMPAIGN) destroy $(CAMPAIGN_NAME) --force; \
	  echo "destroyed. The archive is still under $(WORKDIR)/archive"; \
	fi

### demo-preflight: refuse to spend unless the credential and the host are ready
demo-preflight:
	@[ -n "$$FIREWORKS_API_KEY" ] || { echo "FIREWORKS_API_KEY is not set" >&2; exit 1; }
	@[ -s "$$HOME/.cs-keys/fireworks" ] || { echo "$$HOME/.cs-keys/fireworks is missing or empty. Borrow mode lends a host file, so an environment variable alone cannot be lent." >&2; exit 1; }
	@$(CAMPAIGN) doctor >/dev/null 2>&1 || { echo "cs-campaign doctor is not green. Run: make doctor" >&2; exit 1; }
	@echo "preflight ok: key file present, doctor green"

### demo-profile: render the profile beside its mission and briefs, under .work
demo-profile: demo-preflight
	@mkdir -p $(CAMPAIGN_WS)/roles
	@sed -e 's|@REPO@|$(APP_REPO)|g' -e 's|@MODEL@|$(FW_MODEL)|g' \
	  $(CAMPAIGN_SRC)/profile.yaml.in > $(CAMPAIGN_WS)/profile.yaml
	@cp $(CAMPAIGN_SRC)/mission.md $(CAMPAIGN_WS)/mission.md
	@cp $(CAMPAIGN_SRC)/roles/*.md $(CAMPAIGN_WS)/roles/
	@echo "rendered $(CAMPAIGN_WS)/profile.yaml (repo $(APP_REPO))"

### demo-reset: destroy any previous run and clear what outlives it
##
## Three things survive a destroy and change what the next create does:
##
##   1. a campaign record of the same name;
##   2. an app repository holding earlier commits;
##   3. a recorded agent session id. The campaign id is the profile digest, so an
##      unchanged profile recreates the same session names, and the host still
##      holds the opencode session id from the previous run. The turn driver then
##      drives that dead id against a brand-new member, and every turn fails with
##      "TUI server does not know session". That one cost a day.
demo-reset:
	@rec="$${CS_CAMPAIGN_STATE_DIR:-$$HOME/.config/cs-campaign/campaigns}/$(CAMPAIGN_NAME).json"; \
	if [ -f "$$rec" ]; then \
	  echo "destroying the previous $(CAMPAIGN_NAME) campaign"; \
	  $(CAMPAIGN) destroy $(CAMPAIGN_NAME) --force || true; \
	else \
	  echo "no previous $(CAMPAIGN_NAME) campaign"; \
	fi
	@rm -f $$HOME/.cs-opencode-remote-sessions/$(CAMPAIGN_NAME)-* 2>/dev/null || true
	@rm -rf $$HOME/.cs-opencode-remote-locks/$(CAMPAIGN_NAME)-*.lock 2>/dev/null || true
	@rm -rf $(APP_REPO) $(CAMPAIGN_WS)
	@echo "reset: forgot recorded sessions, removed $(APP_REPO)"

### demo-wait: block until the orchestrator closes the mission
demo-wait:
	@deadline=$$(( $$(date +%s) + 7200 )); \
	while :; do \
	  if ! $(CAMPAIGN) observe $(CAMPAIGN_NAME) 2>/dev/null \
	      | sed 's/\x1b\[[0-9;]*m//g' | grep -qE '^[[:space:]]+orchestrator.*m1[[:space:]]+open'; then \
	    echo "the mission is closed"; \
	    $(CAMPAIGN) observe $(CAMPAIGN_NAME) 2>/dev/null | tail -20; \
	    break; \
	  fi; \
	  [ "$$(date +%s)" -lt "$$deadline" ] || { echo "still open after 7200s. Follow it with: make demo-watch" >&2; exit 1; }; \
	  echo "the mission is still open, looking again in 30s ..."; sleep 30; \
	done

### demo-fetch: harvest the orchestrator's branch into the host repository
##
## By design the orchestrator's branch is the delivery, and `fetch <campaign>` pulls
## exactly that one. Every member's own branch is preserved in the archive instead,
## under source-metadata, with its base, its commit and its full diff.
demo-fetch:
	$(CAMPAIGN) fetch $(CAMPAIGN_NAME)
	@echo "host repository: $(APP_REPO)"
	@git -C $(APP_REPO) --no-pager log --oneline --all | head -10 || true
	@n="$$(git -C $(APP_REPO) rev-list --all --count 2>/dev/null || echo 0)"; \
	if [ "$$n" -le 1 ]; then \
	  echo "the orchestrator branch is identical to its base, so the campaign" >&2; \
	  echo "delivered nothing, whatever it reported." >&2; \
	  exit 1; \
	fi; \
	echo "delivered: $$n commits on the orchestrator branch"

### demo-archive: collect the evidence while the members still exist
##
## The audit runs in the same pass, so this must happen before demo-destroy. Member
## channels, configs and transcripts live inside the sandboxes and go with them.
demo-archive:
	@rm -rf $(WORKDIR)/archive && mkdir -p $(WORKDIR)/archive
	$(CAMPAIGN) archive $(CAMPAIGN_NAME) --output $(WORKDIR)/archive
	@echo "INCOMPLETE markers, if any:"; find $(WORKDIR)/archive -name 'INCOMPLETE-*' -print | head || true

### demo-dispatch-page: build the campaign timeline page from the archive
demo-dispatch-page:
	@dir="$$(dirname "$$(find $(WORKDIR)/archive -name campaign.json -print -quit)")"; \
	[ -n "$$dir" ] && [ "$$dir" != "." ] || { echo "no archive found. Run: make demo-archive" >&2; exit 1; }; \
	$(TOOLSDIR)/cs-dispatch-viewer "$$dir" -o $(WORKDIR)/viewer.html; \
	echo "wrote $(WORKDIR)/viewer.html"

### demo-trajectories: build one trajectory site covering every member session
##
## The archive packs each member's agent-CLI session as transcript/cli-evidence.tgz,
## so each is unpacked under one tree and cs-tracer reads the lot in a single pass.
## `--split` is what gives an index: index.html, shared assets and a page per
## session, which is what a fleet wants rather than one file per member.
demo-trajectories:
	@root="$$(dirname "$$(find $(WORKDIR)/archive -name campaign.json -print -quit)")"; \
	[ -n "$$root" ] && [ "$$root" != "." ] || { echo "no archive found. Run: make demo-archive" >&2; exit 1; }; \
	rm -rf $(WORKDIR)/traces; mkdir -p $(WORKDIR)/traces/src; \
	n=0; \
	for tgz in "$$root"/orchestrator/transcript/cli-evidence.tgz "$$root"/agents/*/transcript/cli-evidence.tgz; do \
	  [ -f "$$tgz" ] || continue; \
	  m="$$(basename "$$(dirname "$$(dirname "$$tgz")")")"; \
	  mkdir -p "$(WORKDIR)/traces/src/$$m"; \
	  tar xzf "$$tgz" -C "$(WORKDIR)/traces/src/$$m" && n=$$((n+1)); \
	done; \
	[ "$$n" -gt 0 ] || { echo "no member transcripts in $$root" >&2; exit 1; }; \
	$(TOOLSDIR)/cs-tracer $(WORKDIR)/traces/src --split -o $(WORKDIR)/traces/site --force; \
	echo "unpacked $$n member transcript(s); index at $(WORKDIR)/traces/site/index.html"

## demo-clean: drop the members and delete the demo's artefacts
##
## This is the discard path, so it does not protect the archive the way demo-destroy
## does. A campaign's channels and transcripts exist only while its members do, so
## the archive is the only copy once they are gone, and this deletes it.
##
## It also forgets the recorded agent sessions on this host, which is what lets the
## next demo-start begin cleanly. It leaves ~/.cs-keys/fireworks alone, because that
## credential is yours rather than this repository's state.
demo-clean: demo-stop
	@rec="$${CS_CAMPAIGN_STATE_DIR:-$$HOME/.config/cs-campaign/campaigns}/$(CAMPAIGN_NAME).json"; \
	if [ -f "$$rec" ]; then \
	  $(CAMPAIGN) destroy $(CAMPAIGN_NAME) --force; \
	else \
	  echo "no $(CAMPAIGN_NAME) campaign to destroy"; \
	fi
	@rm -rf $(WORKDIR)
	@rm -f $$HOME/.cs-opencode-remote-sessions/$(CAMPAIGN_NAME)-* 2>/dev/null || true
	@rm -rf $$HOME/.cs-opencode-remote-locks/$(CAMPAIGN_NAME)-*.lock 2>/dev/null || true
	@echo "removed $(WORKDIR) and forgot any recorded $(CAMPAIGN_NAME) sessions"
	@echo "the credential at ~/.cs-keys/fireworks is untouched"

### clean: remove the fetched use-mode binaries, rebuilt by `make tools`
clean:
	rm -rf $(TOOLSDIR)

## clean-all: also remove the npm dev-mode tools, rebuilt by `npm install`
clean-all: clean
	rm -rf $(CURDIR)/node_modules

