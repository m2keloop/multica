# Echo 二次开发与上游贡献指南

本文说明 Echo 团队如何维护 Multica 的公司内部下游仓库，以及如何把通用改动贡献回官方 GitHub 仓库。本文适用于：

- `toolkit/multica`
- `toolkit/multica-cli`

上游仓库自带的 `CONTRIBUTING.md` 和 `LICENSE` 始终优先；本文只补充 Echo 内部的 Git、评审和同步流程。

## 1. 仓库与 Remote 的职责

| 名称 | 地址示例 | 用途 |
| --- | --- | --- |
| `origin` | `git@g.echo.tech:toolkit/multica.git` | Echo 内部开发、备份、评审和发布来源 |
| `upstream` | `https://github.com/multica-ai/multica.git` | 官方只读上游，用于同步官方更新 |
| `github-fork` | 个人 GitHub Fork | 仅在准备向官方提交 Pull Request 时添加 |

`multica-cli` 使用相同结构，只需把仓库名替换为 `multica-cli`。

首次克隆后配置：

```bash
git clone git@g.echo.tech:toolkit/multica.git
cd multica
git remote add upstream https://github.com/multica-ai/multica.git
git remote -v
```

不要把个人 GitHub Fork 当作公司代码的长期主仓库。公司日常协作以 `origin` 为准；需要向官方贡献时再创建或添加 `github-fork`。

## 2. 分支与合并规则

- `main` 是受保护分支，禁止直接 Push 和 Force Push。
- 所有公司改动必须通过 GitLab Merge Request 合并。
- 一个分支只解决一个明确问题，避免把内部定制、上游贡献和格式化混在同一个 MR。
- 已推送并被他人使用的分支不要重写历史。
- 合并前按上游 `CONTRIBUTING.md` 执行对应的测试、类型检查和构建检查。

建议的分支名称：

```text
feat/<ticket>-<description>
fix/<ticket>-<description>
chore/<description>
docs/<description>
sync/upstream-<yyyy-mm-dd>
contrib/<upstream-issue>-<description>
```

## 3. Echo 内部开发流程

从公司最新 `main` 创建功能分支：

```bash
git switch main
git pull --ff-only origin main
git switch -c feat/<ticket>-<description>
```

完成开发后：

```bash
git push -u origin HEAD
```

然后在公司 GitLab 创建 Merge Request。MR 至少应说明：

1. 解决的问题和业务背景。
2. 核心实现与影响范围。
3. 验证方式及结果。
4. 是否属于 Echo 专用改动。
5. 是否计划向官方贡献。

Echo 专用能力应尽量放在清晰的适配层、配置开关或独立模块中，避免把公司域名、内部认证、业务规则和部署细节散落到上游通用代码里。

## 4. 判断改动是否适合贡献上游

适合贡献官方的改动通常满足以下条件：

- 对其他 Multica 用户也有价值。
- 不依赖 Echo 内网、账号体系、私有 API 或业务数据。
- 不包含公司域名、密钥、Token、内部工单、客户信息或未公开产品规划。
- 能提供必要的测试和文档。
- 与官方架构和路线一致，或已先通过 Issue/Discussion 与维护者沟通。

以下内容通常保留在公司仓库：

- Echo 账号、权限、飞书、Helios 或内部平台集成。
- 公司专用数据模型、业务流程和运营规则。
- 内部部署参数、网络拓扑、域名和监控配置。
- 尚未完成脱敏和通用化的实现。

如果一个需求同时包含通用能力和 Echo 定制，应拆成两个提交或两个分支：先形成可独立合并的通用改动，再在公司分支补充内部适配。

## 5. 同步官方更新

不要直接把更新推入受保护的 `main`。使用同步分支和 MR：

```bash
git fetch upstream --tags
git switch main
git pull --ff-only origin main
git switch -c sync/upstream-$(date +%F)
git merge upstream/main
```

解决冲突并完成完整验证后：

```bash
git push -u origin HEAD
```

随后创建 GitLab MR。不要通过 Rebase 或 Force Push 重写已经进入公司仓库的上游历史。

## 6. 向官方 GitHub 贡献

只有准备提交官方 Pull Request 时，才需要把官方仓库 Fork 到个人 GitHub：

```bash
git remote add github-fork git@github.com:<github-user>/multica.git
git fetch upstream
git switch -c contrib/<issue>-<description> upstream/main
```

开发时遵循官方 `CONTRIBUTING.md`，并保持改动最小、通用、可测试。完成后：

```bash
git push -u github-fork HEAD
```

然后从个人 Fork 向 `multica-ai/multica` 创建 Pull Request。PR 中说明问题、方案、验证结果和兼容性影响，并遵守上游 `LICENSE` 中的贡献条款。

官方合并后，按“同步官方更新”流程把新提交带回公司仓库。不要再次 Cherry-pick 同一补丁，否则容易产生重复提交和冲突。

## 7. Commit 邮箱与历史导入

公司 GitLab 的服务器级 Hook 要求普通 Push 中的 Commit 作者/提交者邮箱符合 `@echo.tech` 规则。开始公司开发前检查身份：

```bash
git config user.name
git config user.email
```

如需设置，仅对当前仓库配置：

```bash
git config user.name "Your Name"
git config user.email "your.name@echo.tech"
```

处理官方历史时遵循以下规则：

- 不要为了通过邮箱 Hook 而改写官方 Commit 的作者、提交者或 Hash。
- 首次导入和镜像同步应使用经批准的 GitLab Import/Mirror 通道，或由管理员对目标项目临时放行历史导入。
- 临时放行只用于导入公开上游历史；导入完成后立即恢复公司规则。
- 如果一个上游贡献分支同时需要推送到公司 GitLab，优先使用已在 GitHub 验证的 `@echo.tech` 邮箱，以保持两边 Commit Hash 一致。
- 如果不希望在公开 GitHub 提交中使用公司邮箱，可以使用 GitHub 隐私邮箱，但该分支只推个人 Fork；不要为迁就公司 Hook 改写已公开的提交。

## 8. 安全与许可证

- 永远不要提交 `.env`、访问令牌、Cookie、私钥、验证码、生产数据或含密配置。
- 示例配置必须使用占位符，并同步更新 `.gitignore` 或模板文件。
- 对外提交前检查 Git diff、Git 历史、测试快照和日志中是否包含内部信息。
- 保留上游版权、许可证和作者信息。
- 向官方提交代码即表示接受上游 `CONTRIBUTING.md` 和 `LICENSE` 规定的贡献条款；提交前应自行阅读确认。

## 9. Merge Request 检查清单

- [ ] 分支来自正确基线：内部改动基于 `origin/main`，官方贡献基于 `upstream/main`。
- [ ] 没有直接修改或 Force Push 受保护的 `main`。
- [ ] 改动范围单一，没有混入无关格式化或重构。
- [ ] 已执行官方指南要求的测试和检查。
- [ ] 不包含密钥、内部域名、生产数据或其他敏感信息。
- [ ] 已说明这是 Echo 专用改动还是计划贡献上游。
- [ ] 若准备贡献上游，代码已完成通用化，且符合官方许可证和贡献条款。
- [ ] 若包含上游历史，保留了原始作者信息和 Commit Hash，没有为通过邮箱 Hook 改写历史。

## 10. 发生冲突时

优先顺序如下：

1. 安全、合规和公司 GitLab 强制策略。
2. 上游 `LICENSE` 与 `CONTRIBUTING.md`。
3. 本文档。
4. 单个 MR 或临时协作约定。

如果公司策略与保留官方历史发生冲突，应暂停导入并联系 GitLab 管理员，不要静默改写上游历史。
