#!/usr/bin/env bash
set -euo pipefail

ATMOSPHERE_REPO="${ATMOSPHERE_REPO:-https://github.com/Atmosphere-NX/Atmosphere.git}"
ATMOSPHERE_REF="${ATMOSPHERE_REF:-master}"
WORKDIR_PATH="${WORKDIR_PATH:-/work}"
OUT_DIR="${OUT_DIR:-/out}"

echo "[atmosphere] repo: ${ATMOSPHERE_REPO}"
echo "[atmosphere] ref:  ${ATMOSPHERE_REF} (branch/tag/commit)"
echo "[atmosphere] work: ${WORKDIR_PATH}"
echo "[atmosphere] out:  ${OUT_DIR}"

mkdir -p "${WORKDIR_PATH}" "${OUT_DIR}"
cd "${WORKDIR_PATH}"

if [[ ! -d Atmosphere/.git ]]; then
  echo "[atmosphere] cloning repository..."
  git clone --recursive "${ATMOSPHERE_REPO}" Atmosphere
else
  echo "[atmosphere] repository exists, updating..."
  (cd Atmosphere && git reset --hard && git clean -xfd)
fi

cd Atmosphere
echo "[atmosphere] fetching refs & tags..."
git fetch --all --tags --prune

echo "[atmosphere] checkout ${ATMOSPHERE_REF}..."
git checkout -f "${ATMOSPHERE_REF}"
git submodule update --init --recursive --force

echo "[atmosphere] building..."
make -j"$(nproc)"

# 尝试打包目标（若存在）
if grep -qE '^package:' Makefile 2>/dev/null || make -n package >/dev/null 2>&1; then
  echo "[atmosphere] packaging (make package)..."
  make -j"$(nproc)" package || true
fi

echo "[atmosphere] collecting artifacts..."
mkdir -p "${OUT_DIR}"

shopt -s nullglob
# 优先复制打包后的 zip（如果有）
for z in ./*.zip ./out/*.zip ./release/*.zip; do
  echo "  -> ${z}"
  cp -f "${z}" "${OUT_DIR}/"
done

# 复制 out 目录（若存在且非空）
if [[ -d out ]] && compgen -G "out/*" > /dev/null; then
  echo "  -> out/*"
  cp -a out/. "${OUT_DIR}/"
fi

echo "[atmosphere] done. artifacts in ${OUT_DIR}"

