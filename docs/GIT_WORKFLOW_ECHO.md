# Echo 内部 Git 工作流

本文定义 Echo 团队维护以下内部仓库时使用的 Git、分支、worktree 和 GitLab Merge Request（MR）流程：

- `toolkit/multica`
- `toolkit/multica-cli`

本文只覆盖 Echo 内部开发。面向外部代码托管平台的工作不属于本流程。

## 1. 规则来源

按以下顺序确定开发要求：

1. 公司安全、合规和 GitLab 强制策略。
2. 本文件定义的内部 Git 工作流。
3. 当前仓库的 `AGENTS.md` 和 `CLAUDE.md` 定义的架构、编码与验证规则。
4. `Makefile`、项目脚本和内部 CI 中实际可执行的命令。

根目录的 `CONTRIBUTING.md`（若存在）是上游面向人类贡献者的参考文档，不属于 Agent 指令来源。Agent 不得从中派生开发、测试、分支、提交或评审要求。只有用户明确要求分析该文件时，Agent 才可以读取其内容，但不得自动采用为内部规范。

仓库现有 `LICENSE`、版权和作者信息始终有效，不在上述排除范围内。

## 2. 内部仓库与基线

公司日常协作只使用名为 `origin` 的 Echo GitLab remote：

| 仓库 | `origin` |
| --- | --- |
| `multica` | `git@g.echo.tech:toolkit/multica.git` |
| `multica-cli` | `git@g.echo.tech:toolkit/multica-cli.git` |

- `origin/main` 是所有内部开发的唯一基线。
- `main` 是受保护分支，禁止直接 Push 和 Force Push。
- 所有公司改动必须通过 GitLab MR 合并。
- 本流程不修改开发者已有的本地 remote 配置。

开始任务前更新基线：

```bash
git switch main
git pull --ff-only origin main
```

## 3. 分支规则

一个分支只处理一个明确问题，不混入无关格式化、重构或其他需求。

分支类型和描述使用小写英文及连字符；`ticket` 保留公司工单编号的原始格式：

```text
feat/<ticket>-<description>
fix/<ticket>-<description>
chore/<description>
docs/<description>
```

示例：

```text
feat/MUL-123-ldap-login
fix/MUL-456-task-timeout
docs/internal-git-workflow
```

创建普通任务分支：

```bash
git switch -c feat/<ticket>-<description>
```

已经 Push 且被他人使用的分支不得通过 rebase、reset 或 Force Push 重写历史。

## 4. 并行开发与 worktree

单任务允许在普通功能分支中开发。一个开发者或 Agent 同时处理多个任务时，必须满足：

- 一任务一分支。
- 一任务一 worktree。
- 不同 Agent 不得共享工作目录或分支。
- 每个 worktree 必须从最新 `origin/main` 创建。

先获取公司最新基线：

```bash
git fetch origin
```

### `multica`

创建并进入 worktree：

```bash
git worktree add ../multica-<ticket> -b feat/<ticket>-<description> origin/main
cd ../multica-<ticket>
make dev
```

`make dev` 会为 worktree 使用 `.env.worktree`，并隔离数据库、后端端口和前端端口。不要把主 checkout 的 `.env` 复制进 worktree。

开发完成后运行适当验证；需要完整 worktree 检查时使用：

```bash
make check-worktree
```

合并后回到另一个 checkout，再通过仓库封装命令删除 worktree 和对应数据库：

```bash
make remove-worktree WORKTREE=../multica-<ticket>
```

不要直接删除 worktree 目录，也不要在目标 worktree 内删除自身。

### `multica-cli`

该仓库没有独立数据库或端口隔离脚本，使用标准 Git worktree：

```bash
git worktree add ../multica-cli-<ticket> -b feat/<ticket>-<description> origin/main
cd ../multica-cli-<ticket>
```

合并后确认 worktree 没有未提交修改，再从另一个 checkout 清理：

```bash
git worktree remove ../multica-cli-<ticket>
git worktree prune
```

