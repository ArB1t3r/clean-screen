# Migration to Dynamic Swift Compilation

## 概述

本次更新将项目从使用预编译二进制文件改为使用动态编译的Swift源代码，以符合Raycast扩展商店的要求。

## 主要变化

### 1. 项目结构调整

**之前：**
```
helper/                          # Swift Package源代码
scripts/build-helper.sh          # 手动构建脚本
assets/CleanScreenHelper.app     # 预编译的.app文件
assets/CleanScreenHelper         # 预编译的二进制文件
```

**之后：**
```
assets/clean-screen-helper/      # Swift Package源代码（新位置）
├── Package.swift
└── Sources/
    └── CleanScreenHelper/
        └── main.swift
```

### 2. 构建流程变化

**之前：**
- 需要手动运行 `npm run build:helper` 预先编译Swift代码
- 使用自定义shell脚本构建
- 预编译的二进制文件保存在assets目录

**之后：**
- 首次运行时自动编译
- 源代码修改后自动重新编译
- 使用标准的 `swift build` 命令
- 编译产物存储在 `environment.supportPath`（用户特定的支持目录）

### 3. 代码改进

**src/index.ts 核心功能：**
- `getHelperPaths()`: 获取Swift Package路径和构建路径
- `ensureHelperBuild()`: 检查并在需要时编译Swift helper
- `helperNeedsBuild()`: 通过比较文件修改时间判断是否需要重新编译
- `newestHelperSourceMtime()`: 递归查找最新的源文件修改时间
- `runProcess()`: 执行命令行进程（编译或运行）

### 4. Package.swift 优化

- Swift工具版本从 6.2 降级到 5.9（更好的兼容性）
- 移除了显式的 linkerSettings（由系统自动处理）
- 简化了配置

### 5. 配置文件更新

**package.json:**
- 移除了 `build:helper` 脚本（不再需要手动构建）

**.gitignore:**
- 移除了旧的helper构建产物路径
- 添加了新的Swift构建产物路径：
  - `assets/clean-screen-helper/.build`
  - `assets/clean-screen-helper/.swiftpm`

## 优势

1. **符合Raycast要求**: 不再使用预编译二进制文件
2. **开发体验更好**: 修改Swift代码后自动重新编译
3. **安全性提升**: 用户可以审查源代码
4. **兼容性更好**: 针对用户的系统架构编译（Intel/Apple Silicon）
5. **维护简化**: 不需要维护多个平台的预编译二进制

## 迁移步骤（已完成）

- [x] 将Swift源代码移动到 `assets/clean-screen-helper/`
- [x] 更新Package.swift降低Swift版本要求
- [x] 重写src/index.ts实现动态编译逻辑
- [x] 删除预编译的二进制文件和.app
- [x] 删除自定义构建脚本
- [x] 更新package.json移除build:helper脚本
- [x] 更新.gitignore
- [x] 更新README和CHANGELOG文档
- [x] 验证构建流程

## 使用说明

**开发模式：**
```bash
npm run dev
```

**生产构建：**
```bash
npm run build
```

**注意：** Swift helper会在以下情况自动编译：
1. 首次运行扩展时
2. 在开发模式下每次运行时
3. 源代码文件被修改后

## 参考

本次重构参考了Raycast官方扩展的最佳实践：
- [cut-out extension](https://github.com/raycast/extensions/pull/25663)
