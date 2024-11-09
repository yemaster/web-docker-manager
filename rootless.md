# Hackergame Web-Docker-Manager Rootless Architecture

## TLDR

每道题目需要有 "rootless-start.sh" 脚本，启动时先使用系统 Docker（我们称为 D0）运行 docker-compose-rootless.yml 创建出有 systemd 的一个容器（容器里面的 Docker 我们称为 D1。D1 的 socket 通过 bind mount 暴露在系统中）。然后利用 `DOCKER_HOST` 环境变量设置使用该 socket 执行题目相关的 docker-compose.yml。

D0 有完整的系统权限，D1 运行在 D0 的一个容器中，是 rootless (UID=1000) 的。

docker-compose.yml 包含题目 challenge 容器和 manager (front)。

## D1 的初始化

D1 的 compose 配置位于 rootless 文件夹下，需要 D0 执行。`extends` 该配置的 compose 需要：

- 设置端口映射（`127.0.0.1:$port:$port`），以让 host 的 nginx 可以访问到 D1 里面的 manager
- bind mount 暴露 D1 的 socket
- 设置持久化 D1 的 Docker 配置（相当于 D0 的 `/var/lib/docker`），否则每次重建都需要从头构建所有的容器
- bind mount 暴露 D1 能访问的题目数据（即 `.env` 中的 `data_dir`，未完成）

D1 **所在**容器相比于 D0 打开的普通容器，有更多的权限，包括 `SYS_ADMIN` `NET_ADMIN` capabilities，以及放开了 apparmor，减小了 seccomp 限制等，可以认为近似于 host root 环境。因此 D1 socket 被 compromise 的安全性保障主要来源于用户的隔离，即 1000 用户无法实现 root 用户的危险操作。攻击者无法做 1000 用户做不到的事情，包括但不限于修改系统配置、跳出当前的 namespace 来获取其他题目文件/以 host 身份任意执行等。例如，攻击者无法使用 `--privileged` 参数：

```console
rootless@554daaee6501:~$ DOCKER_HOST=unix:///shared/run/docker.sock docker run --rm --privileged juan-challenge
docker: Error response from daemon: failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: error mounting "sysfs" to rootfs at "/sys": mount sysfs:/sys (via /proc/self/fd/6), flags: 0xe: operation not permitted: unknown.
```

Docker rootless 利用了 rootlesskit 来做具体的 rootless 实现（例如创建用户命名空间等）。

由于 Docker rootless 的 cgroup 依赖于 systemd 的「委派」实现（即将原本只有 root 能够操作的 cgroup subtree 修改所有者到 1000 用户），因此我们无法使用 Docker 提供的 rootless Docker-in-Docker (dind) 镜像，基于 Debian 做了有 systemd 的自行构建。

如果需要验证 D1 所在容器 rootless 可以做什么，可以在 host (D0) 运行 `docker exec -it xxx bash` 之后，在里层 `su - rootless` 后进行测试操作。

## 题目的初始化

在 D1 启动完成后，D1 需要根据题目的 compose 配置构建、启动对应的容器。

manager 的架构大体与 dynamic_flag 相近，以下几个方面有变化（也导致了其代码量更大一些）：

- manager 需要负责反代请求。其会先判断请求是否是操作容器的（`docker-manager/`），如果不是，则会尝试将请求反代到题目容器
- 多出了 sqlite 数据库，用来存储当前的容器状态
- 题目容器关闭网络。题目容器与 manager 的通信使用 UNIX socket 实现（因此需要在容器中运行 `gocat` 将 TCP socket 转换为 UNIX socket）

目前部署的 manager 与 PKU 版本相比，修正了一些问题。如果需要测试控制了 manager 之后可能的情况，可以：

```sh
DOCKER_HOST=unix:///path/to/challenges/example/run/docker.sock docker exec -it example-front-1 bash
```

manager 的 `/vol` 对应 D1 所在容器的 `${data_dir}/vol`。

- db: 存储 sqlite 数据库文件的文件夹
- gocat: TCP to UNIX 程序的 binary
- logs: 在 stdlog 打开（默认）情况下存储每个容器的 log
- sock: 存储 `gocat` 在题目容器里面创建的 UNIX socket 们的文件夹
