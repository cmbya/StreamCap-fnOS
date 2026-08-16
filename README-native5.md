# StreamCap-fnOS native5

native5 不是继续改“21:22~02:22”的时间计算。

这次修的是 StreamCap v1.0.3 Web 模式后台监控任务生命周期。

## 根因

v1.0.3 的 Web 模式：

1. 第一次打开网页时创建 App A；
2. App A 启动 periodic live check；
3. main.py 设置全局 `periodic_tasks_started = True`；
4. 浏览器刷新/重连后创建 App B；
5. 因全局标记已经为 True，App B 不会重新绑定后台任务；
6. 原 periodic loop 也没有异常 watchdog；
7. 如果旧 Flet session 失效或 loop 因异常退出：
   - 每日定时不会再自动检查；
   - 但 App B 上手动“禁用 → 开启”会直接执行 `check_if_live()`；
   - 所以手动操作立即又能录制。

这和实际现象一致。

## native5 修复

### 1. 每个 Web 会话都重新绑定 scheduler

不再使用：

```text
第一次启动后永久跳过
```

而是每次网页连接/刷新：

```text
start_periodic_tasks
→ setup_periodic_live_check
→ rebind 到当前 RecordingManager
```

### 2. scheduler 使用真实 asyncio Task 状态

不再只看一个永远可能残留为 True 的布尔值。

现在检查：

```text
task is not None
and not task.done()
```

- task 活着：只 rebind；
- task 已死：自动创建新 task。

### 3. 周期 loop 有 watchdog

单次循环报错不会让整个每日监控永久死亡：

```text
cycle error
→ 记录 traceback
→ 10 秒后继续
```

### 4. 定时任务边界检查提升到 30 秒

只要存在每日定时监听：

```text
最多约 30 秒检查一次是否进入时间窗
```

窗口内真正直播状态检测仍由 StreamCap 原来的规则控制。

### 5. native4/native3 功能全部保留

- 保存定时设置立即 re-arm
- 窗口外 -> 窗口内立即触发
- UTC+8
- 跨午夜
- FFmpeg 失败重新解析直播源
- 8 秒快速重试最多 3 次
- 详细 FFmpeg 日志
- GitHub API rate-limit 修复
- fnOS 数字安装版本

上游 1.0.3 + native5：

```text
manifest version = 1.0.305
FPK = StreamCap_1.0.3_native5_fnOS_x86.fpk
```

## native5 日志

正常启动后应看到：

```text
[fnOS native5 scheduler] bind/rebind periodic scheduler to current web session
[fnOS native5 scheduler] new scheduler task created: ...
[fnOS native5 scheduler] persistent periodic scheduler started
```

网页刷新后应看到：

```text
[fnOS native5 scheduler] scheduler alive; rebound to latest web session
```

到定时时间应看到：

```text
[fnOS native4 schedule] ENTER window ...
trigger immediate live check
```
