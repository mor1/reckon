.PHONY: default system client
default: system client

system: 
	cd src && make
	mkdir bins
	cp src/_build/default/bin/main.exe bins/ocamlpaxos

client:
	cd clients/ocaml/ && make
