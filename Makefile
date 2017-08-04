all: build-9.4

build-9.4:
	docker build -t index.xxxxx.com/postgres:9.4 ./9.4
