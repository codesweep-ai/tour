# tour
#
# A tour of the codesweep tools, from the smallest to the largest. Every recipe runs
# its tool through scripts/cs, which prints the command and then runs exactly that, so
# what you read on the screen is what you would type in a project of your own.
#
# The tools come from two places, and both are pinned.
#
#   npm   cs-lint, cs-ledger and the opencode agent. Pinned in package.json and
#         package-lock.json, and run from node_modules/.bin.
#   Go    cs-campaign, cs-sandbox, cs-tracer, cs-vcr and cs-dispatch-viewer. None has
#         an npm package or a tagged release, so `make setup` installs them from the
#         Go module proxy into tools/. That needs a Go toolchain.

# CAMPAIGN_VERSION is the only version to choose. The cs-sandbox, cs-tracer and
# cs-vcr it needs are derived from that campaign's own go.mod on the module proxy,
# so the chain cannot drift apart here. Set SANDBOX_VERSION to override.
CAMPAIGN_VERSION ?= v0.0.0-20260921013337-3ac5613baf20
SANDBOX_VERSION  ?=
TOOLSDIR         := $(abspath tools)
CAMPAIGN_MOD     := https://proxy.golang.org/github.com/codesweep-ai/campaign/@v/$(CAMPAIGN_VERSION).mod

# CS runs one pinned tool and prints the command first. CSQ does the same in silence,
# for the places where a recipe reads the output itself.
# Where the app and the reports are served. It is your Tailscale address when Tailscale is
# up, so another machine of yours can open them, and 127.0.0.1 when it is not. Set BIND_ADDR
# to choose an address yourself. Nothing here ever binds to every interface.
BIND = a="$${BIND_ADDR:-$$(tailscale ip -4 2>/dev/null | head -1)}"; [ -n "$$a" ] || a=127.0.0.1; echo "$$a"

CS  := $(CURDIR)/scripts/cs
CSQ := CS_QUIET=1 $(CURDIR)/scripts/cs

# The campaign's name carries four digits taken from this clone's path. cs-campaign keeps
# its records per user and not per clone, so two clones that both said `hello` would read,
# replace and destroy each other's campaign.
CAMPAIGN_NAME ?= hello$(shell printf '%s' "$(CURDIR)" | cksum | cut -c1-4)
CAMPAIGN_SRC  := $(CURDIR)/campaign/hello
WORKDIR       := $(CURDIR)/.work
CAMPAIGN_WS   := $(WORKDIR)/$(CAMPAIGN_NAME)
APP_REPO      := $(WORKDIR)/hello-app
ARCHIVE       := $(WORKDIR)/archive
REPORTS       := $(WORKDIR)/reports
FW_MODEL      ?= fireworks-ai/accounts/fireworks/models/kimi-k2p7-code
VM_PORT       ?= 5173
FORWARD_PID   := $(WORKDIR)/forward.pid
VIEW_PID      := $(WORKDIR)/view.pid
RECORD        := $${CS_CAMPAIGN_STATE_DIR:-$$HOME/.config/cs-campaign/campaigns}/$(CAMPAIGN_NAME).json

.DEFAULT_GOAL := help

.PHONY: help help-all setup tools doctor env check test ci prose refs oss actionlint clean clean-all \
        try-tracer try-lint try-ledger try-vcr try-sandbox vcr-record \
        demo-replay demo-record no-identity \
        demo demo-start demo-watch demo-stop demo-destroy demo-clean show-reports show-app \
        lint ledger ledger-render cassettes no-local-paths no-session-links \
        demo-preflight demo-profile demo-validate demo-reset demo-wait \
        demo-fetch demo-archive demo-dispatch-page demo-trajectories

