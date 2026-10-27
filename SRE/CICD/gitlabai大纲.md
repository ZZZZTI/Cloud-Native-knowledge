# GitLab 学习大纲（本地环境实操版）

> 配套环境：本机 GitLab CE <http://localhost:8929> + `glab` 1.124.0
> 环境说明见 [gitlab-lab/README.md](gitlab-lab/README.md)，编排文件见 [gitlab-lab/docker-compose.yml](gitlab-lab/docker-compose.yml)
> 用法：每节的「动手」都能直接在本地环境敲，做完打勾即可。

## 学完能达到什么

- 独立把一个仓库从创建、协作开发、代码评审、CI/CD 到发布跑通一遍
- 理解 GitLab 的对象模型（Group / Project / Issue / MR / Pipeline / Runner / Registry），知道什么场景用哪个
- 会用 `glab` 把日常操作从网页搬到命令行，能用 API 做自动化
- 掌握小型 GitLab 实例的运维（备份、恢复、升级、排障）

## 环境里已经准备好的东西

| 能力                                                 | 状态                                                     |
| ---------------------------------------------------- | -------------------------------------------------------- |
| GitLab CE Web + API（<http://localhost:8929>）       | 可用，root 密码在 `gitlab-lab/.env`                      |
| SSH（2222）/ HTTPS 推拉代码                          | 都可用，HTTPS 由 glab 凭据助手免密                       |
| `glab` 命令行                                        | 已认证，默认 host = `localhost`                          |
| 项目级 Runner（docker executor，tag `docker,local`） | 已在线，CI 可开箱运行                                    |
| 示例项目 `demo/demo-app`                             | 含 1 个 Issue、1 个已合并 MR、1 条成功流水线，可对照着看 |

遇到问题先查 [gitlab-lab/README.md](gitlab-lab/README.md) 的「常见问题」。

## 建议节奏

| 周      | 阶段      | 重点                     | 产出                                 |
| ------- | --------- | ------------------------ | ------------------------------------ |
| 第 1 周 | 一 ~ 三   | 对象模型、仓库、Issue    | 一个带分支保护的仓库 + 3 个 Issue    |
| 第 2 周 | 四 ~ 五   | MR 工作流、CI 基础       | 一次完整 MR + 通过的流水线           |
| 第 3 周 | 六 ~ 七   | Runner、制品、Registry   | 自建 Runner + 镜像/制品产物          |
| 第 4 周 | 八 ~ 十一 | 权限、发布、运维、自动化 | 群组结构 + 备份恢复演练 + 自动化脚本 |

> 每天 1–1.5 小时即可。每阶段末尾的「验收」是硬指标，过不了就别往下走。

---

## 阶段一：心智模型与账号（0.5 天）

### 目标

搞清楚 GitLab 到底管什么，以及各对象之间的从属关系。

### 核心概念

- GitLab = Git 仓库托管 + 代码评审 + CI/CD + 项目管理 + 制品库的一体化 DevOps 平台
- 对象层级：

```
Instance（实例）
└── Group（群组，可嵌套，管权限和项目集合）
    └── Subgroup
        └── Project（项目 = 一个 Git 仓库 + Issue + MR + CI + Wiki + Pages）
            ├── Issue  →  看板 / 里程碑 / 标签
            ├── Merge Request（MR）→ 代码评审 + 流水线
            ├── Pipeline（流水线）→ Stage → Job → 由 Runner 执行
            └── Container Registry / Package Registry（制品）
```

- 三个身份概念：**User**（人）、**Role**（Guest/Reporter/Developer/Maintainer/Owner）、**Visibility**（Private/Internal/Public）
- GitLab vs GitHub 的对应关系（已有 GitHub 经验可快速迁移）：Repository↔Project，Pull Request↔Merge Request，Actions↔CI/CD，Organization↔Group

### 动手

1. 浏览器打开 <http://localhost:8929>，用 `root` + `.env` 里的密码登录
2. 右上角头像 → **Preferences**：改密码、设时区、开深色模式
3. 进入 **Admin Area**（左下角扳手图标）→ Overview → 看实例概览、用户列表、项目列表
4. `glab auth status` 确认 CLI 已认证到本实例

### 验收

- [ ] 能画出上面的对象层级图，并说清 Group 和 Project 的区别
- [ ] 能说出 5 种 Role 各自大概能做什么
- [ ] `glab auth status` 显示 `Logged in to localhost:8929`

