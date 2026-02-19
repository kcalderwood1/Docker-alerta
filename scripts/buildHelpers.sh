#!/bin/bash
# Set of utility functions

# Pack directory name (nomad-pack); override with PACK_NAME env if needed
PACK_NAME="${PACK_NAME:-alerta_release}"
PACK_PATH="packs/${PACK_NAME}"

readVersion() {
  local version=$(cat VERSION)
  echo $version
}

incrementVersionNumber() {
  local version=$1
  IFS=. read -r major minor patch <<<"$version"
  ((patch++))
  echo "${major}.${minor}.${patch}"
}

decrementVersionNumber() {
  local version=$1
  previousVersion=$(echo ${version} | awk -F. -v OFS=. '{$NF -= 1 ; print}')
  echo $previousVersion
}

getNextMinorVersion() {
  local version=$1
  IFS=. read -r major minor patch <<<"$version"
  ((minor++))
  echo "${major}.${minor}.0"
}

getReleaseVersion() {
  local version=$1
  IFS=. read -r major minor patch <<<"$version"
  echo "${major}.${minor}"
}

updateVersion() {
  local version=$1
  echo "${version}" >VERSION
  sed -i "s/version *= *\"v[0-9]*\.[0-9]*\.[0-9]*\"/version     = \"v${version}\"/" "./${PACK_PATH}/metadata.hcl"
}

gitSetup() {
    GIT_EMAIL="${GIT_EMAIL:-support@lucera.com}"
    GIT_USERNAME="${GIT_USERNAME:-Teamcity}"

    if [[ -z $GITHUB_TOKEN ]]; then
        echo "Error: GITHUB_TOKEN environment variable is not set."
        exit 1
    fi

    # Configure git with provided user details
    git config --global user.email "${GIT_EMAIL}"
    git config --global user.name "${GIT_USERNAME}"
    git config --global --add safe.directory "$(pwd)"
}

gitCheckout() {
    local REPO_NAME=$1
    local BRANCH=$2

    mkdir -p checkouts/$REPO_NAME
    cd checkouts/$REPO_NAME

    git config --global --add safe.directory "$(pwd)"
    if [ ! -d "./.git" ]; then
        REPO_PREFIX_WITH_USER=$(echo "$REPO_PREFIX" | sed "s/github.com/${GIT_USERNAME}:${GITHUB_TOKEN}@github.com/")
        echo "Cloning ${REPO_PREFIX_WITH_USER}${REPO_NAME} to $(pwd)"
        git clone ${REPO_PREFIX_WITH_USER}${REPO_NAME} .
        git config user.email "${GIT_EMAIL}"
        git config user.name "${GIT_USERNAME}"
        git config credential.helper '!f() { echo username=${GIT_USERNAME}; echo "password=$GITHUB_TOKEN"; };f'
    fi
    if [[ "$BRANCH" ]]; then
        echo "Checking out branch: ${BRANCH}"
        git checkout "$BRANCH"
    fi
    git reset --hard HEAD
    git pull --rebase
    cd ../..
}

# Function to commit and push changes to a git repository using provided credentials.
gitCommitAndPush() {
    local REPO_NAME=$1
    local COMMIT_MESSAGE=$2

    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "${COMMIT_MESSAGE}"
        REPO_PREFIX_WITH_USER=$(echo "$REPO_PREFIX" | sed "s/github.com/${GIT_USERNAME}@github.com/")
        git push
    else
      echo "There were no changes, nothing to commit!";
    fi
}

getGithubReleaseNotesForTag() {
    local REPO_NAME=$1
    local TAG=$2

    if [[ -z $GITHUB_TOKEN ]]; then
        echo "Error: GITHUB_TOKEN environment variable is not set."
        return 1
    fi

    if [[ -z $GITHUB_ORG ]]; then
        echo "Error: GITHUB_ORG environment variable is not set."
        return 1
    fi

    local API_URL="https://api.github.com/repos/${GITHUB_ORG}/${REPO_NAME}/releases/tags/${TAG}"

    local RESPONSE=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${API_URL}")

    local RELEASE_NOTES="$(echo "$RESPONSE" | jq -r '.body // empty' | sed 's/## /### /g')"

    if [[ -z "$RELEASE_NOTES" ]]; then
        echo "Error: Could not fetch release notes for ${REPO_NAME} tag ${TAG}"
        return 1
    fi

    echo "$RELEASE_NOTES"
}