## help: the tour, in the order to take it
help:
	@echo ""
	@echo "  tour: the codesweep tools, from the smallest to the largest"
	@echo ""
	@echo "  first                     make setup"
	@echo ""
	@echo "  five minutes, no key, nothing spent"
	@echo "    make try-tracer         cs-tracer   draw one of your own agent sessions as a page"
	@echo "    make try-lint           cs-lint     watch it pass, then catch three planted faults"
	@echo "    make try-ledger         cs-ledger   read this repo's ledger, file and close a record"
	@echo "    make try-vcr            cs-vcr      replay a recorded agent run, with no key at all"
	@echo "    make try-sandbox        cs-sandbox  create, work, fetch, destroy   (needs podman and KVM)"
	@echo ""
	@echo "  seven more minutes, still no key, still nothing spent"
	@echo "    make demo-replay        cs-campaign three real agents run a whole campaign, from a recording"
	@echo ""
	@echo "  about ten minutes, a Fireworks key on disk, about a dollar"
	@echo "    make demo-validate      cs-campaign check the campaign before it costs anything"
	@echo "    make demo               the same campaign live   (in a second terminal: make demo-watch)"
	@echo "    make show-reports       read the dispatch page and the trajectories"
	@echo "    make demo-destroy       drop the members, and keep the archive"
	@echo ""
	@echo "  start over                make demo-clean   (deletes the archive too)"
	@echo ""
	@echo "  in any step's output      a line that starts with \$$ is the tool command that step just ran"
	@echo "  run a tool yourself       eval \"\$$(make env)\"   then type its name"
	@echo "  every target              make help-all"
	@echo ""

## help-all: every target, with a line on each
help-all:
	@echo ""
	@echo "  commands"
	@echo ""
	@grep -hE '^## [a-z][a-z-]*:' $(MAKEFILE_LIST) | sed 's/^## //' \
	  | awk -F': ' '{printf "  %-16s %s\n", $$1, substr($$0, index($$0,": ")+2)}'
	@echo ""
	@echo "  stages"
	@echo ""
	@grep -hE '^### [a-z][a-z-]*:' $(MAKEFILE_LIST) | sed 's/^### //' \
	  | awk -F': ' '{printf "  %-20s %s\n", $$1, substr($$0, index($$0,": ")+2)}'
	@echo ""

## setup: install both sets of tools, prove the chain, and name what is missing
##
## The tools are only half of what the campaign needs. It lends a Fireworks key from
## a host file, so this ends by saying whether that file is there. Lending reads a file
## rather than an environment variable, which is why an exported key is not enough.
## The five `try-` targets need no key at all.
setup:
	npm install
	@$(MAKE) --no-print-directory tools
	@$(MAKE) --no-print-directory doctor
	@echo ""
	@echo "  next        make try-tracer, and on down the list that \`make\` prints"
	@if [ -s "$$HOME/.cs-keys/fireworks" ]; then \
	  echo "  credential  ~/.cs-keys/fireworks is present, which the campaign needs"; \
	else \
	  echo "  credential  ~/.cs-keys/fireworks is missing. Only the campaign needs it:"; \
	  echo ""; \
	  echo "              mkdir -p ~/.cs-keys && chmod 700 ~/.cs-keys"; \
	  echo "              printf '%s' \"\$$FIREWORKS_API_KEY\" > ~/.cs-keys/fireworks"; \
	  echo "              chmod 600 ~/.cs-keys/fireworks"; \
	fi
	@echo ""

### tools: fetch the pinned Go binaries into tools/
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
	@# The campaign replay runs cs-vcr in a container built from nothing but a static
	@# base, so that copy is linked without cgo. It is the same pinned version.
	@v="$$(curl -fsS $(CAMPAIGN_MOD) | awk '$$1=="github.com/codesweep-ai/vcr"{print $$2}')"; \
	CGO_ENABLED=0 GOBIN=$(TOOLSDIR)/static go install github.com/codesweep-ai/vcr/cmd/cs-vcr@$$v
	$(CS) cs-sandbox install-agent-tools $(TOOLSDIR)

## doctor: prove cs-campaign and the sandbox it needs agree with the pins
doctor:
	@$(CS) cs-campaign doctor

