# StreamCap fnOS Auto Builder

这是 StreamCap 的非官方 fnOS x86 原生 FPK 自动构建仓库。

- 上游：ihmily/StreamCap
- 不使用 Docker
- GitHub Actions 每 6 小时检查一次上游最新正式 Release
- 检测到新版本后自动生成 `.fpk` 和 `SHA256SUMS.txt`
- 自动创建 GitHub **Pre-release**，方便先在飞牛上测试

## 手动构建

GitHub 仓库 → Actions → `Build StreamCap fnOS FPK` → `Run workflow`。

版本留空：构建上游最新正式版。

也可以填写指定版本，例如：`v1.0.3`。

## 修改飞牛封装版本

`PACK_REV` 当前为 `native2`。

如果以后修改了 fnOS 打包逻辑，请将它改成 `native3`、`native4`……，这样同一个 StreamCap 上游版本也能重新生成一个新的 Release。

## 注意

自动“打包成功”不等于上游新版本一定与旧 fnOS 封装完全兼容。上游如果改变启动参数、配置文件结构或依赖方式，仍可能需要修改 `package-template/`。因此默认生成 Pre-release，而不是直接标记为正式版。
