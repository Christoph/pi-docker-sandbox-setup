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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Python toolchain for pi-lens (interpreter + ruff, system-wide)
RUN apt-get update \
    && apt-get install -y python3 python3-pip \
    && pip3 install --break-system-packages ruff \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER agent

# Put agent-local npm globals and the Rust toolchain on PATH for ALL processes
ENV PATH="/home/agent/.npm-global/bin:/home/agent/.cargo/bin:${PATH}"

# npm globals: pi + TypeScript/JS and Python language servers
RUN mkdir -p "$HOME/.npm-global" \
  && npm config set prefix "$HOME/.npm-global" \
  && printf '\n npm user-global prefix\nexport PATH="$HOME/.npm-global/bin:$PATH"\n' >> ~/.bashrc \
  && npm install -g --ignore-scripts \
       @earendil-works/pi-coding-agent@latest \
       typescript typescript-language-server \
       pyright

# Rust toolchain + rust-analyzer for pi-lens
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal \
  && . "$HOME/.cargo/env" \
  && rustup component add rust-analyzer clippy

# Global pi settings (~/.pi/agent/settings.json)
RUN mkdir -p "$HOME/.pi/agent" \
  && printf '%s\n' \
    '{' \
    '  "defaultProjectTrust": "always",' \
    '  "packages": [' \
    '    "npm:@juicesharp/rpiv-ask-user-question",' \
    '    "npm:@juicesharp/rpiv-todo",' \
    '    "npm:pi-mcp-adapter",' \
    '    "npm:pi-lens"' \
    '    "npm:pi-powerline-footer"' \
    '  ]' \
    '}' \
    > "$HOME/.pi/agent/settings.json"

# --- Auto-launch pi in interactive shells ------------------------------------
RUN printf '\n Auto-launch pi coding agent in interactive shells\nif [[ $- == *i* ]] && command -v pi &> /dev/null; then\n    exec pi -a\nfi\n' >> ~/.bashrc
