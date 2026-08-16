#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"

if [[ -z "$TAG" ]]; then
  echo "用法: $0 v1.0.3" >&2
  exit 2
fi

if [[ "$TAG" != v* ]]; then
  TAG="v${TAG}"
fi

VERSION="${TAG#v}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_REV="$(tr -d '[:space:]' < "$ROOT/PACK_REV")"

[[ -n "$PACK_REV" ]] || {
  echo "PACK_REV 为空" >&2
  exit 2
}

# ================================================================
# fnOS manifest 版本必须保持纯 X.Y.Z。
#
# 旧版错误写法：
#   1.0.3-native2
#   1.0.3-native3
#
# fnOS 可能会把两者都按 1.0.3 判断，
# 导致“已安装相同或更高版本”。
#
# native3 修正版映射：
#   上游 1.0.3 + native3 -> 1.0.303
#   上游 1.0.3 + native4 -> 1.0.304
#   上游 1.0.4 + native1 -> 1.0.401
#
# 规则：
#   fnOS patch = 上游 patch * 100 + native 序号
# ================================================================

if [[ ! "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "上游版本必须是 X.Y.Z，当前：$VERSION" >&2
  exit 2
fi

UP_MAJOR="${BASH_REMATCH[1]}"
UP_MINOR="${BASH_REMATCH[2]}"
UP_PATCH="${BASH_REMATCH[3]}"

if [[ ! "$PACK_REV" =~ ^native([0-9]+)$ ]]; then
  echo "PACK_REV 必须是 native数字，例如 native3；当前：$PACK_REV" >&2
  exit 2
fi

PACK_SEQ="${BASH_REMATCH[1]}"

if (( 10#$PACK_SEQ >= 100 )); then
  echo "native 序号必须小于 100；当前：$PACK_SEQ" >&2
  exit 2
fi

FNOS_PATCH=$((10#$UP_PATCH * 100 + 10#$PACK_SEQ))
FNOS_VERSION="${UP_MAJOR}.${UP_MINOR}.${FNOS_PATCH}"

echo "======================================"
echo "StreamCap 上游版本 : $VERSION"
echo "fnOS 封装修订     : $PACK_REV"
echo "fnOS manifest版本 : $FNOS_VERSION"
echo "======================================"

WORK="$ROOT/.build"
PKG="$WORK/package"
DIST="$ROOT/dist"

rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"

cp -a "$ROOT/package-template" "$PKG"

# 1) 把上游 StreamCap 版本写入 native bootstrap。
python3 - "$PKG/app/native/bootstrap.py" "$TAG" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
tag = sys.argv[2]

s = p.read_text(encoding="utf-8")

s, n1 = re.subn(
    r'^STREAMCAP_VERSION\s*=\s*"[^"]+"',
    f'STREAMCAP_VERSION = "{tag}"',
    s,
    flags=re.M,
)

s, n2 = re.subn(
    r'^SOURCE_URL\s*=\s*"[^"]+"',
    f'SOURCE_URL = "https://github.com/ihmily/StreamCap/archive/refs/tags/{tag}.tar.gz"',
    s,
    flags=re.M,
)

if n1 != 1 or n2 != 1:
    raise SystemExit(
        "无法更新 bootstrap.py 中的 StreamCap 版本，请检查模板"
    )

p.write_text(s, encoding="utf-8")
PY

# 2) 更新 fnOS manifest。
#    注意：version 只能写纯 X.Y.Z 的 FNOS_VERSION，
#    native3 等修订号只放在 changelog / 文件名 / Release Tag。
python3 \
  - "$PKG/manifest" \
  "$FNOS_VERSION" \
  "$VERSION" \
  "$PACK_REV" \
  "$TAG" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])

fnos_version, upstream_version, pack_rev, tag = sys.argv[2:]

lines = p.read_text(
    encoding="utf-8"
).splitlines()

replace = {
    "version": fnos_version,
    "changelog": (
        f"自动跟随上游 StreamCap {tag} 构建；"
        f"fnOS 原生 x86 封装 {pack_rev}；"
        f"fnOS 包版本 {fnos_version}。"
        "保留持久化配置、录像目录和无损升级逻辑。"
    ),
    "checksum": "",
}

out = []
seen = set()

for line in lines:
    key = line.split("=", 1)[0] if "=" in line else ""

    if key in replace:
        out.append(
            f"{key}={replace[key]}"
        )
        seen.add(key)
    else:
        out.append(line)

for key, value in replace.items():
    if key not in seen:
        out.append(
            f"{key}={value}"
        )

p.write_text(
    "\n".join(out) + "\n",
    encoding="utf-8",
)
PY

# 3) app/ -> app.tgz
tar -czf "$PKG/app.tgz" -C "$PKG/app" .

APP_MD5="$(
  md5sum "$PKG/app.tgz" |
  awk '{print $1}'
)"

python3 - "$PKG/manifest" "$APP_MD5" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
md5 = sys.argv[2]

s = p.read_text(
    encoding="utf-8"
)

s, n = re.subn(
    r'^checksum=.*$',
    f'checksum={md5}',
    s,
    flags=re.M,
)

if n != 1:
    raise SystemExit(
        "manifest checksum 字段异常"
    )

p.write_text(
    s,
    encoding="utf-8",
)
PY

rm -rf "$PKG/app"

# 4) 基础自检
for f in "$PKG"/cmd/*; do
  bash -n "$f"
done

python3 -m py_compile \
  "$ROOT/package-template/app/native/bootstrap.py"

python3 - <<PY
import json

for p in [
    r"$PKG/config/privilege",
    r"$PKG/config/resource",
    r"$PKG/wizard/config",
]:
    json.load(
        open(
            p,
            encoding="utf-8",
        )
    )
PY

grep -q '^platform=x86$' \
  "$PKG/manifest"

grep -q "^version=${FNOS_VERSION}$" \
  "$PKG/manifest"

grep -q "^checksum=${APP_MD5}$" \
  "$PKG/manifest"

# 再严格验证一次 fnOS version 必须为 X.Y.Z
MANIFEST_VERSION="$(
  awk -F= \
    '$1=="version"{print $2}' \
    "$PKG/manifest"
)"

if [[ ! "$MANIFEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ manifest version 格式错误：$MANIFEST_VERSION" >&2
  exit 1
fi

echo "✅ manifest version 合法：$MANIFEST_VERSION"

# 5) 生成 .fpk
#
# 文件名仍然保留“上游版本 + native修订”，
# 方便人在 GitHub Release 中识别。
OUT="$DIST/StreamCap_${VERSION}_${PACK_REV}_fnOS_x86.fpk"

tar -czf "$OUT" -C "$PKG" .

# 6) 解包复核
VERIFY="$WORK/verify"

mkdir -p "$VERIFY"

tar -xzf "$OUT" -C "$VERIFY"

EXPECTED="$(
  awk -F= \
    '$1=="checksum"{print $2}' \
    "$VERIFY/manifest"
)"

ACTUAL="$(
  md5sum "$VERIFY/app.tgz" |
  awk '{print $1}'
)"

[[ "$EXPECTED" == "$ACTUAL" ]] || {
  echo "checksum 校验失败" >&2
  exit 1
}

INSTALLED_VERSION="$(
  awk -F= \
    '$1=="version"{print $2}' \
    "$VERIFY/manifest"
)"

[[ "$INSTALLED_VERSION" == "$FNOS_VERSION" ]] || {
  echo "FPK 内 manifest 版本复核失败" >&2
  exit 1
}

gzip -t "$OUT"

sha256sum "$OUT" |
  tee "$DIST/SHA256SUMS.txt"

echo
echo "======================================"
printf '构建成功: %s\n' "$OUT"
printf '上游版本: %s\n' "$VERSION"
printf '封装修订: %s\n' "$PACK_REV"
printf 'fnOS安装版本: %s\n' "$FNOS_VERSION"
echo "======================================"