---

## 阶段二：仓库与 Git 工作流（1 天）

### 目标

能从零建库、配置认证、按团队规范推代码。

### 核心概念

- 三种建库方式：空项目 / 从模板 / 导入（GitHub、URL、manifest）
- 两种认证：**SSH Key**（推荐）与 **HTTPS + Personal Access Token**（PAT）
- **Protected Branch**：谁能 push、谁能 merge
- **Default Branch**、**Fork** 与 **Branch** 的区别
- 提交规范（Conventional Commits）、`.gitignore`、Git LFS（大文件）

### 动手

```bash
# 1. 生成并上传 SSH key（如果还没有）
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -C "you@local" -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
# 粘贴到 http://localhost:8929/-/user_settings/ssh_keys

# 2. 验证 SSH 通到 GitLab（端口是 2222）
ssh -T -p 2222 git@localhost

# 3. 命令行建项目并推送
glab repo create demo-app --private --description "学习用示例项目"
cd demo-app
printf '# Demo App\n' > README.md
git add . && git commit -m "chore: init repo" && git push -u origin main
```

5. 网页上进 **Settings → Repository → Protected branches**，把 `main` 设成：允许 Merge = Maintainer，允许 Push = No one
6. 试一次直接 push 到 main，观察被拒绝的报错（这是保护分支生效的证据）

### 验收

- [ ] SSH 方式能 clone / push，不用每次输密码
- [ ] 理解「保护分支 + 只能走 MR」这条规则的配置位置和效果
- [ ] 能解释 Fork 工作流和分支工作流分别适合什么团队

---

## 阶段三：Issue、看板与迭代管理（1 天）

### 目标

学会用 Issue 承载需求/缺陷，并用看板管理流动。

### 核心概念

- Issue 的组成：标题、描述、**Labels**（标签）、**Milestone**（里程碑）、**Assignee**、**Due date**、**Weight**、**Epic**（旗舰版功能）
- **Issue Board**（看板）：按标签列组织，拖拽改状态
- **Iteration**（迭代）与 **Milestone** 的区别
- 快捷写法：`#123` 引用 Issue、`!45` 引用 MR、`@user` 提及、`/close` 快捷命令
- **Confidential Issue**（保密 Issue）、**Issue Templates**

### 动手

```bash
glab issue create -t "feat: 支持用户登录" -d "需要邮箱+密码登录" -l feature
glab issue create -t "bug: 首页在窄屏错位" -d "iPhone SE 下布局溢出" -l bug
glab issue create -t "docs: 补 README" -l documentation

glab issue list
glab issue view 1
glab issue note 1 -m "已确认，下个迭代做"
```

5. 网页进 **Issues → Boards**，新建一个看板，按 label 分列（To Do / Doing / Done），拖动卡片
6. 建一个 Milestone「v0.1」，把两个 Issue 挂上去

### 验收

- [ ] 能用 `glab issue list --label bug` 过滤
- [ ] 看板拖动后，Issue 的 label 确实变了（理解「看板 = label 的视图」）
- [ ] 会在描述里用 `#1` 建立关联

---

## 阶段四：Merge Request 与代码评审（1.5 天）

### 目标

跑通「分支 → MR → 评审 → 合并」全流程，这是 GitLab 使用频率最高的动作。

### 核心概念

- MR 的生命周期：Draft → Ready → Review → Approve → Merge
- **Diff 评审**：行级评论、建议修改（Suggested change）、批量评论、Resolve discussion
- **Approval Rules**（审批规则）：需要几个人批
- **Merge 策略**：Merge commit / Squash / Fast-forward
- **Merge Train**（合并列车）
- **Pipeline must succeed**、**Delete source branch**
- **Code Owners**：按路径指定必须由谁 review
- **Cherry-pick**、**Revert**（从 MR 页面一键回滚）

### 动手

```bash
# 1. 从 Issue 1 开分支（glab 会按 issue 自动命名分支）
glab issue view 1
git checkout -b feat/login main

# 2. 改点东西
cat >> README.md <<'EOF'

## 登录
支持邮箱 + 密码登录。
EOF
git add README.md && git commit -m "feat: 增加登录说明" && git push -u origin feat/login

# 3. 提 MR，正文自动带 commit 信息
glab mr create --fill --target-branch main --title "feat: 登录功能" --yes

# 4. 评审动作
glab mr list
glab mr view 1
glab mr note 1 -m "LGTM，建议补一个测试"
glab mr checkout 1      # 本地切到该 MR 的分支
glab mr merge 1 --remove-source-branch --yes
```