## env: print the settings that put the pinned tools on your PATH
##
## Use it as `eval "$(make env)"`. After that a bare tool name in this shell means the
## pinned copy, so any command a target printed can be typed again by hand. These are
## the same three settings scripts/cs applies.
env:
	@echo 'export PATH="$(TOOLSDIR):$(CURDIR)/node_modules/.bin:$$PATH"'
	@echo 'export CS_SANDBOX_BIN="$(TOOLSDIR)/cs-sandbox"'
	@echo 'export CS_CAMPAIGN_GUEST_BIN="$(TOOLSDIR)/cs-campaign-member"'

## try-tracer: draw one of your own agent sessions as a page
try-tracer:
	@./scripts/try-tracer

## try-lint: watch cs-lint pass here, then catch three planted faults
try-lint:
	@./scripts/try-lint

## try-ledger: read this repo's ledger, then file and close a record in a copy
try-ledger:
	@./scripts/try-ledger

## try-vcr: replay a recorded agent run, with no key and no provider call
try-vcr:
	@./scripts/vcr-agent replay

## try-sandbox: create one sandbox, work in it, fetch the work out, destroy it
try-sandbox:
	@./scripts/try-sandbox

### vcr-record: record cassettes/hello again. Calls Fireworks, for about two cents.
##
## Do this after changing the opencode pin in package.json, because another version of
## the agent sends another prompt and the old cassette stops matching. The scrub that
## follows looks for keys and addresses, and exits non-zero while any are left.
vcr-record:
	@./scripts/vcr-agent record
	@CS_VCR_CASSETTES=$(CURDIR)/cassettes $(CS) cs-vcr cassette scrub hello --from-env FIREWORKS_API_KEY

## check: everything that must pass before a commit
check: prose refs oss actionlint ledger cassettes no-local-paths no-identity no-session-links

## test: the tour steps that check themselves and boot no machine
##
## Each one fails when the tool stops behaving as the tour says. None needs a key, and
## `try-vcr` runs a whole agent loop against the committed cassette for nothing.
test: try-lint try-ledger try-vcr

## ci: every gate the CI workflow runs, in the order it runs them
##
## It starts with `setup`, so that the one command is enough on a fresh clone. A second
## run is quick, because the Go and npm caches already hold every pinned tool.
ci: setup check test

### lint: the three linters that need no build
lint: prose refs oss

### prose: how the documents and the ledger records are written
prose:
	@$(CS) cs-lint prose

### refs: whether everything the documents point at exists
refs:
	@$(CS) cs-lint refs

### oss: whether this repository has what a published one owes a reader
oss:
	@$(CS) cs-lint oss

### actionlint: whether the CI workflow is one the forge will accept
##
## This repository has no go.mod to pin a Go tool in, so the version is pinned here.
ACTIONLINT_VERSION ?= v1.7.12
actionlint:
	@echo ""; echo "  $$ actionlint"; echo ""
	@go run github.com/rhysd/actionlint/cmd/actionlint@$(ACTIONLINT_VERSION)

### ledger: validate the records and prove ledger.html is current
ledger:
	@$(CS) cs-ledger check ledger

### ledger-render: rewrite ledger.html, then validate it
ledger-render:
	@$(CS) cs-ledger render ledger
	@$(CS) cs-ledger check ledger

### cassettes: prove every committed cassette still matches this cs-vcr, and this campaign
##
## A cassette is keyed by cs-vcr's ruleset, which `verify` checks. The campaign's cassettes
## are also bound to what the agents were asked. An edit to the mission, a brief, the
## profile or the pinned version changes the prompts, and the recording stops matching.
## The recording stores a hash of those, and this compares it.
cassettes:
	@CS_VCR_CASSETTES=$(CURDIR)/cassettes $(CS) cs-vcr cassette verify
	@if [ -f cassettes/campaign.json ]; then \
	  want="$$(python3 -c 'import json;print(json.load(open("cassettes/campaign.json"))["campaign_digest"])')"; \
	  have="$$(./scripts/campaign-digest)"; \
	  if [ "$$want" != "$$have" ]; then \
	    echo "the campaign cassettes are stale: the mission, a brief, the profile or the pinned" >&2; \
	    echo "version changed after they were recorded. Record them again with: make demo-record" >&2; \
	    exit 1; \
	  fi; \
	  echo "the campaign cassettes match the campaign they were recorded from"; \
	fi

