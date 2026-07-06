FROM docker/sandbox-templates:shell

USER root

RUN apt-get update \
    && apt-get install -y curl ca-certificates gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER agent

ENV NPM_CONFIG_PREFIX=/home/agent/.npm-global
ENV PATH=/home/agent/.npm-global/bin:$PATH

ENV OKF_REMOTE=1
ENV ITERATOR_REMOTE=1

RUN mkdir -p "$NPM_CONFIG_PREFIX" \
    && npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest \
    && command -v pi 

RUN npx --yes impeccable@latest install \
      --providers=pi \
      --scope=global \
      --no-hooks

RUN mkdir -p "$HOME/.pi/agent" \
    && printf '%s\n' \
'{' \
'  "npmCommand": ["npm"],' \
'  "packages": [' \
'    "npm:@juicesharp/rpiv-ask-user-question",' \
'    "npm:@juicesharp/rpiv-todo",' \
'    "npm:pi-mcp-adapter",' \
'    "npm:pi-lens",' \
'    "npm:pi-powerline-footer"' \
'  ]' \
'}' > "$HOME/.pi/agent/settings.json" \
    && node -e 'JSON.parse(require("fs").readFileSync(process.env.HOME + "/.pi/agent/settings.json", "utf8"))'

RUN pi install git:github.com/Christoph/okf-memory \
    && node -e 'JSON.parse(require("fs").readFileSync(process.env.HOME + "/.pi/agent/settings.json", "utf8"))'

RUN pi install git:github.com/Christoph/iterator \
    && node -e 'JSON.parse(require("fs").readFileSync(process.env.HOME + "/.pi/agent/settings.json", "utf8"))'

RUN printf '%s\n' \
'if [[ $- == *i* ]] && command -v pi >/dev/null 2>&1; then' \
'  exec pi -a' \
'fi' >> "$HOME/.bashrc"
