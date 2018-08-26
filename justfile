run: build
    target/sound-garden

build:
    mkdir -p target
    nim c -d:release --opt:speed -d:useRealtimeGC -o:target/sound-garden src/index.nim 

watch:
    watchexec -e nim -- just build
