# 生产环境说明（直连模型）

本容器内各云 CLI 已直接配好凭证。需要查云资源时直接在容器内执行对应 CLI。不要向用户索取任何密钥。所有查询优先只读。执行变更类操作前必须先向用户确认。

可用工具：

- `gh repo list --limit 10`：查看 GitHub 仓库
- `hcloud ECS ListServersDetails --limit 5 --cli-region=cn-north-4`：华为云华北四区 ECS
- `aliyun ecs DescribeInstances --RegionId cn-hangzhou`：阿里云杭州地域实例
- `oci compute instance list --compartment-id <ocid> --all`：甲骨文云实例
- `tailscale status`：查看 tailnet 节点状态

工作区说明：

- `/workspace` 为默认工作目录（git 仓库，改动前会自动 checkpoint）。
- 若挂载了 `/old-workspace`，那是历史业务目录，优先只读；需要改动必须先向用户确认。
- 模型经由本地 LiteLLM 网关调用。不要在容器内改动 `/root/.config/opencode/` 下的文件（随容器重建丢失）；要改默认配置请改镜像仓库重打镜像。

- 铁律：运行环境缺工具时，禁止在容器内手工安装——去仓库 Dockerfile 加、走流水线重打镜像（2026-10-09 runner 黑户事故教训，详见 docker/README.md）。
