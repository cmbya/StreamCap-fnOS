# StreamCap-fnOS native6

native6 保留 native5 的全部定时监听 / scheduler / FFmpeg 自动恢复修复，
只额外解决一个问题：

**不用 SSH，也能直接在飞牛文件管理器查看调试日志。**

## 日志位置

StreamCap 会在你当前选择的录像保存目录下自动创建：

```text
StreamCap-Logs/
└── streamcap-fnos.log
```

例如你的录像目录是：

```text
/vol2/1000/图库/MeTube-down/streamcap
```

那么文件管理器里就是：

```text
图库
└── MeTube-down
    └── streamcap
        └── StreamCap-Logs
            └── streamcap-fnos.log
```

日志超过约 10 MiB 后自动轮转：

```text
streamcap-fnos.log
streamcap-fnos.log.1
```

## 测试每日定时监听时要找的内容

搜索：

```text
fnOS native5 scheduler
fnOS native4 schedule
fnOS native3 ffmpeg
fnOS native3 recovery
```

正常启动：

```text
[fnOS native5 scheduler] new scheduler task created
[fnOS native5 scheduler] persistent periodic scheduler started
```

刷新网页：

```text
[fnOS native5 scheduler] scheduler alive; rebound to latest web session
```

进入每日监听时间：

```text
[fnOS native4 schedule] ENTER window
trigger immediate live check
```

如果发生录制错误：

```text
[fnOS native3 ffmpeg]
[fnOS native3 recovery]
```

## fnOS 版本

如果上游是 StreamCap 1.0.3：

```text
PACK_REV = native6
fnOS manifest = 1.0.306
FPK = StreamCap_1.0.3_native6_fnOS_x86.fpk
```
