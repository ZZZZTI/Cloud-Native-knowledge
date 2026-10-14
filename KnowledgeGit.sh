#!/usr/bin/env bash
#
# KnowledgeGit.sh —— 自动提交并推送到 GitHub
#
# 用法：
#   ./KnowledgeGit.sh                 # 提交并推送当前分支
#   ./KnowledgeGit.sh main            # 指定分支
#   REMOTE=origin ./KnowledgeGit.sh   # 指定远程
#
# 可直接放进 crontab / launchd 定时执行，见文件末尾说明。
#
set -euo pipefail

# ---------- 配置 ----------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE="${REMOTE:-origin}"
MSG_PREFIX="${MSG_PREFIX:-routinely commit}"

cd "$REPO_DIR"
BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"

LOCK_DIR=".git/knowledgegit.lock"

log() { printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "错误：$*"; exit 1; }

# ---------- 前置检查 ----------
command -v git >/dev/null 2>&1            || die "未找到 git"
git rev-parse --git-dir >/dev/null 2>&1   || die "$REPO_DIR 不是 git 仓库"
git remote get-url "$REMOTE" >/dev/null 2>&1 || die "远程 $REMOTE 不存在"
[ "$BRANCH" = "HEAD" ] && die "当前处于分离头指针状态，请先 git switch <分支>"

# ---------- 并发锁：避免定时任务重入 ----------
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [ -f "$LOCK_DIR/pid" ] && kill -0 "$(cat "$LOCK_DIR/pid")" 2>/dev/null; then
    die "另一个实例正在运行（PID $(cat "$LOCK_DIR/pid")），本次跳过"
  fi
  log "清理上次遗留的锁"
  rm -rf "$LOCK_DIR" && mkdir "$LOCK_DIR"
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT

log "仓库 $REPO_DIR ｜ 分支 $BRANCH ｜ 远程 $REMOTE"

# ---------- 1. 提交本地改动 ----------
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "$MSG_PREFIX: $(date +'%Y-%m-%d %H:%M:%S')" >/dev/null
  log "已提交 $(git log -1 --pretty='%h %s')"
else
  log "工作区干净，无需提交"
fi

# ---------- 2. 推送到 GitHub ----------
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  log "未设置上游分支，执行首次推送"
  git push -u "$REMOTE" "$BRANCH"
  log "推送完成 ✅ → $REMOTE/$BRANCH"
  exit 0
fi

AHEAD=$(git rev-list --count '@{upstream}..HEAD')
if [ "$AHEAD" -eq 0 ]; then
  log "与 $REMOTE/$BRANCH 已同步，无需推送"
  exit 0
fi

log "有 $AHEAD 个提交待推送"

# 远程有新提交导致 push 被拒时，rebase 后重试一次
if ! git push "$REMOTE" "$BRANCH"; then
  log "推送被拒，尝试 pull --rebase 后重试"
  if git pull --rebase "$REMOTE" "$BRANCH"; then
    git push "$REMOTE" "$BRANCH" || die "重试推送仍失败，请手动处理"
  else
    die "rebase 出现冲突，请手动解决后重新运行"
  fi
fi

log "推送完成 ✅ → $REMOTE/$BRANCH"

# ---------- 定时执行（可选，取消注释并 crontab -e 生效） ----------
# 每小时的第 5 分钟自动提交推送：
#   5 * * * * /Users/mac/Documents/Knowledge/KnowledgeGit.sh >> /tmp/knowledgegit.log 2>&1
