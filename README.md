# Pi Docker Setup
How to setup pi agent with docker sandbox

# Goal
Having a coding agent with minimal overhead and best extension support in a microVm sandbox with network management.
Three reasons why this is relevant:
1. Supply chain attacks can hit only the sandbox content
2. Pi doesnt ask for permissions which is dangerous with full system access

#Requirements
* Install docker [sbx](https://docs.docker.com/ai/sandboxes/get-started/?ref=ajeetraina.com)
  * Login to sbx `sbx login`
  * Set you api key at the sandbox level `sbx secret set -g anthropic` or login inside pi later
* Install [Pi Agent](https://pi.dev)

# Setup

## 1. Build Docker Image
Choose you platform.
`docker build --platform linux/arm64 -t sbx-shell-pi:v1 .`

## 2. Save tar
`docker save sbx-shell-pi:v1 -o /OUTPUT/PATH/sbx-shell-pi.tar`

## 3. load it into the sandbox runtime's image store
`sbx template load /OUTPUT/PATH/sbx-shell-pi.tar`

## 4. run a sandbox from that template (tag is preserved from the save)
`sbx run -t sbx-shell-pi:v1 shell`

### Check if the image is there
`sbx template ls`

### Sbx command pane

`sbx`

## 5. Allow chatgpt and npm and pi.dev for documentation
Adapt these based on your needs.
```
sbx policy allow network "auth.openai.com,api.openai.com,chatgpt.com,registry.npmjs.org,pi.dev"
sbx policy allow network "raw.githubusercontent.com,api.github.com,github.com,objects.githubusercontent.com,codeload.github.com,release-assets.githubusercontent.com"
```

## (optional) Forward ports
IMPORTANT: This needs to be done for each sandbox on each start

### Example Plannotator
`sbx ports <sandbox> --publish 9999:9999`

### 
Opens the pi sandbox in the current working dir with all subdirs accessible. 

``` bash
# Usage: pisbx            # sandbox named after $PWD
#        pisbx /path/repo # sandbox named after that dir
pisbx() {
  local template="sbx-shell-pi:v1"                 # your loaded template tag
  local ws="${${1:-$PWD}:A}"                        # absolute workspace path
  local base="${ws:t}"                              # directory name
  local name="shell-${base//[^A-Za-z0-9._+-]/-}"    # sandbox name (sanitized)

  # 1. stop every other sandbox so host ports 9999/1455 are free
  sbx ls -q 2>/dev/null | grep -vx "$name" | while read -r other; do
    [[ -n "$other" ]] && sbx stop "$other" >/dev/null 2>&1
  done

  # 2. create this one if it doesn't exist yet (detached, so we can publish)
  if ! sbx ls -q 2>/dev/null | grep -qx "$name"; then
    sbx create --name "$name" -t "$template" shell "$ws" || return 1
  fi

  # 3. forward plannotator UI + OAuth callback (idempotent; persists across restarts)
  sbx ports "$name" --publish 9999:9999 >/dev/null 2>&1
  sbx ports "$name" --publish 1455:1455 >/dev/null 2>&1

  # 4. attach
  print -P "%F{cyan}plannotator%f → http://localhost:9999   %F{242}(sandbox: ${name})%f"
  sbx run "$name"
}
```