generateReleaseNotesText() {
    local CURRENT_TAG=$1
    local UP_TO_COMMIT=${2-HEAD}
    
    local PREV_TAG=$(git describe --abbrev=0 --tags `git rev-list --tags --skip=1 --max-count=1` 2>/dev/null || echo "")

    if [[ -z $PREV_TAG ]]; then
        COMMITS="$(git log --pretty='%s')"
    else
        if [[ "$CURRENT_TAG" != *.1 ]]; then
            PREV_TAG="v$(decrementVersionNumber ${CURRENT_TAG#v})"
        fi
        COMMITS="$(git log --pretty='%s' ${PREV_TAG}..${UP_TO_COMMIT})"
    fi

    local RELEASE_NOTES=""
    local -A REPO_VERSIONS  # Associative array to store versions per repo
    local -a REPO_ORDER     # Array to maintain repo order
    local FEATURES=""
    local FIXES=""
    local PATCHES=""
    
    # Generate header with version comparison link
    local TODAYS_DATE=$(date +%Y-%m-%d)
    if [[ -z "$PREV_TAG" ]]; then
        RELEASE_NOTES="## ${CURRENT_TAG} (${TODAYS_DATE})\n\n"
    else
        RELEASE_NOTES="## [${CURRENT_TAG}](https://github.com/${GITHUB_ORG}/${RELEASE_REPO_NAME}/compare/${PREV_TAG}...${CURRENT_TAG}) (${TODAYS_DATE})\n\n"
    fi

    # First pass: collect all dependency updates and conventional commits
    while IFS= read -r line; do
        if [[ "$line" == "ci: Updated dependency - "* ]]; then
            # Extract repo name and version from "ci: Updated dependency - repo_name=version"
            local dep_part="${line#ci: Updated dependency - }"
            local repo_name="${dep_part%%=*}"
            local version="${dep_part#*=}"
            repo_name="$(echo $repo_name | sed 's/_/-/g')"

            # Track repo order (only add if not already tracked)
            if [[ -z "${REPO_VERSIONS[$repo_name]}" ]]; then
                REPO_ORDER+=("$repo_name")
            fi

            # Append version to repo's version list (pipe-separated)
            if [[ -n "${REPO_VERSIONS[$repo_name]}" ]]; then
                REPO_VERSIONS[$repo_name]="${REPO_VERSIONS[$repo_name]}|${version}"
            else
                REPO_VERSIONS[$repo_name]="${version}"
            fi
        elif [[ "$line" == "feat:"* || "$line" == "feat("* ]]; then
            local msg="${line#feat:}"
            msg="${msg#feat(*)}"
            msg="${msg# }"
            FEATURES="${FEATURES}* ${msg}\n"
        elif [[ "$line" == "fix:"* || "$line" == "fix("* ]]; then
            local msg="${line#fix:}"
            msg="${msg#fix(*)}"
            msg="${msg# }"
            FIXES="${FIXES}* ${msg}\n"
        elif [[ "$line" == "patch:"* || "$line" == "patch("* ]]; then
            local msg="${line#patch:}"
            msg="${msg#patch(*)}"
            msg="${msg# }"
            PATCHES="${PATCHES}* ${msg}\n"
        fi
    done <<< "$COMMITS"

    # Add conventional commits sections
    if [[ -n "$FEATURES" ]]; then
        RELEASE_NOTES="${RELEASE_NOTES}### Features\n\n${FEATURES}\n"
    fi

    if [[ -n "$FIXES" ]]; then
        RELEASE_NOTES="${RELEASE_NOTES}### Fixes\n\n${FIXES}\n"
    fi

    if [[ -n "$PATCHES" ]]; then
        RELEASE_NOTES="${RELEASE_NOTES}### Patches\n\n${PATCHES}\n"
    fi

    # Build release notes for dependencies
    for repo_name in "${REPO_ORDER[@]}"; do
        RELEASE_NOTES="${RELEASE_NOTES}## ${repo_name}\n\n"

        # Split versions and process each
        IFS='|' read -ra versions <<< "${REPO_VERSIONS[$repo_name]}"
        for version in "${versions[@]}"; do
            RELEASE_NOTES="${RELEASE_NOTES}"

            # Fetch GitHub release notes for this repo/version
            local github_notes=$(getGithubReleaseNotesForTag "$repo_name" "$version" 2>/dev/null)
            if [[ -n "$github_notes" && "$github_notes" != "Error:"* ]]; then
                RELEASE_NOTES="${RELEASE_NOTES}${github_notes}\n\n"
            fi
        done
    done

    echo -e "$RELEASE_NOTES"
}