5. 网页上把 `main` 的保护规则再加一条 **Approval required = 1**
6. 再开一个 MR，体验「没审批不让合并」的拦截
7. 试试在 MR diff 里点 `+` 写行内评论，用 **Suggest change** 提修改建议

### 验收

- [ ] 会从 Issue 建分支、提 MR、用 `Closes #1` 自动关 Issue
- [ ] 体验过审批规则拦截
- [ ] 能解释 Squash merge 和普通 merge 对提交历史的影响

---

## 阶段五：CI/CD 基础（2 天）

### 目标

写出能跑通的多阶段 `.gitlab-ci.yml`，理解流水线的数据模型。

### 核心概念

- 层次：**Pipeline → Stage → Job**，默认 stage 顺序 `build → test → deploy`
- `.gitlab-ci.yml` 关键字段：`stages`、`image`、`script`、`artifacts`、`cache`、`rules`/`only/except`、`variables`、`before_script`、`needs`、`extends`、`include`
- **rules** 是现在的主流（替代 only/except）：按分支、文件变更、变量、MR 事件决定是否跑
- **artifacts**（产物，传给下游 stage、可下载）vs **cache**（加速，不保证存在）
- **needs** 做 DAG（跳过 stage 顺序，加速）
- **manual job**、**allow_failure**、**retry**、**timeout**
- **CI/CD Variables**：项目级/群组级/实例级，masked 与 protected 的区别
- **Environments / Deployments**：环境的部署记录与回滚
- **CI Lint**：网页 CI/CD → Editor 里校验语法

### 动手

> 环境里的 Runner 已在线，写好 `.gitlab-ci.yml` 推上去就能跑，不用先装 Runner。

```bash
cd demo-app
cat > .gitlab-ci.yml <<'EOF'
stages: [build, test, deploy]

variables:
  APP_NAME: demo-app

build-job:
  stage: build
  image: alpine:3.20
  script:
    - echo "building $APP_NAME"
    - mkdir -p dist && echo "artifact content" > dist/out.txt
  artifacts:
    paths: [dist/]
    expire_in: 1 week

test-job:
  stage: test
  image: alpine:3.20
  script:
    - test -f dist/out.txt || echo "artifact not here, that is why needs matters"
    - echo "running tests"

lint-job:
  stage: test
  image: alpine:3.20
  script:
    - echo "linting"
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  allow_failure: true

deploy-job:
  stage: deploy
  image: alpine:3.20
  script:
    - echo "deploying to staging"
  environment:
    name: staging
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
EOF
git add .gitlab-ci.yml && git commit -m "ci: add pipeline" && git push -u origin feat/ci
glab mr create --fill --yes
glab ci status
```

5. 打开 **Build → Pipelines** 看图形化视图，点进 job 看日志
6. 下载 build-job 的 artifacts（作业页右侧 Browse / 下载）
7. 把 `test-job` 加上 `needs: [build-job]`，观察 DAG 形态变化
8. 进 **Settings → CI/CD → Variables** 加一个 `MY_SECRET`（masked），在 job 里 `echo $MY_SECRET` 看是否被打码

### 验收

- [ ] 能不看文档写出带 rules 的三阶段流水线
- [ ] 能说清 artifacts 和 cache 的区别
- [ ] 理解 manual job 在 deploy 场景的作用
- [ ] 知道 `$CI_COMMIT_BRANCH`、`$CI_PIPELINE_SOURCE`、`$CI_MERGE_REQUEST_IID` 这些预定义变量从哪查

---

## 阶段六：Runner（1 天）

### 目标

搞清楚 Job 到底是谁在跑，能自己注册、配置、排障 Runner。

### 核心概念

- Runner 是执行 Job 的进程，三种 **Executor**：shell / docker / kubernetes
- Runner 作用域：**Shared**（实例级）/ **Group** / **Project**
- **Tag**：Job 的 `tags` 决定它只能被带对应 tag 的 Runner 接走
- **concurrent**（并发数）、**locked**、**protected**（只跑保护分支）
- Docker executor 的 `image`/`services`/`volumes` 配置
- **Docker-in-Docker** vs **DinD-less（socket 挂载）** 的取舍
- `gitlab-runner` 的 `config.toml`、`register`、`verify`、日志排障

