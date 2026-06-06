# Quick Open

Quick Open 是一个轻量的 macOS 桌面快捷方式整理工具。它常驻菜单栏，可以创建多个悬浮在桌面层的快捷窗口，并通过拖放管理常用应用。

## 功能

- 创建多个独立的快捷方式窗口
- 从 Finder 拖入 `.app` 应用
- 点击图标快速启动应用
- 调整窗口位置和大小
- 修改窗口名称、主题色、标题颜色和透明度
- 设置或清除窗口背景图片
- 管理和删除已有窗口
- 自动保存窗口布局与快捷方式
- 支持登录 Mac 后自动启动
- 可显示在所有桌面空间

## 软件界面

![Quick Open 软件界面](docs/images/quick-open-interface.png)

## 系统要求

- macOS 14.0 或更高版本
- Xcode 15.0 或更高版本

## 构建

1. 克隆仓库：

   ```bash
   git clone https://github.com/dw443106/Quick-Open.git
   cd Quick-Open
   ```

2. 使用 Xcode 打开：

   ```bash
   open "Quick Open.xcodeproj"
   ```

3. 在 Xcode 中选择 `Quick Open` Scheme，然后运行项目。

也可以使用命令行进行无签名构建：

```bash
xcodebuild \
  -project "Quick Open.xcodeproj" \
  -scheme "Quick Open" \
  -configuration Debug \
  -derivedDataPath /tmp/QuickOpenDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 使用

1. 启动后点击菜单栏中的窗口图标。
2. 选择“新建窗口”。
3. 从 Finder 将应用拖入窗口。
4. 点击应用图标即可启动。
5. 使用窗口右上角的设置按钮调整外观。
6. 通过菜单栏中的“管理所有窗口”统一编辑或删除窗口。

配置保存在当前用户的 `UserDefaults` 中。应用路径发生变化后，需要重新拖入对应应用。

## 项目结构

```text
Quick Open/
├── QuickOpenApp.swift       # 应用入口、菜单栏和配置持久化
├── RiceWindow.swift         # 快捷窗口模型与 AppKit 控制器
├── RiceWindowView.swift     # 快捷方式窗口界面
├── WindowManagerView.swift  # 窗口管理界面
├── SettingsView.swift       # 应用设置
└── Assets.xcassets          # 图标和资源
```

## 说明

Quick Open 当前关闭了 App Sandbox，以便启动用户拖入的应用。公开分发或提交 Mac App Store 前，应重新评估沙箱、文件访问权限和安全书签方案。

## License

MIT License. See [LICENSE](LICENSE).