### no-identity: refuse anything of yours in a file git would commit
##
## It looks for this machine's own username, git name, git address and hostname, as whole
## words, in every tracked and untracked file that is not ignored. A cassette is the file
## most likely to hold one, because a member carries a copy of the host's git identity.
## It prints file names and never the values.
##
## A generic account name is skipped, because `runner`, `dev` or `ubuntu` is also an
## ordinary word that these documents use. CI is skipped for the same reason: the account
## there belongs to nobody.
no-identity:
	@if [ -n "$$CI" ]; then echo "no-identity: skipped on CI, where the account belongs to nobody"; exit 0; fi; \
	bad=""; for v in "$$(id -un)" "$$(git config --global user.name)" "$$(git config --global user.email)" "$$(hostname)"; do \
	  [ -n "$$v" ] || continue; \
	  case "$$v" in root|user|admin|ubuntu|debian|fedora|runner|dev|developer|test|vagrant|codespace|ec2-user|localhost) continue ;; esac; \
	  hit="$$(git ls-files --cached --others --exclude-standard | grep -vE '^(node_modules|tools|\.work)/' | xargs -r grep -lwF -- "$$v" 2>/dev/null | head -5)"; \
	  [ -n "$$hit" ] && bad="$$bad$$hit\n"; \
	done; \
	if [ -n "$$bad" ]; then \
	  echo "these files hold your username, your git identity or this machine's name:" >&2; \
	  printf "$$bad" | sort -u >&2; exit 1; \
	fi; \
	echo "nothing of yours in committable files"

### no-session-links: refuse an agent session link in any commit message
##
## A session link is private to whoever ran it, it is useless to everyone else, and it
## cannot be taken out once the history is public. This repository is meant to be
## published, so the guard runs inside `make check` rather than living in a convention
## nobody reads.
no-session-links:
	@bad=$$(git log --all --format='%H' 2>/dev/null | while read -r c; do \
	  git log -1 --format='%B' "$$c" 2>/dev/null \
	    | grep -qiE 'claude-session|claude\.ai/code/session' && echo "$$c"; \
	done); \
	if [ -n "$$bad" ]; then \
	  echo "these commits carry an agent session link, which must not be published:" >&2; \
	  echo "$$bad" >&2; \
	  exit 1; \
	fi; \
	echo "no session links in commit messages"

### no-local-paths: refuse any absolute path from this machine in a committed file
##
## `/Users/name` is let through, and nothing else is. It is the example path in the
## agent's own tool description, so every cassette carries it.
no-local-paths:
	@bad=$$(git ls-files --cached --others --exclude-standard 2>/dev/null \
	  | grep -vE '^(node_modules|tools|\.work)/' \
	  | while read -r f; do \
	      grep -ohE '(/home|/Users)/[a-z][A-Za-z0-9_-]*' "$$f" 2>/dev/null \
	        | grep -vx '/Users/name' | grep -q . && echo "$$f"; \
	    done); \
	if [ -n "$$bad" ]; then \
	  echo "these files carry an absolute path from this machine:" >&2; \
	  echo "$$bad" >&2; exit 1; \
	fi; \
	echo "no local paths in committable files"

## demo-replay: three real agents run the whole campaign from a recording. No key, no spend.
##
## It boots the same three machines as `make demo`, and the agents run every command they
## ran when it was recorded: the installs, the build, the browser check and the server. Only
## the model is a recording, served by cs-vcr, so the page you open was built here a minute
## ago. It ends the way the live run does, with the app, the dispatch page and the
## trajectories.
demo-replay:
	@CAMPAIGN_NAME=$(CAMPAIGN_NAME) ./scripts/campaign-vcr replay