### 动手

环境里已有一个项目级 Runner（docker executor，tag `docker,local`），先把它读懂：

```bash
# 1. 看它长什么样
docker exec gitlab-runner cat /etc/gitlab-runner/config.toml
docker exec gitlab-runner gitlab-runner list
glab api projects/2/runners

# 2. 这个配置里最关键的两行（也是本地环境最容易踩的坑）
#    url       = "http://gitlab:8929"   ← runner 自己怎么连 GitLab
#    clone_url = "http://gitlab:8929"   ← job 容器里 clone 用什么地址
#    job 容器内的 localhost 不是宿主机，所以必须改写 clone_url

# 3. 自己再注册一个（可选，练手用），token 从 UI 或 API 拿
glab api --method POST user/runners \
  -f runner_type=project_type -f project_id=2 \
  -f description="my-runner" -f tag_list="test" -f run_untagged=false
docker exec gitlab-runner gitlab-runner register --non-interactive \
  --url http://gitlab:8929 --token <glrt-...> \
  --executor docker --docker-image alpine:3.20 \
  --docker-network-mode gitlab-lab_default
```

4. 进 **Settings → CI/CD → Runners**，确认 Runner 上线（绿点），看它的 tag
5. 给一个 job 加 `tags: [docker]`，观察它能被接走；加一个不存在的 tag，观察 job 卡住 pending
6. 把 `/etc/gitlab-runner/config.toml` 里的 `concurrent` 调成 1，同时跑多个 job，观察排队；改完 `docker restart gitlab-runner`
7. 试着把 `clone_url` 删掉再跑一次流水线，亲眼看一次 `fatal: unable to access 'http://localhost:8929'`，再改回来

### 验收

- [ ] 能解释 job 卡在 pending 的三种常见原因（无 runner / tag 不匹配 / 被 protected 限制）
- [ ] 能自己注册一个 project runner 并让流水线跑起来
- [ ] 知道 docker executor 下 `$CI_PROJECT_DIR` 和 volume 挂载的关系

---

## 阶段七：制品与 Registry（1 天）

### 目标

把"构建产物"存起来，并打通镜像仓库。

### 核心概念

- **Container Registry**：`registry.localhost:8929/group/project:tag`，与项目权限联动
- **Package Registry**：npm / Maven / PyPI / NuGet / Composer / Generic
- **Job Artifacts** 与 **Job Logs** 的保留策略（Admin → Settings → CI/CD → 保留期）
- **Generic packages** 做任意文件分发
- 镜像清理策略（Cleanup policy）

### 动手

`.gitlab-ci.yml` 里加：

```yaml
docker-build:
  stage: build
  image: docker:27
  services:
    - docker:27-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
```

```bash
# 本地拉回来验证
docker login localhost:8929 -u root
docker pull localhost:8929/<group>/demo-app:<sha>
```

### 验收

- [ ] 能在网页 Deploy → Container Registry 看到自己推的镜像
- [ ] 理解 `$CI_REGISTRY_IMAGE`、`$CI_REGISTRY_USER`、`$CI_REGISTRY_PASSWORD` 是自动注入的
- [ ] 知道制品过期策略在哪配

---

## 阶段八：群组、权限与实例管理（1 天）

### 目标

能按组织架构设计 GitLab 的层级，会配权限。

### 核心概念

- Group 嵌套与**权限继承**、**Group-level 变量**、**Group Runner**
- **Members** 与 **Groups 作为成员**（把子群组/群组整体授权）
- **Visibility** 三档、**Project feature 开关**（Issues/Wiki/CI 等可单独关）
- **Deploy Key / Deploy Token**（只读或只写某个仓库，适合 CI 拉取）
- **Impersonation**（管理员模拟用户，排障神技）
- **User 状态**：Active / Blocked / Deactivated / LDAP
- **SAML/SSO、LDAP**（企业集成的入口，本地实例了解概念即可）

### 动手

```bash
# 用 API 建群组和用户
glab api --method POST groups -f name="platform" -f path="platform" -f visibility=private
glab api --method POST groups -f name="frontend" -f path="frontend" -f parent_id=1
glab api --method POST users \
  -f username=alice -f name="Alice" -f email=alice@local \
  -f password="Alice@12345" -f skip_confirmation=true

glab api groups/1/projects
```

5. 网页进 Group → Members，把 alice 加成 Developer
6. 建一个 Deploy Token（Settings → Repository → Deploy tokens），用它 clone 试试
7. 用 Admin → Users → Impersonate 以 alice 身份看一遍界面差异

### 验收

- [ ] 能设计出「平台组 / 前端组 / 后端组」的嵌套结构并说清权限继承
- [ ] 用过 Deploy Token 做无个人凭据的拉取
- [ ] 知道把变量放 Group 级比放每个项目里好在哪

---

## 阶段九：发布、文档与项目管理（0.5 天）

### 目标

把项目从"能跑流水线"推进到"能对外发布"。

### 核心概念

- **Releases**：打 tag + 发布说明 + 附件（关联 Milestone 与 Issue）
- **Changelog API**：按 commit 自动生成变更日志
- **GitLab Pages**：静态站点托管（`pages` job + `public/` 目录）
- **Wiki**：项目内文档；与仓库内 `docs/` 的取舍
- **Snippets**：代码片段共享
- **Milestone / Burnup chart**：迭代健康度

### 动手

```bash
git tag -a v0.1.0 -m "first release" && git push origin v0.1.0
glab release create v0.1.0 --name "v0.1.0 首个版本" --notes "登录功能上线"
glab release list
```

5. 加一个 `pages` job 发布 `public/index.html`
6. 用 Releases API 生成 changelog：`glab api --method POST projects/:id/repository/changelog -f version=v0.2.0`

### 验收

- [ ] 能发一个带附件的 Release
- [ ] 理解 tag 触发的流水线和分支触发的有什么区别
- [ ] Pages 访问地址规则清楚（`https://<pages-domain>/<group>/<project>`）

---

## 阶段十：运维、备份与安全（1 天）

### 目标

能维护一个实例：备份、恢复、升级、看日志、评估安全。

### 核心概念

- **备份/恢复**：`gitlab-backup create` / `gitlab-backup restore`、`/etc/gitlab` 配置单独备份、`gitlab-secrets.json` 的重要性
- **升级路径**：必须按 minor 逐级升级，先跑 `gitlab-rake gitlab:check`
- **日志**：`/var/log/gitlab/` 下各组件日志、`gitlab-ctl tail`
- **健康检查**：`/health`、`/-/readiness`、`gitlab-ctl status`
- **安全**：**Vulnerability Report**（依赖/容器扫描）、**Secret Detection**、**SAST/DAST**（模板化引入）
- **审计事件**（Audit Events）、**2FA 强制**
- **Rate limit**、**Rack Attack** 基础概念

### 动手

```bash
# 备份（在容器内执行）
docker exec -t gitlab gitlab-backup create STRATEGY=copy
docker cp gitlab:/var/opt/gitlab/backups ./backups/
docker cp gitlab:/etc/gitlab/gitlab-secrets.json ./backups/

# 健康检查
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8929/health
docker exec gitlab gitlab-ctl status
docker exec gitlab gitlab-ctl tail puma | head -20

# 把安全扫描模板加进流水线
cat >> .gitlab-ci.yml <<'EOF'

include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml
EOF
```

### 验收

- [ ] 完整做过一次「备份 → 删数据 → 恢复」并成功登录
- [ ] 知道为什么 `gitlab-secrets.json` 丢了会导致恢复后无法解密
- [ ] 能通过日志定位一次 502

---

## 阶段十一：glab 与 API 自动化（1 天）

### 目标

把重复劳动脚本化。

### 核心概念

- `glab api` 直接打 REST API（自动带 token），支持 `--paginate`、`-f`、`--method`
- GitLab API 关键资源：`projects`、`issues`、`merge_requests`、`pipelines`、`jobs`、`users`、`groups`
- **Webhook**：项目/群组/系统级，事件类型与触发条件
- **Pipeline Trigger Token**、**Project Access Token**、**Group Access Token**（比个人 PAT 更适合自动化）
- **OAuth** 应用与 GitLab 作为身份提供方

### 动手

```bash
# 典型自动化：把某标签的 Issue 批量建分支
glab api "projects/:id/issues?labels=feature&state=opened" --paginate | \
  python3 -c "import sys,json;[print(i['iid'], i['title']) for i in json.load(sys.stdin)]"

# 列出最近失败的流水线
glab ci list --status failed

# 原始 API
glab api --method GET projects --field per_page=5
glab api --paginate "projects/:id/pipelines?per_page=100" | head -c 500

# Webhook 建一个
glab api --method POST projects/:id/hooks \
  -f url="http://host.docker.internal:9000/hook" \
  -f push_events=true -f merge_requests_events=true
```

### 验收

- [ ] 能写一个 shell/python 脚本：读 Issue → 建分支 → 提 MR → 打标签
- [ ] 区分得清 PAT / Project Access Token / Deploy Token / Trigger Token 的用途
- [ ] 跑通一个本地 webhook 接收端（可用 `nc -l 9000` 看请求）

---

## 附录 A：glab 命令速查

| 场景         | 命令                                                         |
| ------------ | ------------------------------------------------------------ |
| 登录 / 状态  | `glab auth login` · `glab auth status`                       |
| 建库 / 克隆  | `glab repo create x` · `glab repo clone g/p`                 |
| 仓库信息     | `glab repo view` · `glab repo view --web`                    |
| Issue 增删查 | `glab issue create/list/view/close/reopen/note`              |
| MR 全流程    | `glab mr create/list/view/note/checkout/merge/rebase`        |
| 流水线       | `glab ci status` · `glab ci view` · `glab ci run` · `glab ci list` · `glab ci trace` |
| 变量         | `glab variable list/set/get/delete`                          |
| 发布         | `glab release create/list`                                   |
| 原始 API     | `glab api <endpoint> [-f key=val] [--paginate]`              |
| 别名         | `glab alias set co "mr checkout"`                            |

## 附录 B：本地环境常见坑

| 现象                                         | 原因                               | 处理                                                         |
| -------------------------------------------- | ---------------------------------- | ------------------------------------------------------------ |
| 打开 8929 显示 502/503                       | GitLab 首启未完成                  | 等 3–8 分钟，`docker compose logs -f gitlab` 观察            |
| `ssh -T git@localhost` 连到本机 sshd         | 端口 22 被 macOS sshd 占           | 必须用 `-p 2222`                                             |
| `git clone http://localhost:8929/...` 要密码 | HTTPS 需 PAT                       | 用 `glab auth login` 生成 token，或用 SSH                    |
| CI job 一直 pending                          | 没 runner / tag 不匹配 / protected | 看 Settings → CI/CD → Runners                                |
| Runner 容器连不上 `localhost:8929`           | 容器内 localhost 是它自己          | 用 `host.docker.internal` 或 `172.17.0.1`                    |
| 拉了依赖后 VM 内存吃满                       | Colima 只有 8 GB                   | `docker compose` 已限 5 GB；必要时停 kind 集群 `docker stop lab-control-plane` |
| 重启电脑后打不开                             | Colima 没自启                      | `colima start && docker compose up -d`                       |

## 附录 C：自测清单

能独立答出下面这些，说明基础已经扎实：

1. Group 和 Project 的权限继承规则是什么？
2. 保护分支上「Allow to merge」和「Allow to push」分别影响谁？
3. artifacts 和 cache 的三个关键差异？
4. `rules` 里 `if` 与 `changes` 同时写是「与」还是「或」？
5. Job 卡 pending 的排查顺序？
6. Docker executor 里 `services` 和 DinD 分别解决什么问题？
7. Squash merge 会丢什么信息？什么团队不适合用？
8. 备份 GitLab 必须同时备份哪两样东西？
9. PAT、Deploy Token、Trigger Token 各自不能被谁使用？
10. `needs` 相比 `dependencies` 改变了什么？

## 附录 D：延伸方向

- **GitLab Duo / AI 辅助**（代码建议、MR 摘要）
- **Geo 异地多活**、**Gitaly Cluster**（大规模部署）
- **Kubernetes executor** 与 **Agent（GitLab Agent for Kubernetes）**
- **Compliance Pipeline**、**合并队列**、**Approval 多级规则**
- **OpenTofu / Terraform 集成**、**Auto DevOps**
- 自建 **Helm Chart 部署**（`gitlab/gitlab` chart）替代 Omnibus 单容器

---

## 参考

- 官方文档：<https://docs.gitlab.com/>
- CI/CD 预定义变量：<https://docs.gitlab.com/ee/ci/variables/predefined_variables.html>
- `.gitlab-ci.yml` 关键字全集：<https://docs.gitlab.com/ee/ci/yaml/>
- Runner executor：<https://docs.gitlab.com/runner/executors/>
- glab 手册：<https://gitlab.com/gitlab-org/cli>