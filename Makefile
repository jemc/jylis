all: bin/jylis
.PHONY: all test spec clean lldb lldb-test ci ci-setup release

PKG=jylis
REPO_URL=https://github.com/jemc/jylis
COMPAT_BRANCH=master

bin/${PKG}: bundle.json $(shell find ${PKG} -name *.pony)
	mkdir -p bin
	stable env ponyc --debug -o bin ${PKG}

bin/test: bundle.json $(shell find ${PKG} -name *.pony)
	mkdir -p bin
	stable env ponyc --debug -o bin ${PKG}/test

compat/bin/${PKG}: $(shell find compat -name bundle.json) $(shell find compat/${PKG} -name *.pony)
	git clone ${REPO_URL} --depth 1 --branch ${COMPAT_BRANCH} compat || \
	git --work-tree compat --git-dir compat/.git pull
	mkdir -p compat/bin
	stable env ponyc --debug -o compat/bin compat/${PKG}

test: bin/test
	$^

spec: bin/${PKG} compat/bin/${PKG}
	rspec

clean:
	rm -rf bin

lldb:
	stable env lldb -o run -- $(shell which ponyc) --debug -o /tmp ${PKG}/test

lldb-test: bin/test
	stable env lldb -o run -- bin/test

ci: test spec

ci-setup:
	apt-get update
	apt-get install -y libpcre2-dev ruby
	gem install rspec:3.7.0 redis:4.0.1
	stable fetch

bin/${PKG}-release: bundle.json $(shell find ${PKG} -name *.pony)
	mkdir -p bin
	docker build -t ${PKG}-release .
	docker create --name ${PKG}-release ${PKG}-release
	docker cp ${PKG}-release:/${PKG} bin/${PKG}-release
	docker rm -v ${PKG}-release

# The `make release` target will update the "nightly" release binary on GitHub.
# It will create a new tag named `nightly-{unix-time}` at current master.
# Remove the binary previously uploaded there, and upload the new one.
GITHUB_RELEASE_ID=10442813
GITHUB_AUTH=-H "Authorization: token ${GITHUB_API_TOKEN}"
GITHUB_API_URL=https://api.github.com/repos/jemc/${PKG}
GITHUB_UPLOADS_URL=https://uploads.github.com/repos/jemc/${PKG}
release: bin/${PKG}-release
	@curl -X PATCH  ${GITHUB_AUTH} ${GITHUB_API_URL}/releases/${GITHUB_RELEASE_ID} --data '{"tag_name": "nightly-$(shell date +%s)", "target_commitish": "master" }'
	@curl -X GET    ${GITHUB_AUTH} ${GITHUB_API_URL}/releases/${GITHUB_RELEASE_ID}/assets | jq .[0].id | xargs -I '{id}' \
	 curl -X DELETE ${GITHUB_AUTH} ${GITHUB_API_URL}/releases/assets/{id}
	@curl -X POST   ${GITHUB_AUTH} ${GITHUB_UPLOADS_URL}/releases/${GITHUB_RELEASE_ID}/assets?name=jylis --data-binary @"bin/${PKG}-release" -H "Content-Type: application/octet-stream"