### demo-record: record the campaign again. Calls Fireworks, for about a dollar.
##
## Do this after any change to the mission, a brief, the profile or CAMPAIGN_VERSION, which
## `make check` reports as stale cassettes. A recording is kept only when it holds nothing
## of yours: the step searches it for your username, git identity, hostname and key, runs
## the cs-vcr scrubber, and moves a recording that fails into .work. Replay it twice
## before you commit it, because each recording holds different decisions.
demo-record:
	@CAMPAIGN_NAME=$(CAMPAIGN_NAME) ./scripts/campaign-vcr record

## demo-validate: check the profile, the mission and the briefs, spending nothing
demo-validate: demo-profile
	@$(CS) cs-campaign validate $(CAMPAIGN_WS)/profile.yaml

## demo: the whole cycle, ending with the app and both reports on a URL
demo: demo-start demo-wait demo-fetch demo-archive demo-dispatch-page demo-trajectories show-app
	@echo ""
	@echo "the app is on the URL above, served from inside the orchestrator."
	@echo "the reports open from disk, with no server behind them:"
	@echo "  dispatch page   file://$(REPORTS)/viewer.html"
	@echo "  trajectories    file://$(REPORTS)/traces/index.html"
	@echo "to reach them from another machine:   make show-reports"
	@echo "when you are done:                    make demo-destroy"

### demo-start: create the campaign and dispatch the mission. THIS SPENDS.
##
## Destroy and create is the whole strategy. `create` is documented as resumable,
## and this does not resume it: a resumed create shows that resume works rather
## than that a clean create works. A readback that misses its fixed 15 minute
## bound fails the run, and ~/.cs-opencode-remote-logs says why.
demo-start: demo-preflight
	@$(MAKE) --no-print-directory demo-reset
	@$(MAKE) --no-print-directory demo-validate
	@$(CS) cs-campaign create $(CAMPAIGN_NAME) --profile $(CAMPAIGN_WS)/profile.yaml

## demo-watch: follow progress and health until the run ends or breaks
##
## Reads the derived member states, the orchestrator's claims as they happen, and
## each member's agent log. That last one matters: a member that cannot reach its
## provider still reports node-working, so only its log shows the failure.
demo-watch:
	@PATH="$(TOOLSDIR):$(CURDIR)/node_modules/.bin:$$PATH" \
	  CS_SANDBOX_BIN=$(TOOLSDIR)/cs-sandbox CS_CAMPAIGN_BIN=$(TOOLSDIR)/cs-campaign \
	  ./scripts/campaign-watch $(CAMPAIGN_NAME)

## show-reports: serve the dispatch page and the trajectories, on Tailscale or on 127.0.0.1
##
## Both are self-contained HTML that opens from disk, so this exists only to reach
## them from another machine. It serves .work/reports and nothing else. The archive,
## the harvested app and any page `make try-tracer` drew of your own sessions stay
## off the network.
show-reports:
	@[ -f $(REPORTS)/viewer.html ] || { echo "no dispatch page yet. Run: make demo-archive demo-dispatch-page" >&2; exit 1; }
	@rec="$$(find $(ARCHIVE) -name campaign.json -print -quit 2>/dev/null)"; \
	for page in $(REPORTS)/viewer.html $(REPORTS)/traces/index.html; do \
	  [ -f "$$page" ] || continue; \
	  if [ -z "$$rec" ] || [ "$$page" -ot "$$rec" ]; then \
	    echo "$$page is older than the archive, so it describes an earlier one." >&2; \
	    echo "Rebuild with: make demo-dispatch-page demo-trajectories" >&2; exit 1; \
	  fi; \
	done
	@if [ -f $(VIEW_PID) ]; then kill "$$(cat $(VIEW_PID))" 2>/dev/null; rm -f $(VIEW_PID); fi
	@ts="$$($(BIND))"; \
	[ "$$ts" != 127.0.0.1 ] || echo "Tailscale is not up, so the reports are served on this machine only."; \
	port="$$(python3 -c 'import socket;s=socket.socket();s.bind((str(),0));print(s.getsockname()[1]);s.close()')"; \
	( cd $(REPORTS) && nohup python3 -m http.server "$$port" --bind "$$ts" >$(WORKDIR)/view.log 2>&1 & echo $$! >$(VIEW_PID) ); \
	echo ""; \
	echo "  dispatch page   http://$$ts:$$port/viewer.html"; \
	[ -f $(REPORTS)/traces/index.html ] \
	  && echo "  trajectories    http://$$ts:$$port/traces/index.html"; \
	echo ""; \
	echo "stop serving with: make demo-stop"

### show-app: publish the running app from the orchestrator, on Tailscale or on 127.0.0.1
##
## The member-side port is fixed, because the role briefs name it. The host side is
## whatever is free. The orchestrator's sandbox name comes from the LIVE campaign
## record, not from `plan`: a fresh plan recomputes an id from the current profile
## and repository, which drifts the moment the members commit.
show-app:
	@mkdir -p $(WORKDIR)
	@rec="$(RECORD)"; \
	[ -f "$$rec" ] || { echo "no live campaign $(CAMPAIGN_NAME)" >&2; exit 1; }; \
	ts="$$($(BIND))"; \
	[ "$$ts" != 127.0.0.1 ] || echo "Tailscale is not up, so the app is served on this machine only."; \
	port="$$(python3 -c 'import socket;s=socket.socket();s.bind((str(),0));print(s.getsockname()[1]);s.close()')"; \
	sbx="$$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(next(m["sandbox"] for m in d["members"] if m["role"]=="orchestrator"))' "$$rec")"; \
	grp="$$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["group"])' "$$rec")"; \
	name="$$sbx.$$grp"; \
	$(CSQ) cs-sandbox ls 2>/dev/null | awk -v g="$$grp" -v n="$$sbx" '$$1==g && $$2==n && $$3=="running"{f=1} END{exit !f}' \
	  || { echo "sandbox $$name is not running. Look with: scripts/cs cs-sandbox ls" >&2; exit 1; }; \
	$(CSQ) cs-campaign ssh $(CAMPAIGN_NAME)/orchestrator "ss -ltn 2>/dev/null | grep -q ':$(VM_PORT) '" \
	  || { echo "nothing is listening on port $(VM_PORT) inside the orchestrator." >&2; \
	       echo "The mission asks it to leave the application servable. It did not." >&2; exit 1; }; \
	nohup $(CS) cs-sandbox forward "$$name" "$$port:$(VM_PORT)" --bind "$$ts" \
	  >$(WORKDIR)/forward.log 2>&1 & echo $$! >$(FORWARD_PID); \
	sleep 3; \
	sed -n '/^  \$$/p' $(WORKDIR)/forward.log; \
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
	@if [ -n "$(filter demo-destroy demo-clean demo-reset,$(MAKECMDGOALS))" ]; then \
	  true; \
	elif [ -f "$(RECORD)" ]; then \
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
	@if [ -f "$(RECORD)" ] && [ ! -f "$$(find $(ARCHIVE) -name campaign.json -print -quit 2>/dev/null)" ] && [ -z "$(FORCE)" ]; then \
	  echo "no archive for $(CAMPAIGN_NAME), so destroying now would lose the evidence." >&2; \
	  echo "Keep it with:  make demo-archive" >&2; \
	  echo "Or accept the loss with:  make demo-destroy FORCE=1" >&2; \
	  exit 1; \
	fi
	@if [ ! -f "$(RECORD)" ]; then \
	  echo "no $(CAMPAIGN_NAME) campaign to destroy"; \
	else \
	  $(CS) cs-campaign destroy $(CAMPAIGN_NAME) --force; \
	  echo "destroyed. The archive is still under $(ARCHIVE)"; \
	fi

