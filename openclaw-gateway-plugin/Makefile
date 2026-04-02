PLUGIN_ID   := lifelog-gateway
DIST_DIR    := dist
EXT_DIR     := $(HOME)/.openclaw/extensions/$(PLUGIN_ID)
CONFIG_FILE := $(HOME)/.openclaw/openclaw.json
SCRIPTS_DIR := scripts

.PHONY: all build clean install uninstall restart register verify

all: build

# --- Build ---

build: node_modules
	npx tsc

node_modules: package.json
	npm install
	@touch $@

clean:
	rm -rf $(DIST_DIR)

# --- Install into OpenClaw ---

install: build register restart
	@echo "=== $(PLUGIN_ID) installed ==="

register:
	@mkdir -p "$(EXT_DIR)/src" "$(EXT_DIR)/scripts"
	cp $(DIST_DIR)/index.js $(DIST_DIR)/index.js.map          "$(EXT_DIR)/"
	cp $(DIST_DIR)/index.d.ts $(DIST_DIR)/index.d.ts.map      "$(EXT_DIR)/"
	cp $(DIST_DIR)/src/*.js $(DIST_DIR)/src/*.js.map           "$(EXT_DIR)/src/"
	cp $(DIST_DIR)/src/*.d.ts $(DIST_DIR)/src/*.d.ts.map       "$(EXT_DIR)/src/"
	cp package.json openclaw.plugin.json                        "$(EXT_DIR)/"
	cp $(SCRIPTS_DIR)/cleanup-memory.sh                         "$(EXT_DIR)/scripts/"
	chmod +x "$(EXT_DIR)/scripts/cleanup-memory.sh"
	@# Register plugin in openclaw.json
	@python3 -c "\
	import json; \
	from pathlib import Path; \
	p = Path('$(CONFIG_FILE)'); \
	cfg = json.loads(p.read_text()); \
	cfg.setdefault('plugins', {}).setdefault('entries', {}).setdefault('$(PLUGIN_ID)', {})['enabled'] = True; \
	p.write_text(json.dumps(cfg, indent=2) + '\n')"
	@echo "[register] $(PLUGIN_ID) enabled in $(CONFIG_FILE)"

uninstall:
	rm -rf "$(EXT_DIR)"
	@python3 -c "\
	import json; \
	from pathlib import Path; \
	p = Path('$(CONFIG_FILE)'); \
	cfg = json.loads(p.read_text()); \
	cfg.get('plugins', {}).get('entries', {}).pop('$(PLUGIN_ID)', None); \
	p.write_text(json.dumps(cfg, indent=2) + '\n')" 2>/dev/null || true
	@echo "[uninstall] $(PLUGIN_ID) removed"
	$(MAKE) restart

# --- Gateway lifecycle ---

restart:
	@if command -v openclaw >/dev/null 2>&1; then \
		openclaw gateway stop  2>/dev/null || true; \
		sleep 2; \
		openclaw gateway start 2>/dev/null || true; \
		echo "[restart] gateway restarted via openclaw CLI"; \
	elif launchctl list ai.openclaw.gateway >/dev/null 2>&1; then \
		launchctl stop  ai.openclaw.gateway 2>/dev/null || true; \
		sleep 2; \
		launchctl start ai.openclaw.gateway 2>/dev/null || true; \
		echo "[restart] gateway restarted via launchctl"; \
	else \
		echo "[restart] WARNING: could not restart automatically"; \
		echo "  Run manually: openclaw gateway stop && openclaw gateway start"; \
	fi

# --- Verify ---

verify:
	@TOKEN=$$(python3 -c "import json; print(json.load(open('$(CONFIG_FILE)'))['gateway']['auth']['token'])"); \
	echo "--- POST /api/telemetry (location) ---"; \
	curl -s -X POST http://localhost:18789/api/telemetry \
		-H "Authorization: Bearer $$TOKEN" \
		-H "Content-Type: application/json" \
		-d '{"events":[{"type":"location","id":"test-001","timestamp":"2026-01-01T00:00:00Z","data":{"lat":35.6762,"lon":139.6503,"accuracy":10}}]}' | python3 -m json.tool; \
	echo ""; \
	echo "--- POST /api/telemetry (health) ---"; \
	curl -s -X POST http://localhost:18789/api/telemetry \
		-H "Authorization: Bearer $$TOKEN" \
		-H "Content-Type: application/json" \
		-d '{"health":{"steps":7000,"heartRateAvg":72}}' | python3 -m json.tool; \
	echo ""; \
	echo "--- GET /api/recall-settings ---"; \
	curl -s http://localhost:18789/api/recall-settings \
		-H "Authorization: Bearer $$TOKEN" | python3 -m json.tool
