FROM alpine:3.20

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    kubectl \
    jq

# Install ArgoCD CLI
RUN curl -sSL -o /usr/local/bin/argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    chmod +x /usr/local/bin/argocd

# Copy registration script
COPY register.sh /register.sh

RUN chmod +x /register.sh

ENTRYPOINT ["/register.sh"]