### demo-preflight: refuse to spend unless the credential and the host are ready
demo-preflight:
	@[ -s "$$HOME/.cs-keys/fireworks" ] || { echo "$$HOME/.cs-keys/fireworks is missing or empty. Borrow mode lends a host file, so an environment variable alone cannot be lent." >&2; exit 1; }
	@$(CSQ) cs-campaign doctor >/dev/null 2>&1 || { echo "cs-campaign doctor is not green. Run: make doctor" >&2; exit 1; }
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
##
## The previous run's archive and reports are moved aside into .work/runs/<time>,
## and whatever was serving them is stopped. Left in place they would be served as
## if they belonged to the new run, and a stale archive would satisfy the guard in
## demo-destroy on behalf of a run that has none.
demo-reset: demo-stop
	@if [ -f "$(RECORD)" ]; then \
	  owner="$$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("profilePath",""))' "$(RECORD)")"; \
	  case "$$owner" in "$(CURDIR)"/*|"") ;; *) \
	    echo "a campaign called $(CAMPAIGN_NAME) is already running from another directory:" >&2; \
	    echo "  $$owner" >&2; \
	    echo "It is not this clone's to destroy. Destroy it from there, or choose another name:" >&2; \
	    echo "  make $(MAKECMDGOALS) CAMPAIGN_NAME=another-name" >&2; exit 1 ;; esac; \
	  echo "destroying the previous $(CAMPAIGN_NAME) campaign"; \
	  $(CS) cs-campaign destroy $(CAMPAIGN_NAME) --force || true; \
	else \
	  echo "no previous $(CAMPAIGN_NAME) campaign"; \
	fi
	@rm -f $$HOME/.cs-opencode-remote-sessions/$(CAMPAIGN_NAME)-* 2>/dev/null || true
	@rm -rf $$HOME/.cs-opencode-remote-locks/$(CAMPAIGN_NAME)-*.lock 2>/dev/null || true
	@rm -rf $(APP_REPO) $(CAMPAIGN_WS)
	@if [ -e $(ARCHIVE) ] || [ -e $(REPORTS) ]; then \
	  old="$(WORKDIR)/runs/$$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$$old"; \
	  for d in $(ARCHIVE) $(REPORTS); do \
	    [ -e "$$d" ] && mv "$$d" "$$old/"; \
	  done; \
	  echo "reset: moved the previous run's archive and reports to $$old"; \
	fi
	@echo "reset: forgot recorded sessions, removed $(APP_REPO)"

### demo-wait: block until the orchestrator closes the mission
demo-wait:
	@echo ""; echo "  waiting on:  cs-campaign observe $(CAMPAIGN_NAME)"; echo ""
	@deadline=$$(( $$(date +%s) + 7200 )); \
	while :; do \
	  if ! $(CSQ) cs-campaign observe $(CAMPAIGN_NAME) 2>/dev/null \
	      | sed 's/\x1b\[[0-9;]*m//g' | grep -qE '^[[:space:]]+orchestrator.*m1[[:space:]]+open'; then \
	    echo "the mission is closed"; \
	    $(CS) cs-campaign observe $(CAMPAIGN_NAME) 2>&1 | tail -22; \
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
	@$(CS) cs-campaign fetch $(CAMPAIGN_NAME)
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
	@rm -rf $(ARCHIVE) && mkdir -p $(ARCHIVE)
	@$(CS) cs-campaign archive $(CAMPAIGN_NAME) --output $(ARCHIVE)
	@echo "INCOMPLETE markers, if any:"; find $(ARCHIVE) -name 'INCOMPLETE-*' -print | head || true

### demo-dispatch-page: build the campaign timeline page from the archive
demo-dispatch-page:
	@dir="$$(dirname "$$(find $(ARCHIVE) -name campaign.json -print -quit)")"; \
	[ -n "$$dir" ] && [ "$$dir" != "." ] || { echo "no archive found. Run: make demo-archive" >&2; exit 1; }; \
	mkdir -p $(REPORTS); \
	$(CS) cs-dispatch-viewer "$$dir" -o $(REPORTS)/viewer.html || exit 1; \
	echo "wrote $(REPORTS)/viewer.html"

### demo-trajectories: build a trajectory site per member, under one index
##
## The archive packs each member's agent-CLI session as transcript/cli-evidence.tgz.
## cs-tracer titles a session by what the agent called it, which is the dispatch and
## never the member, so one site over every member cannot say whose session is whose.
## Each member therefore gets its own site, and the index above them names the member.
demo-trajectories:
	@root="$$(dirname "$$(find $(ARCHIVE) -name campaign.json -print -quit)")"; \
	[ -n "$$root" ] && [ "$$root" != "." ] || { echo "no archive found. Run: make demo-archive" >&2; exit 1; }; \
	rm -rf $(WORKDIR)/traces-src $(REPORTS)/traces; mkdir -p $(WORKDIR)/traces-src $(REPORTS)/traces; \
	n=0; rows=""; \
	for tgz in "$$root"/orchestrator/transcript/cli-evidence.tgz "$$root"/agents/*/transcript/cli-evidence.tgz; do \
	  [ -f "$$tgz" ] || continue; \
	  m="$$(basename "$$(dirname "$$(dirname "$$tgz")")")"; \
	  mkdir -p "$(WORKDIR)/traces-src/$$m"; \
	  tar xzf "$$tgz" -C "$(WORKDIR)/traces-src/$$m" \
	    || { echo "cannot unpack the $$m transcript" >&2; exit 1; }; \
	  $(CS) cs-tracer "$(WORKDIR)/traces-src/$$m" --split -o "$(REPORTS)/traces/$$m" --force \
	    || { echo "cs-tracer failed on the $$m transcript" >&2; exit 1; }; \
	  rows="$$rows<li><a href=\"$$m/index.html\">$$m</a></li>"; n=$$((n+1)); \
	done; \
	[ "$$n" -gt 0 ] || { echo "no member transcripts in $$root" >&2; exit 1; }; \
	printf '<!doctype html>\n<meta charset="utf-8">\n<title>%s trajectories</title>\n<body style="font:16px system-ui;margin:2rem">\n<h1>%s trajectories, by member</h1>\n<ul>%s</ul>\n' \
	  "$(CAMPAIGN_NAME)" "$(CAMPAIGN_NAME)" "$$rows" > $(REPORTS)/traces/index.html; \
	echo "built $$n member site(s); index at $(REPORTS)/traces/index.html"

