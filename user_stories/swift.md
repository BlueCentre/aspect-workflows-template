# Swift Bazel Starter

    # This is executable Markdown that's tested on CI.
    # How is that possible? See https://gist.github.com/bwoods/1c25cb7723a06a076c2152a2781d4d49
    set -o errexit -o nounset -o xtrace
    alias ~~~=":<<'~~~sh'";:<<'~~~sh'

This repo includes:
- 🧱 Latest version of Bazel and dependencies
- 📦 Curated bazelrc flags via [bazelrc-preset.bzl]
- 🧰 Developer environment setup with [bazel_env.bzl]
- 🎨 `swift-format` formatting, using rules_lint
- 📚 Generic cross-platform Swift via rules_swift

[bazelrc-preset.bzl]: https://github.com/bazel-contrib/bazelrc-preset.bzl
[bazel_env.bzl]: https://github.com/buildbuddy-io/bazel_env.bzl

> [!NOTE]
> This project was generated from the `swift` preset. You can create your own with
> `aspect init --preset swift`, or start from this repo with GitHub's
> "Use this template" button. See https://aspect.build/docs/cli/overview

## Setup dev environment

First, we recommend you setup a Bazel-based developer environment with direnv.

1. install https://direnv.net/docs/installation.html
1. run <code>direnv allow</code> and follow the prompts to <code>bazel run //tools:bazel_env</code>

This isn't strictly required, but the commands which follow assume that needed tools are on the PATH,
so skipping `direnv` means you're responsible for installing them yourself.

## Build and run the sample

The starter ships a tiny `hello/swift` package. Build it and run it. The
`//hello/swift:hello` target uses the `//swift:defs.bzl` wrapper around
rules_swift's `swift_binary` so the hermetic Swift runtime is staged on Linux,
letting `bazel run` find `libswiftCore` at runtime:

~~~sh
aspect build --task:name build-swift-story --github-status-comments:enabled=false --github-status-checks:enabled=false //hello/swift:hello
output=$(bazel run //hello/swift:hello)
echo "${output}" | grep -q "Hello, world!" || {
    echo >&2 "Wanted output containing 'Hello, world!' but got '${output}'"
    exit 1
}
~~~

## Add your own code

Swift has no BUILD file generator in this starter, so create a new package with a
hand-written `BUILD` following the same pattern as the sample. Load `swift_binary`
from `//swift:defs.bzl` (the runtime-staging wrapper), not directly from
rules_swift:

~~~sh
mkdir -p cmd/greet
>cmd/greet/main.swift cat <<'EOF'
print("Greetings from Bazel")
EOF
>cmd/greet/BUILD cat <<'EOF'
load("//swift:defs.bzl", "swift_binary")

swift_binary(
    name = "greet",
    srcs = ["main.swift"],
    visibility = ["//visibility:public"],
)
EOF
~~~

Build and run the new command:

~~~sh
aspect build --task:name build-swift-greet --github-status-comments:enabled=false --github-status-checks:enabled=false //cmd/greet:greet
output=$(bazel run //cmd/greet:greet)
echo "${output}" | grep -q "Greetings from Bazel" || {
    echo >&2 "Wanted output containing 'Greetings from Bazel' but got '${output}'"
    exit 1
}
~~~