createGithubRelease() {
    local tag="$1"
    local releaseNotes="$2"
    echo "Creating github release"
    
    cd "./${PACK_PATH}"
    nomad-pack deps vendor
    cd ../..
    
    # Package the pack folder into a tar.gz archive
    local archive_name="${PACK_NAME}_nomad_pack_${tag}.tar.gz"
    echo "Packaging ${PACK_PATH} into ${archive_name}"
    # Create a temporary directory to stage files for the archive
    local temp_dir=$(mktemp -d)
    cp -r "${PACK_PATH}" "${temp_dir}/"
    cp CHANGELOG.md DEPENDENCIES "${temp_dir}/${PACK_NAME}/"
    tar -czvf "${archive_name}" -C "${temp_dir}" "${PACK_NAME}"
    rm -rf "${temp_dir}"

    # Create the GitHub release with the release notes
    local release_response=$(curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${GITHUB_ORG}/${RELEASE_REPO_NAME}/releases" \
        -d @- <<EOF
{
    "tag_name": "${tag}",
    "name": "${tag}",
    "body": $(echo "$releaseNotes" | jq -Rs .),
    "draft": false,
    "prerelease": false
}
EOF
)

    # Extract the upload URL from the response
    local upload_url=$(echo "$release_response" | jq -r '.upload_url' | sed 's/{?name,label}//')

    if [[ -z "$upload_url" || "$upload_url" == "null" ]]; then
        echo "Error: Failed to create GitHub release"
        echo "$release_response"
        return 1
    fi

    echo "Uploading ${archive_name} to release"
    curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Content-Type: application/gzip" \
        --data-binary @"${archive_name}" \
        "${upload_url}?name=${archive_name}"

    # Clean up the archive
    rm -f "${archive_name}"

    echo "GitHub release created successfully"
}

updateChangelog() {
    local releaseNotes="$1"
    
    # Check if CHANGELOG.md exists, if not create it with header
    if [[ ! -f "CHANGELOG.md" ]]; then
        echo "# Changelog" > CHANGELOG.md
        echo "" >> CHANGELOG.md
    fi
    
    {
        head -n 2 CHANGELOG.md
        printf '%s\n\n' "$releaseNotes"
        tail -n +3 CHANGELOG.md
    } > CHANGELOG.md.tmp
    mv CHANGELOG.md.tmp CHANGELOG.md
}

tagProject() {
    local tagVersion=$1
    
    echo "Updating changelog"
    releaseNotes="$(generateReleaseNotesText "v${tagVersion}")"
    updateChangelog "${releaseNotes}"
    git add -A
    git commit -m "ci: Release v$tagVersion"
    git tag -a "v${tagVersion}" -m "ci: Release v$tagVersion"
    echo "Generating release notes"
    git push
    git push --tags
    createGithubRelease "v${tagVersion}" "${releaseNotes}"
}


checkoutAndTagReleaseProject() {
    gitCheckout "${RELEASE_REPO_NAME}" $CI_COMMIT_REF_NAME
    cd "checkouts/${RELEASE_REPO_NAME}"
    
    currentVersion=$(readVersion)
    
    # Check if there are any changes since last tag
    local numOfCommits=$(git rev-list $(git describe --tags --abbrev=0)..HEAD --count)
    if [[ "${numOfCommits}" -eq 0 ]]; then
        echo "Error: There were no commits since the last tag! Nothing to do"
        exit 1
    fi
    
    tagVersion="$(incrementVersionNumber $currentVersion)"
    
    echo "Updating version"
    updateVersion $tagVersion
    echo "Tagging project"
    tagProject $tagVersion
    cd ../..
}

prepareReleaseBranch() {
    repo=$1
    tag=$2
    releaseVersion=$3
    
    gitCheckout "$repo" "$tag"
    cd checkouts/${repo}
    
    branch="release/${releaseVersion}"
    branchExists=$(git ls-remote --heads origin ${branch})
    if [[ -n ${branchExists} ]]; then
        echo "Release branch ${branch} already exists in ${project} repo"
    else
        git checkout -b ${branch}
        git push -u origin ${branch}
    
        if [[ -f "./VERSION" ]]; then
            tagVersion=$(readVersion)
            git checkout main
            nextVersion="$(getNextMinorVersion $tagVersion)"
            updateVersion ${nextVersion}
            git add -A
            git commit -m "ci: Started next release - $nextVersion"
            git push
        fi
    fi
    cd ../..
}

prepareReleaseBranches() {
    tagVersion=$(readVersion)
    releaseVersion=$(getReleaseVersion $tagVersion)
    
    prepareReleaseBranch "${RELEASE_REPO_NAME}" "main" "$releaseVersion"
    prepareReleaseBranch "${VARS_REPO_NAME}" "main" "$releaseVersion"
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Extract service name and tag (format: service_name: vX.Y.Z)
        local service_name="${line%%:*}"
        local service_tag="${line#*: }"

        # Skip if we couldn't parse properly
        [[ -z "$service_name" || -z "$service_tag" ]] && continue

        echo "Preparing release branch for ${service_name} at ${service_tag}"
        prepareReleaseBranch "${service_name//_/-}" "$service_tag" "$releaseVersion"
    done < DEPENDENCIES
}
