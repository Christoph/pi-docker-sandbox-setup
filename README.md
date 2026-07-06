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

## 1. Prepare Docker Image
Choose you platform.

The Dockerfile includes 5 extensions, adapt as needed.
```
"npm:@juicesharp/rpiv-ask-user-question",' 
"npm:@juicesharp/rpiv-todo",' 
"npm:pi-mcp-adapter",'
"npm:pi-lens",' 
"npm:pi-powerline-footer"'
```

Then build the container

## 2. Build and load image to sbx
```
docker build --platform linux/arm64 -t sbx-shell-pi:v1 .
docker save sbx-shell-pi:v1 -o /OUTPUT/PATH/sbx-shell-pi.tar
sbx template load /OUTPUT/PATH/sbx-shell-pi.tar
```

## 3. run a sandbox from that template (tag is preserved from the save) or use the script form the end of the readme
`sbx run -t sbx-shell-pi:v1 shell`

### Check if the image is there
`sbx template ls`

### Sbx command pane
`sbx`

## 4. Network policy
If you use a strict network ploicy use these as baseline to allow extension install and open subscriptions.
```
sbx policy allow network "auth.openai.com,api.openai.com,chatgpt.com,registry.npmjs.org,pi.dev"
sbx policy allow network "raw.githubusercontent.com,api.github.com,github.com,objects.githubusercontent.com,codeload.github.com,release-assets.githubusercontent.com"
```

## (optional) Forward ports
IMPORTANT: `sbx ports` only works on a **running** sandbox (`sbx ports --help`:
"publish … ports for a running sandbox"), and publishes do not survive the
sandbox being stopped. So the publish must happen on every start, *after* the
sandbox is up — publishing right after `sbx create` (created ≠ running) or
while a previously-used sandbox is stopped silently leaves you with zero
forwards and `ERR_CONNECTION_REFUSED` on the host.

### Example Plannotator
`sbx ports <sandbox> --publish 9999:9999`

### Script for Startup
Opens the pi sandbox and forwards the dashboard ports (8888 okf-memory,
7777 iterator) plus any extra `host:container` args. It boots the sandbox
first (`sbx exec` starts a stopped sandbox), publishes while it is running,
and prints the live port table so you can see the forwards are actually there.

``` bash
# Usage: pisbx                      # sandbox for $PWD, dashboards forwarded
#        pisbx 8080:9999            # additionally forward host:container ports
pisbx() {
  local template="sbx-shell-pi:v9"                 # your loaded template tag
  local ws="${PWD:A}"                              # absolute workspace path (always $PWD)
  local base="${ws:t}"                             # directory name
  local name="shell-${base//[^A-Za-z0-9._+-]/-}"   # sandbox name (sanitized)

  # 1. validate all port args up front (expect host:container, digits only)
  local p
  for p in "$@"; do
    if [[ "$p" != <->:<-> ]]; then
      print -u2 "pisbx: invalid port mapping '$p' (expected host:container, e.g. 8080:9999)"
      return 1
    fi
  done

  # 2. create this sandbox if it doesn't exist yet (created, not running)
  if ! sbx ls -q 2>/dev/null | grep -qx "$name"; then
    sbx create --name "$name" -t "$template" shell "$ws" || return 1
  fi

  # 3. make sure it is RUNNING before publishing — sbx ports only affects a
  #    running sandbox, and publishes are lost when the sandbox stops
  sbx exec "$name" true || return 1

  # 4. publish the dashboard ports + any extras, then show the live table
  local -a wanted=(8888:8888 7777:7777 "$@")
  for p in "${wanted[@]}"; do
    sbx ports "$name" --publish "$p" >/dev/null 2>&1
  done
  sbx ports "$name"

  # 5. attach (documented re-attach form)
  sbx run --name "$name"
}

```
