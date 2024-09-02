.PHONY: build 3rd skynet clean

all: help

help:
	@echo "支持下面命令："
	@echo "  make build   # 编译项目"
	@echo "  make clean   # 清理 "
	@echo "  make console # 启动控制台"
	@echo "  make node1   # 启动节点1"

LUA_CLIB_PATH ?= luaclib
LUA_INCLUDE_DIR ?= skynet/3rd/lua

build: 3rd skynet

3rd: 
	git submodule update --init 
	cd 3rd/lua-cjson && $(MAKE) install LUA_INCLUDE_DIR=../../$(LUA_INCLUDE_DIR) DESTDIR=../.. LUA_CMODULE_DIR=./$(LUA_CLIB_PATH) CC='$(CC) -std=gnu99'
	cd 3rd/lua-protobuf && gcc -O2 -shared -fPIC -I ../../$(LUA_INCLUDE_DIR) pb.c -o pb.so && cp pb.so ../../$(LUA_CLIB_PATH)

skynet:
	git submodule update --init
	cd skynet && $(MAKE) linux 

node1:
	@./skynet/skynet etc/config.node1

console:
	@telnet 127.0.0.1 4040

clean:
	rm -f $(LUA_CLIB_PATH)/*.so