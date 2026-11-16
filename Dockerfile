# Local-source Docker image for Zulip.
# Builds from the source code in this repository root.
FROM ubuntu:24.04 AS base

ENV LANG="C.UTF-8"

ARG UBUNTU_MIRROR

RUN apt-get -q update && \
    apt-get -q dist-upgrade -y && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -q install --no-install-recommends -y ca-certificates git locales python3 sudo tzdata && \
    touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu && \
    useradd -d /home/zulip -m zulip -u 1000

FROM base AS build

RUN echo 'zulip ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

USER zulip
WORKDIR /home/zulip

COPY --chown=zulip:zulip . /home/zulip/zulip
WORKDIR /home/zulip/zulip

# Keep webpack within Docker Desktop memory limits on smaller machines.
ENV NODE_OPTIONS="--max-old-space-size=1024"

# Some local checkouts may not preserve executable bits for helper scripts.
RUN find scripts tools -type f -exec chmod +x {} +

# Keep git index permissions in sync so checkout-index in build-release-tarball
# writes executable scripts in the temporary release tree.
RUN (git ls-files scripts tools; echo manage.py) | xargs -r git update-index --chmod=+x

# Build from local working tree even if git status is dirty.
RUN sed -i '/require_clean_work_tree/d' tools/build-release-tarball

# In local trees with inconsistent file modes, make manage.py executable first
# and call the helper through python3.
RUN sed -i 's#\./tools/update-prod-static#chmod +x ./manage.py \&\& python3 ./tools/update-prod-static#' tools/build-release-tarball

# Avoid execute-bit dependency for manage.py within temporary release checkouts.
RUN sed -i 's#\["\./manage.py", "collectstatic"#["python3", "./manage.py", "collectstatic"#' tools/update-prod-static && \
    sed -i 's#\["\./manage.py", "compilemessages"#["python3", "./manage.py", "compilemessages"#' tools/update-prod-static

RUN SKIP_VENV_SHELL_WARNING=1 python3 ./tools/lib/provision.py --build-release-tarball-only && \
    uv run --no-sync bash ./tools/build-release-tarball docker && \
    mv /tmp/tmp.*/zulip-server-docker.tar.gz /tmp/zulip-server-docker.tar.gz

FROM base

ENV DATA_DIR="/data"

COPY --from=build /tmp/zulip-server-docker.tar.gz /root/
COPY custom_zulip_files/ /root/custom_zulip

WORKDIR /root
RUN \
    dpkg-divert --add --rename /etc/init.d/nginx && \
    ln -s /bin/true /etc/init.d/nginx && \
    mkdir -p "$DATA_DIR" && \
    tar -xf zulip-server-docker.tar.gz && \
    rm -f zulip-server-docker.tar.gz && \
    mv zulip-server-docker zulip && \
    cp -rf /root/custom_zulip/* /root/zulip && \
    rm -rf /root/custom_zulip && \
        for d in /root/zulip/scripts /root/zulip/tools; do \
            if [ -d "$d" ]; then find "$d" -type f -exec chmod +x {} +; fi; \
        done && \
        chmod +x /root/zulip/manage.py && \
        bash /root/zulip/scripts/setup/install --hostname="docker-zulip.local" --email="docker-zulip" \
      --puppet-classes="zulip::profile::docker" --postgresql-version=14 && \
    rm -f /etc/zulip/zulip-secrets.conf /etc/zulip/settings.py && \
    touch /.dockerenv && \
    apt-get -qq autoremove --purge -y && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY entrypoint.sh /sbin/entrypoint.sh
COPY zulip-certbot-setup /usr/local/sbin/zulip-certbot-setup

VOLUME ["$DATA_DIR"]
EXPOSE 25 80 443

HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=300s \
    CMD ["curl", "-isfL", "--insecure", "http://localhost/health"]

ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["app:run"]
