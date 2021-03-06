# First target in the Makefile is the default.
all: help

# without this 'source' won't work.
SHELL := /bin/bash

# Specify the binary dependencies
REQUIRED_BINS := docker docker-compose
$(foreach bin,$(REQUIRED_BINS),\
    $(if $(shell command -v $(bin) 2> /dev/null),$(),$(error Please install `$(bin)` first!)))

.PHONY : help
help : Makefile
	@sed -n 's/^##//p' $<

## up              : Start Node
.PHONY : up
up: build-config build build-rocksdb
	docker-compose up -d --no-build

## down            : Shutdown Node
.PHONY : down
down:
	docker-compose down

## restart         : Restart Node
.PHONY : restart
restart: down up

## logs            : Tail Node logs
.PHONY : logs
logs:
	docker-compose logs -f -t | grep chainpoint-node

## logs-all        : Tail all logs
.PHONY : logs-all
logs-all:
	docker-compose logs -f -t

## ps              : View running processes
.PHONY : ps
ps:
	docker-compose ps

## build           : Build Node image
.PHONY : build
build: tor-exit-nodes
	docker build -t chainpoint-node .
	docker tag chainpoint-node gcr.io/chainpoint-registry/github-chainpoint-chainpoint-node
	docker container prune -f
	docker-compose build

## build-config    : Copy the .env config from .env.sample
.PHONY : build-config
build-config:
	@[ ! -f ./.env ] && \
	cp .env.sample .env && \
	echo 'Copied config .env.sample to .env' || true

## build-rocksdb   : Ensure the RocksDB data dir exists
.PHONY : build-rocksdb
build-rocksdb:
	mkdir -p ./.data/rocksdb && chmod 777 ./.data/rocksdb

## pull            : Pull Docker images
.PHONY : pull
pull:
	docker-compose pull

## git-pull        : Git pull latest
.PHONY : git-pull
git-pull:
	@git pull --all

## upgrade         : Same as `make down && git pull && make up`
.PHONY : upgrade
upgrade: down git-pull up

## clean           : Shutdown and **destroy** all local Node data
.PHONY : clean
clean: down
	@rm -rf ./.data/*

## print-auth-keys : Print to console the name and contents of auth key (HMAC) backups
.PHONY : print-auth-keys
print-auth-keys: up
	@docker exec -it chainpoint-node-src_chainpoint-node_1 node auth-keys-print.js

## tor-exit-nodes  : Update static list of Exit Nodes
.PHONY : tor-exit-nodes
tor-exit-nodes:
	curl -s https://check.torproject.org/exit-addresses | grep ExitAddress | cut -d' ' -f2 > ./tor-exit-nodes.txt

## cert            : Gen new self-signed TLS cert. 'make cert IP_ADDR=127.0.0.1'
.PHONY : cert
cert:
	./certgen.sh $(IP_ADDR)
