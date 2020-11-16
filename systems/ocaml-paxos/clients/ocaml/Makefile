
.PHONY:client message.proto

build: client

client: client.ml
	eval `opam env`
	dune build client.exe 
	cp _build/default/client.exe client
