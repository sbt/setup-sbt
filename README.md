Setup sbt
=========

This action enables `sbt` runner from GitHub Actions.

Usage
-----

Here's an example usage of setup-sbt action.

```yaml
env:
  JAVA_OPTS: -Xms2048M -Xmx2048M -Xss6M -XX:ReservedCodeCacheSize=256M -Dfile.encoding=UTF-8
steps:
- uses: actions/checkout@v4
- name: Setup JDK
  uses: actions/setup-java@v4
  with:
    distribution: temurin
    java-version: 17
    cache: sbt
- uses: sbt/setup-sbt@v1
- name: Build and test
  shell: bash
  run: sbt -v +test
```

`uses: sbt/setup-sbt@v1` makes `sbt` available on Linux, macOS, and Windows.

### Setting the runner version

The `sbt` runner (Bash script that launches sbt) is typically compatible with all modern sbt releases,
you might want to pin the runner to a specific version.

```yaml
env:
  JAVA_OPTS: -Xms2048M -Xmx2048M -Xss6M -XX:ReservedCodeCacheSize=256M -Dfile.encoding=UTF-8
steps:
- uses: actions/checkout@v4
- name: Setup JDK
  uses: actions/setup-java@v4
  with:
    distribution: temurin
    java-version: 17
    cache: sbt
- uses: sbt/setup-sbt@v1
  with:
    sbt-runner-version: 1.9.9
- name: Build and test
  shell: bash
  run: sbt -v +test
```

Why is this GitHub Action needed?
---------------------------------

The runner images on GitHub Action has long included `sbt` runner script. The [initial commit on actions/runner-images](https://github.com/actions/runner-images/pull/96) contains `images/linux/scripts/installers/sbt.sh`. However, the situation has changed in May 2024 when GitHub released the runner image for `macos-13` and `macos-14`, users noticed that they were missing the `sbt` runner script.

[actions/runner-images#9369](https://github.com/actions/runner-images/issues/9369) and [actions/runner-images#9837](https://github.com/actions/runner-images/issues/9837) confirmed that this was intentional:

> Thank you for such detail request. But currently we have no plans to add `sbt` on `macOS-13`/`macOS-14`.

Since GitHub Actions are extensible, we thought this providing a setup action would be convenient way to enable `sbt` again on all runner images.

License
-------

The scripts and documentation in this project are released under the [MIT License](LICENSE).
