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
- uses: actions/checkout@v6
- name: Setup JDK
  uses: actions/setup-java@v5
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

The `sbt` runner is typically compatible with all modern sbt releases.
In the future, the launcher distributed by sbt 2.x may require JDK 17.

You can pin the `sbt` runner back to sbt 1.x to run JDK 8:

```yaml
env:
  JAVA_OPTS: -Xms2048M -Xmx2048M -Xss6M -XX:ReservedCodeCacheSize=256M -Dfile.encoding=UTF-8
steps:
- uses: actions/checkout@v6
- name: Setup JDK
  uses: actions/setup-java@v5
  with:
    distribution: zulu
    java-version: 8
    cache: sbt
- uses: sbt/setup-sbt@v1
  with:
    sbt-runner-version: 1.12.11
- name: Build and test
  shell: bash
  run: sbt -v +test
```

### Opting out of disk cache

By default setup-sbt saves and restores the sbt 2.x disk cache. This can be opted out as follows:

```yaml
- uses: sbt/setup-sbt@v1
  with:
    disk-cache: false
- name: Build and test
  shell: bash
  run: sbt -v +test
```

### Controlling disk-cache restores

The disk-cache key includes the OS, architecture, Java version, cache-format version,
the date of the current week's Monday, and a hash of the build's `.sbt` and
`.properties` files. Weeks follow the runner's local date.
By default, a missing primary key falls back to caches from any week with the same
OS, architecture, Java version, and cache-format version.
The weekly date rotates cache archives; it does not force a fresh cache each week.

Use `disk-cache-restore-policy` to control these fallback restores:

| Value | Behavior when the primary key is missing |
| --- | --- |
| `all` (default) | Allow fallback restores from any week, preserving the existing behavior. |
| `current-week` | Allow fallback restores only from the current week's dated prefix, including caches with a different build-file hash. |
| `none` | Supply no additional restore prefixes. Normal primary-key lookup still applies. |

```yaml
- uses: sbt/setup-sbt@v1
  with:
    disk-cache-restore-policy: current-week
```

These policies keep the same primary save key and do not affect sbt distribution
caching. `disk-cache: false` skips both saving and restoring the build disk cache.

The policy controls which archive is restored, not the age of its individual
entries. For example, another workflow using `all` can carry older entries into
an archive saved under the current week's key. Existing local caches on persistent
runners and other sbt caches are also unaffected.
To force test execution with sbt 2 while retaining compilation caching, use
`testFull`; changing the archive restore policy does not guarantee tests run.

Why is this GitHub Action needed?
---------------------------------

The runner images on GitHub Action had long included `sbt` runner script. The [initial commit on actions/runner-images](https://github.com/actions/runner-images/pull/96) contains `images/linux/scripts/installers/sbt.sh`

### May 2024

However, the situation has changed in May 2024 when GitHub released the runner image for `macos-13` and `macos-14`, users noticed that they were missing the `sbt` runner script.

[actions/runner-images#9369](https://github.com/actions/runner-images/issues/9369) and [actions/runner-images#9837](https://github.com/actions/runner-images/issues/9837) confirmed that this was intentional:

> Thank you for such detail request. But currently we have no plans to add `sbt` on `macOS-13`/`macOS-14`.

Since GitHub Actions are extensible, we thought this providing a setup action would be convenient way to enable `sbt` again on all runner images.

### December 2024

The situation changed again in December 2024 when GitHub dropped sbt from `ubuntu-latest`. So now this same action is needed for Ubuntu-based builds, too.

License
-------

The scripts and documentation in this project are released under the [MIT License](LICENSE).
