COMMAND_COLOR = \033[36m
DESC_COLOR    = \033[32m
CLEAR_COLOR   = \033[0m
SERVICE_NAME  = minecraft
CONTAINER_NAME = neoforgeserver

# Auto-detect container runtime
# 1. Default to Docker if found
# 2. Fallback to Podman if Docker is missing
# 3. Allow override (e.g., make up DOCKER=podman)
ifneq (,$(shell command -v docker))
	DOCKER_DEFAULT := docker
	COMPOSE_DEFAULT := docker-compose
else ifneq (,$(shell command -v podman))
	DOCKER_DEFAULT := podman
	COMPOSE_DEFAULT := podman-compose
else
	DOCKER_DEFAULT := docker
	COMPOSE_DEFAULT := docker-compose
endif

DOCKER ?= $(DOCKER_DEFAULT)
DOCKER_COMPOSE ?= $(COMPOSE_DEFAULT)

.PHONY: help
help: ## prints this message ## 
	@echo ""; \
	echo "Usage: make <command>"; \
	echo ""; \
	echo "where <command> is one of the following:"; \
	echo ""; \
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	perl -nle '/(.*?): ## (.*?) ## (.*$$)/; if ($$3 eq "") { printf ( "$(COMMAND_COLOR)%-20s$(DESC_COLOR)%s$(CLEAR_COLOR)\n\n", $$1, $$2) } else { printf ( "$(COMMAND_COLOR)%-20s$(DESC_COLOR)%s$(CLEAR_COLOR)\n%-20s%s\n\n", $$1, $$2, " ", $$3) }';

.PHONY: up
up: ## 🚙 Runs the server ## ($(DOCKER_COMPOSE) up -d) 
	@echo "📦 Starting..."
	@$(DOCKER_COMPOSE) up -d

.PHONY: stop
stop: ## 🛑 Stops the server ## ($(DOCKER_COMPOSE) stop) 
	@echo "🛑 Stopping..."
	@$(DOCKER_COMPOSE) stop

.PHONY: down
down: ## 👎 Remove containers and network ## (Keep volumes) 
	@echo "👎🏻 Tearing down..."
	@$(DOCKER_COMPOSE) down

.PHONY: build
build: ## ️ Rebuilds the image locally ## (Using Dockerfile) 
	@echo "🛠️ Rebuilding image..."
	@$(DOCKER_COMPOSE) build --no-cache
	@$(MAKE) up
	@$(MAKE) logs

.PHONY: restart
restart: ## 🔃 Restarts the container ## (Quick reload)
	@echo " Restarting..."
	@$(DOCKER_COMPOSE) restart
	@$(MAKE) logs

.PHONY: update
update: ## ⬇️ Pulls latest image and restarts ## (For pre-built image users)
	@echo "⬇️ Pulling latest updates..."
	@$(DOCKER_COMPOSE) pull
	@$(MAKE) up
	@$(MAKE) logs

.PHONY: logs
logs: ## 🧻 Follow logs ## 
	@$(DOCKER_COMPOSE) logs --tail 50 -f $(SERVICE_NAME)

.PHONY: attach
attach: ##  Attach to console ## (Ctrl+P+Q to detach!) 
	@echo "📌 Attaching to console..."
	@echo "⚠️  REMEMBER: Use [Ctrl+P] then [Ctrl+Q] to detach safely."
	@echo "   (Ctrl+C will KILL the server!)"
	@echo ""
	@$(DOCKER) attach $(CONTAINER_NAME)

.PHONY: clean
clean: ##  Remove everything ## (WARNING: DELETES DATA!)
	@echo "⚠️  WARNING: This will delete the 'neoforge_data' folder!"
	@read -p "Are you sure? [y/N] " ans && [ $${ans:-N} = y ]
	@$(DOCKER_COMPOSE) down -v --remove-orphans
	@rm -rf neoforge_data
	@echo "🧹 Cleaned."

.PHONY: test
test: ## 🧪 Build and run a temporary container for testing ##
	@echo "🧪 Building test image..."
	@$(DOCKER) build -t neoforge-test .
	@echo "📦 Starting temporary server (2GB RAM)..."
	@mkdir -p neoforge_data
	@$(DOCKER) run -it --rm \
		--name neoforge-test-runner \
		-p 25565:25565 \
		-v "$$(pwd)/neoforge_data:/data" \
		-e MEMORYSIZE=2G \
		neoforge-test