## demo-clean: drop the members and delete the demo's artefacts
##
## This is the discard path, so it does not protect the archive the way demo-destroy
## does. A campaign's channels and transcripts exist only while its members do, so
## the archive is the only copy once they are gone, and this deletes it. It deletes
## what the `try-` targets left in .work too.
##
## It also forgets the recorded agent sessions on this host, which is what lets the
## next demo-start begin cleanly. It leaves ~/.cs-keys/fireworks alone, because that
## credential is yours rather than this repository's state.
demo-clean: demo-stop
	@if [ -f "$(RECORD)" ]; then \
	  $(CS) cs-campaign destroy $(CAMPAIGN_NAME) --force; \
	else \
	  echo "no $(CAMPAIGN_NAME) campaign to destroy"; \
	fi
	@rm -rf $(WORKDIR)
	@rm -f $$HOME/.cs-opencode-remote-sessions/$(CAMPAIGN_NAME)-* 2>/dev/null || true
	@rm -rf $$HOME/.cs-opencode-remote-locks/$(CAMPAIGN_NAME)-*.lock 2>/dev/null || true
	@echo "removed $(WORKDIR) and forgot any recorded $(CAMPAIGN_NAME) sessions"
	@echo "the credential at ~/.cs-keys/fireworks is untouched"

### clean: remove the fetched Go binaries, rebuilt by `make tools`
clean:
	rm -rf $(TOOLSDIR)

## clean-all: also remove the npm tools, rebuilt by `npm install`
clean-all: clean
	rm -rf $(CURDIR)/node_modules
