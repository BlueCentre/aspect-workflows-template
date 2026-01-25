# Shell Bazel Starter

    # This is executable Markdown that's tested on CI.
    # How is that possible? See https://gist.github.com/bwoods/1c25cb7723a06a076c2152a2781d4d49
    set -o errexit -o nounset -o xtrace
    alias ~~~=":<<'~~~sh'";:<<'~~~sh'

This repo includes:
- 🧱 Latest version of Bazel and dependencies
- 📦 Curated bazelrc flags via [bazelrc-preset.bzl]
- 🧰 Developer environment setup with [bazel_env.bzl]
- 🎨 `shfmt` and `shellcheck`, using rules_lint
- ✅ Pre-commit hooks for automatic linting and formatting

## Setup dev environment

First, we recommend you setup a Bazel-based developer environment with direnv.

1. install https://direnv.net/docs/installation.html
1. run <code>direnv allow</code> and follow the prompts to <code>bazel run //tools:bazel_env</code>

This isn't strictly required, but the commands which follow assume that needed tools are on the PATH,
so skipping `direnv` means you're responsible for installing them yourself.

## Try it out

Write a simple Bash executable:

~~~sh
>hello.sh cat <<'EOF'
#!/usr/bin/env bash
echo "Hello from Bash"
EOF
chmod u+x hello.sh
~~~

We should be able to generate BUILD files, see .aspect/gazelle/shell.axl for the logic used

~~~sh
bazel run gazelle || true
~~~

Now we verify that running the Bash program produces the expected output.

~~~sh
output="$(bazel run :hello)"
[ "${output}" = "Hello from Bash" ] || {
    echo >&2 "Wanted output 'Hello from Bash' but got '${output}'"
    exit 1
}
~~~

Run shellcheck on the code:

~~~sh
aspect lint
~~~