## 5. Commit 规则

- 每个 Commit 保持原子化，只表达一个逻辑变更。
- 使用 conventional 前缀：`feat(scope)`、`fix(scope)`、`refactor(scope)`、`docs`、`test(scope)`、`chore(scope)`。
- Commit 作者和提交者邮箱必须符合公司 GitLab 的 `@echo.tech` 规则。
- 不得为了绕过 GitLab Hook 改写他人的 Commit 身份或历史。

开始开发前检查当前仓库身份：

```bash
git config user.name
git config user.email
```

如需修改，只设置当前仓库：

```bash
git config user.name "Your Name"
git config user.email "your.name@echo.tech"
```

## 6. GitLab MR 流程

完成开发和验证后 Push 当前分支：

```bash
git push -u origin HEAD
```

任何 Push、创建 MR 或其他远端写操作都必须已经由用户明确要求或授权。

GitLab MR 的目标分支为 `main`，至少说明：

1. 业务背景和需要解决的问题。
2. 核心实现和影响范围。
3. 实际执行的验证命令及结果。
4. 未执行的检查及原因。
5. 已知风险和回滚或恢复方式；不适用时明确写明。

所有评审意见都应被处理或明确回复。MR 合并后再删除远端功能分支和本地 worktree。

## 7. 验证要求

验证以当前仓库的 `AGENTS.md`、`CLAUDE.md`、项目脚本和内部 CI 为准，不引用根目录 `CONTRIBUTING.md`。

### `multica`

迭代时运行与修改范围匹配的最小检查；风险较高或用户明确要求时运行更完整的检查，例如：

```bash
pnpm typecheck
pnpm test
make test
make check
```

worktree 中需要完整验证时使用 `make check-worktree`。

### `multica-cli`

至少运行本地回归测试：

```bash
scripts/test-lint.py
```

环境中具备可用的真实 `multica` CLI 时，再运行：

```bash
scripts/lint-skill-commands.py --verbose
```

不得声称未运行的检查已经通过。因文档修改、环境限制或用户要求而跳过检查时，必须在结果和 MR 中说明。

## 8. Agent 外部操作禁令

Agent 的开发权限只覆盖 Echo 内部仓库和 GitLab 流程。Agent 不得：

- Fetch、Push、创建分支或提交变更到官方 GitHub 仓库或个人 Fork。
- 创建、更新或评论官方 Issue、Discussion 或 Pull Request。
- 执行上游同步、官方历史导入或任何等价操作。
- 把根目录 `CONTRIBUTING.md` 当作开发或贡献授权。

用户提出上述请求时，Agent 只能整理当前内部改动、验证结果和风险说明，然后停止外部操作并交由人工处理。人工进行的外部仓库操作不属于本文工作流。

## 9. 安全与清理

- 永远不要提交 `.env`、访问令牌、Cookie、私钥、验证码、生产数据或含密配置。
- 示例配置必须使用占位符，并同步维护模板或 `.gitignore`。
- Push 或创建 MR 前检查 Git diff、提交历史、测试快照和日志中是否包含敏感信息。
- 保留仓库现有版权、许可证和作者信息。
- 合并后删除内部功能分支和 worktree；`multica` 必须通过 `make remove-worktree` 同时清理对应数据库。

## 10. MR 检查清单

- [ ] 分支来自最新 `origin/main`。
- [ ] 没有直接修改或 Force Push `main`。
- [ ] 一个分支只处理一个问题。
- [ ] 并行任务使用独立 worktree 和独立分支。
- [ ] Commit 原子化，邮箱符合 `@echo.tech` 规则。
- [ ] 已执行仓库规则要求的检查，并如实记录结果。
- [ ] 不包含密钥、内部凭据、生产数据或其他敏感信息。
- [ ] 远端写操作只指向 Echo GitLab `origin`，且已获用户明确授权。
- [ ] Agent 未执行任何官方仓库或个人 Fork 操作。
