# Helm Publisher

A GitHub Action for publishing Helm charts with Github Pages.

## Usage

Inputs:
* `token` The GitHub token with write access to the target repository
* `charts_dir` The charts directory, defaults to `charts`
* `charts_url` The GitHub Pages URL, defaults to `https://<OWNER>.github.io/<REPOSITORY>`
* `owner` The GitHub user or org that owns this repository, defaults to the owner in `GITHUB_REPOSITORY` env var
* `repository` The GitHub repository, defaults to the `GITHUB_REPOSITORY` env var
* `branch` The branch to publish charts, defaults to `gh-pages`
* `target_dir` The target directory to store the charts, defaults to `.`
* `helm_version` The Helm CLI version, defaults to the latest release
* `linting` Toggle Helm linting, can be disabled by setting it to `off`

## Examples

Package and push all charts in `./charts` dir to `gh-pages` branch:

```yaml
name: release
on:
  push:
    tags: '*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Publish Helm charts
        uses: stefanprodan/helm-gh-pages@master
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

Package and push charts in `./chart` dir to `gh-pages` branch in a different repository:

```yaml
name: release-chart
on:
  push:
    tags: 'chart-*'

jobs:
  release-chart:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Publish Helm chart
        uses: stefanprodan/helm-gh-pages@master
        with:
          token: ${{ secrets.BOT_GITHUB_TOKEN }}
          charts_dir: chart
          charts_url: https://charts.fluxcd.io
          owner: fluxcd
          repository: charts
          branch: gh-pages
          target_dir: charts
```
