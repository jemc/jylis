all: test
.PHONY: all test clean lldb lldb-test ci ci-setup

PKG=jylis

bin/test: $(shell find ${PKG} -name *.pony)
	mkdir -p bin
	stable env ponyc --debug -o bin ${PKG}/test

test: bin/test
	$^

clean:
	rm -rf bin

lldb:
	stable env lldb -o run -- $(shell which ponyc) --debug -o /tmp ${PKG}/test

lldb-test: bin/test
	stable env lldb -o run -- bin/test

ci: test

ci-setup:
