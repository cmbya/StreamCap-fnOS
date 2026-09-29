# StreamCap fnOS Auto Builder

这是 StreamCap 的非官方 fnOS x86 原生 FPK 自动构建仓库。

- 上游：ihmily/StreamCap
- 不使用 Docker
- GitHub Actions 每 24 小时检查一次上游最新正式 Release
- 检测到新版本后自动生成 `.fpk` 和 `SHA256SUMS.txt`
- 自动创建 GitHub **Pre-release**，方便先在飞牛上测试

## 手动构建

GitHub 仓库 → Actions → `Build StreamCap fnOS FPK` → `Run workflow`。

版本留空：构建上游最新正式版。

也可以填写指定版本，例如：`v1.0.3`。

## 注意

自动“打包成功”不等于上游新版本一定与旧 fnOS 封装完全兼容。上游如果改变启动参数、配置文件结构或依赖方式，仍可能需要修改 `package-template/`。因此默认生成 Pre-release，而不是直接标记为正式版。

## 上游版本与旧包迁移

新 FPK 的 manifest、文件名和 Release tag 直接使用上游版本 `1.0.3`，不再添加封装修订号。同一个上游版本只发布一次，不能静默替换同版本 FPK。

FnDepot 先前索引的版本为 `1.0.307`。已安装的旧包可能因版本号比较或安装来源无法自动升级；切换版本规则需要在设备上单独验证和迁移。
