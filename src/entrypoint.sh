#!/usr/bin/env bash

# Copyright 2020 Stefan Prodan. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o pipefail

GITHUB_TOKEN=$1
CHARTS_DIR=$2
CHARTS_URL=$3
OWNER=$4
REPOSITORY=$5
BRANCH=$6
TARGET_DIR=$7
HELM_VERSION=$8
LINTING=$9
COMMIT_USERNAME=${10}
COMMIT_EMAIL=${11}
APP_VERSION=${12}
CHART_VERSION=${13}
OVERRIDE_RELEASES=${14}

CHARTS=()
CHARTS_TMP_DIR=$(mktemp -d)
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_URL=""

main() {
  if [[ -z "$HELM_VERSION" ]]; then
      HELM_VERSION="3.4.2"
  fi

  if [[ -z "$CHARTS_DIR" ]]; then
      CHARTS_DIR="charts"
  fi

  if [[ -z "$OWNER" ]]; then
      OWNER=$(cut -d '/' -f 1 <<< "$GITHUB_REPOSITORY")
  fi

  if [[ -z "$REPOSITORY" ]]; then
      REPOSITORY=$(cut -d '/' -f 2 <<< "$GITHUB_REPOSITORY")
  fi

  if [[ -z "$BRANCH" ]]; then
      BRANCH="gh-pages"
  fi

  if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="."
  fi

  if [[ -z "$CHARTS_URL" ]]; then
      CHARTS_URL="https://${OWNER}.github.io/${REPOSITORY}"
  fi

  if [[ "$TARGET_DIR" != "." && "$TARGET_DIR" != "docs" ]]; then
    CHARTS_URL="${CHARTS_URL}/${TARGET_DIR}"
  fi

  if [[ -z "$REPO_URL" ]]; then
      REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${OWNER}/${REPOSITORY}"
  fi

  if [[ -z "$COMMIT_USERNAME" ]]; then
      COMMIT_USERNAME="${GITHUB_ACTOR}"
  fi

  if [[ -z "$COMMIT_EMAIL" ]]; then
      COMMIT_EMAIL="${GITHUB_ACTOR}@users.noreply.github.com"
  fi

  if [[ -z "$OVERRIDE_RELEASES" ]]; then
      OVERRIDE_RELEASES="off"
  fi

  locate
  download
  dependencies
  if [[ "$LINTING" != "off" ]]; then
    lint
  fi
  package
  upload
}

locate() {
  for dir in $(find "${CHARTS_DIR}" -type d -mindepth 1 -maxdepth 1); do
    if [[ -f "${dir}/Chart.yaml" ]]; then
      CHARTS+=("${dir}")
      echo "Found chart directory ${dir}"
    else
      echo "Ignoring non-chart directory ${dir}"
    fi
  done
}

download() {
  tmpDir=$(mktemp -d)

  pushd $tmpDir >& /dev/null

  curl -sSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar xz
  cp linux-amd64/helm /usr/local/bin/helm

  popd >& /dev/null
  rm -rf $tmpDir
}

dependencies() {
  for chart in ${CHARTS[@]}; do
    helm dependency update "${chart}"
  done
}

lint() {
  helm lint ${CHARTS[*]}
}

package() {
  if [[ ! -z "$APP_VERSION" ]]; then
      APP_VERSION_CMD=" --app-version $APP_VERSION"
  fi

  if [[ ! -z "$CHART_VERSION" ]]; then
      CHART_VERSION_CMD=" --version $CHART_VERSION"
  fi

  helm package ${CHARTS[*]} --destination ${CHARTS_TMP_DIR} $APP_VERSION_CMD$CHART_VERSION_CMD
}

upload() {
  tmpDir=$(mktemp -d)
  pushd $tmpDir >& /dev/null

  git clone ${REPO_URL}
  cd ${REPOSITORY}
  git config user.name "${COMMIT_USERNAME}"
  git config user.email "${COMMIT_EMAIL}"
  git remote set-url origin ${REPO_URL}
  git checkout ${BRANCH}

  charts=$(cd ${CHARTS_TMP_DIR} && ls *.tgz | xargs)

  mkdir -p ${TARGET_DIR}

  published=()
  if [[ "$OVERRIDE_RELEASES" == "off" ]]; then
    for chart in $charts; do
      if ls "${TARGET_DIR}/${chart}" >& /dev/null; then
        echo "Skipping already released chart ${chart}"
      else
        mv -v "${CHARTS_TMP_DIR}/${chart}" ${TARGET_DIR}
        published+=(${chart})
      fi
    done
  else
    mv -vf ${CHARTS_TMP_DIR}/*.tgz ${TARGET_DIR}
    published=$charts
  fi

  if [[ -f "${TARGET_DIR}/index.yaml" ]]; then
    echo "Found index, merging changes"
    helm repo index ${TARGET_DIR} --url ${CHARTS_URL} --merge "${TARGET_DIR}/index.yaml"
  else
    echo "No index found, generating a new one"
    helm repo index ${TARGET_DIR} --url ${CHARTS_URL}
  fi

  git add ${TARGET_DIR}
  git commit -m "Publish $published"
  git push origin ${BRANCH}

  popd >& /dev/null
  rm -rf $tmpDir
}

main
