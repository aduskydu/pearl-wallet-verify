# pearl-wallet-verify

Checks the **official Pearl Wallet** desktop release from [pearl-research-labs/pearl](https://github.com/pearl-research-labs/pearl) on GitHub's own machines, rebuilds the file found broken in the Intel Mac build and re-signs the Apple Silicon app ad hoc (both unofficial; see Results).

`.github/workflows/verify.yml` (run by hand, input: the release tag, default `pearl-wallet-v3.0.0`):

- **checksums** (Ubuntu): downloads every asset of the release and checks each one against the release's `checksums.txt` and against GitHub's own SHA-256 digest of the upload.
- **macos** (Intel `macos-15-intel` and Apple Silicon `macos-15`): checks the DMG hash, then reports the app and Electron versions, the minimum macOS, the architectures, the code signature, the Gatekeeper verdict and the notarization ticket; copies the app out of the DMG, launches it and takes a screenshot; then adds the quarantine flag a browser sets, launches it again, removes the flag and relaunches it; finally runs the wallet test below on the bundled `oyster`.
- **windows** (`windows-latest`): checks the installer hash and Authenticode signatures, installs silently (per user), launches the app, takes a screenshot, runs the wallet test on the bundled `oyster`, then uninstalls.

Wallet test (`scripts/oyster-smoke.sh`) starts oyster the way the desktop app does according to its source (`wallet-process.ts`: `--createfromfile`, then `--usespv`) and checks it over JSON-RPC: a new mainnet wallet from `--createfromfile` prints a 12-word mnemonic → the wallet runs in SPV mode and returns a `prl1…` address that `validateaddress` reports as valid and owned → a wallet restored from the mnemonic returns the same first address → a second new wallet returns a different one. Throwaway wallets only, deleted at the end; the SPV progress against the live network is reported for information.

Results: each run's Summary page, plus the `macos-x86_64`, `macos-arm64` and `windows` artifacts (report and screenshots).

Other workflows: `intel-fix.yml` and `arm64-resign.yml` make the fixed DMGs (each with a check on a fresh runner), `verify-fixed.yml` rechecks an existing Intel fix artifact without rebuilding it, `gatekeeper.yml` tests what a downloaded copy meets and which workaround gets it to start, and `release.yml` publishes the fixed DMGs from their build runs, after checking them against the hashes those runs recorded.

## Results for Pearl Wallet v3.0.0 (2026-10-20)

Tag `pearl-wallet-v3.0.0` = commit `837c69c5`, bundled `oyster` 1.5.0. Fixed DMGs: release [`pearl-wallet-v3.0.0-fix1`](../../releases/tag/pearl-wallet-v3.0.0-fix1) (unofficial). Runs: [verify](../../actions/runs/39475603342) (shown as failed: the macOS Intel job fails, and the relaunch-after-`xattr` step fails in both macOS jobs, see Gatekeeper below), [Gatekeeper](../../actions/runs/39477056980).

| | Windows x64 | macOS Intel | macOS Apple Silicon |
|---|---|---|---|
| Hash matches `checksums.txt` and GitHub's digest | yes | yes | yes |
| Signature | none (installer, app and oyster unsigned) | none | main binary: only the linker's automatic ad-hoc signature; the bundle is not signed ("code has no resources but signature indicates they must be present") |
| Notarized | – | no | no |
| Launch with the quarantine flag a browser download sets (simulated) | not tested; unsigned, so a SmartScreen warning is likely | blocked: "“Pearl Wallet” Not Opened" (Done / Move to Trash) | blocked: "“Pearl Wallet” is damaged and can't be opened" (Cancel / Move to Trash) |
| App launches (screenshot) | yes (Windows Server 2025 runner) | yes | yes |
| Bundled `oyster` | x64 (per file name) | **arm64: "Bad CPU type" on an Intel Mac** | arm64, minos 26.0 (runs on macOS 15) |
| Wallet test of the bundled `oyster` | passed | **failed (cannot start)** | passed |

**macOS Intel**: `Contents/Resources/bin/oyster-darwin-x64` is an arm64 build (sha256 `3c3a464c11ca184737ddcf47c089e7599a9c6fbee2237a79a0c74ef7b33d9c76`); the separate `go-binaries-darwin-amd64-v1.5.0.tar.gz` holds the same file. According to the app's source, oyster is its wallet backend, so on an Intel Mac the app has no working wallet backend. Cause: in the official `pearl-desktop-wallet.yml` the "macOS Intel" job runs on `macos-15`, which is an arm64 runner, with only `GOOS=darwin` set, so `task build:blockchain` builds for arm64.

**Gatekeeper** (`gatekeeper.yml`, fresh copies on macOS 15.7.9, official and fixed builds on both architectures): removing the quarantine flag before the first launch (`xattr -dr com.apple.quarantine`) let all four builds start. After a launch that Gatekeeper had blocked, with that first dialog still on screen (the script could not close it, and clicking Done was not simulated), removing the flag with `xattr -dr` did not let that copy start (a new "Not Opened" dialog appeared), and neither did `xattr -cr` afterwards. Whether removing the flag works after clicking Done was not tested; neither was System Settings → Privacy & Security → Open Anyway.

### Fixes (unofficial)

Both are unofficial repackages made by this repository, not published or endorsed by Pearl Research Labs. Use an official fixed release once there is one. Download them from the release [`pearl-wallet-v3.0.0-fix1`](../../releases/tag/pearl-wallet-v3.0.0-fix1).

- **Intel** (`intel-fix.yml`, [run](../../actions/runs/39470086444)): builds `oyster` natively on `macos-15-intel` from the same commit, with the Taskfile target `task build:oyster` (the official workflow runs `task build:blockchain`), Go 1.26.6 and a macOS 12.0 target, and replaces `oyster-darwin-x64` in the official Intel DMG. The other 93 regular files in the app are byte-identical to the official ones (symlinks were not compared; the DMG container is rebuilt). Needs macOS 12 or later (Go 1.26), while the official app states 10.15.
- **Apple Silicon** (`arm64-resign.yml`, [run](../../actions/runs/39476343050)): re-signs the whole official app ad hoc (`codesign --force --deep --sign -`). 84 files are byte-identical (any Mach-O files that `codesign --deep` did not re-sign are among them), 10 Mach-O binaries differ only in their code signature (`scripts/macho-same-code.py`), and 9 `_CodeSignature` files are new or changed. A downloaded copy then gets "Not Opened" instead of "damaged". Apple's `syspolicy_check` also reports "Internal Xprotect Error" for it; its meaning is not clear to us.
- Checked on fresh runners with the same checks as the official DMGs ([Intel recheck](../../actions/runs/39475598457)): the apps launch and their bundled oyster passes the wallet test. The recheck and the re-sign run show as failed only because of the relaunch-after-`xattr` step (see Gatekeeper above).

| File | SHA-256 |
|---|---|
| `Pearl-Wallet-3.0.0-intel-fixed.dmg` | `dc0dd87dbca44036ec6d8d8fc517f436d386c827a2ea6006e457e47918ffaa32` |
| `Pearl-Wallet-3.0.0-arm64-resigned.dmg` | `7ce2fac11976ca55d233521c40ebebf27954154106f3511618e22adf6fb47a85` |
| `oyster-darwin-x64` (x86_64, macOS 12+) | `7a8cf8bb60e1e40846d45bbf2d03b2a0703a650f0bd32135127a350f29be3753` |

To open either on macOS: copy the app to Applications and, before opening it for the first time, run `xattr -dr com.apple.quarantine "/Applications/Pearl Wallet.app"` (tested, see Gatekeeper above).

**Not tested**: the app's own wallet screens on any platform (creating or restoring a wallet in the UI; only the bundled oyster was tested from the command line), real Macs and PCs (only GitHub's macOS 15.7.9 and Windows Server 2025 runners), other macOS versions (older or newer, such as macOS 26), sending coins.

## Notes

- English is the default language here; other languages are added in this section.

<details>
<summary>中文说明</summary>

在 GitHub 的机器上核验 **官方 Pearl Wallet** 桌面钱包的发布包,重新编译 Intel Mac 版里发现坏掉的那个文件,并给 Apple 芯片版重新做临时签名(都是非官方的,见下面结论)。手动运行 `verify.yml`(输入发布 tag,默认 `pearl-wallet-v3.0.0`):

- checksums:下载全部发布文件,和发布里的 `checksums.txt`、GitHub 自己记录的 SHA-256 逐个核对。
- macos(Intel 和 Apple 芯片各一台):核对 DMG 哈希,查版本、Electron 版本、最低 macOS、架构、签名、Gatekeeper 判定和公证;把 app 拷出来装上、打开、截图,再对内置的 `oyster` 做钱包实测。
- windows:核对安装包哈希和签名,静默安装(当前用户)、打开、截图、钱包实测,最后卸载。
- 其它流程:`intel-fix.yml`、`arm64-resign.yml` 生成修复版 DMG(各自在干净机器上复测);`verify-fixed.yml` 不重编、复测已有的 Intel 修复版;`gatekeeper.yml` 测下载后打开会被怎么拦、哪种绕过办法有效;`release.yml` 从构建运行取修复版、按构建时记录的哈希核对后发布。

钱包实测按桌面钱包源码(`wallet-process.ts`)的方式启动 oyster(先 `--createfromfile`,再 `--usespv`),再用 JSON-RPC 检查:新建主网钱包得到 12 个助记词 → SPV 模式运行并生成 `prl1…` 地址(validateaddress 确认有效、属于本钱包)→ 用助记词恢复的钱包第一个地址相同 → 再新建一个钱包地址不同。只用临时钱包,结束就删。

**v3.0.0 结论(2026-10-20)**:tag `pearl-wallet-v3.0.0` = commit `837c69c5`,内置 oyster 1.5.0。三个平台的安装包哈希都和官方 checksums.txt、GitHub 记录一致;三个 app 都能打开(截图)。修复版见 Release [`pearl-wallet-v3.0.0-fix1`](../../releases/tag/pearl-wallet-v3.0.0-fix1)(非官方)。运行记录:[核验](../../actions/runs/39475603342)(显示失败:macOS Intel 任务失败,两个 macOS 任务的「清标记后重新打开」那一步也失败,见下面 Gatekeeper)、[Gatekeeper](../../actions/runs/39477056980)。

- Windows:安装包、程序、oyster 都没签名(按未签名推断很可能有 SmartScreen 提示;没测,runner 上没有模拟浏览器下载);内置 oyster 钱包实测通过。只在 Windows Server 2025 的 runner 上测过。
- Apple 芯片 Mac:主程序只有链接器自动加的临时签名,整个 app 没签,没公证;模拟浏览器下载后打开被拦,提示「已损坏,无法打开」(只有「取消」「移到废纸篓」);内置 oyster 是 arm64、minos 26.0,在 macOS 15 上能跑,钱包实测通过。
- **Intel Mac:官方包里的 oyster 是 arm64 版(sha256 3c3a464c11ca…),Intel Mac 上报「Bad CPU type」跑不起来;单独发布的 go-binaries-darwin-amd64-v1.5.0.tar.gz 里是同一个文件。** 按 app 源码,oyster 是它的钱包后端。官方 Intel 版没签名、没公证,模拟浏览器下载后打开提示「“Pearl Wallet” Not Opened」(只有「完成」「移到废纸篓」)。原因是官方流程的「macOS Intel」任务跑在 arm64 机器上、只设了 GOOS。
- **Gatekeeper 实测**(macOS 15.7.9,每次用新拷贝,官方和修复版、两种架构共四个包):第一次打开前先运行 `xattr -dr com.apple.quarantine`,四个都能打开。被拦后第一次的拦截框一直没关掉(脚本关不掉,也没模拟点「完成」),这时先 `xattr -dr` 再打开仍被拦(又弹出「Not Opened」),再 `xattr -cr` 也一样。点「完成」之后再删标记是否有效没测,「系统设置 > 隐私与安全性 > 仍要打开」也没测。
- **修复版(非官方,本仓库重新打包,不是 Pearl Research Labs 发布或认可的;官方出修复版后请用官方的)**:
  - Intel([运行](../../actions/runs/39470086444)):同一个 commit 在 Intel 机器上原生编 x86_64 oyster(Taskfile 的 `task build:oyster`,官方流程用的是 `task build:blockchain`;Go 1.26.6;最低 macOS 12,官方 app 标的是 10.15),只替换这一个文件,app 内其余 93 个普通文件逐字节不变(没比符号链接;DMG 外壳是重新打的)。`Pearl-Wallet-3.0.0-intel-fixed.dmg` sha256 `dc0dd87dbca44036ec6d8d8fc517f436d386c827a2ea6006e457e47918ffaa32`;`oyster-darwin-x64` sha256 `7a8cf8bb60e1e40846d45bbf2d03b2a0703a650f0bd32135127a350f29be3753`。
  - Apple 芯片([运行](../../actions/runs/39476343050)):整个 app 重新做临时签名;84 个文件逐字节相同(没被重签的程序文件也算在里面),10 个程序文件只有签名不同,9 个 `_CodeSignature` 文件新增或改动。下载后被拦时的提示从「已损坏」变成「Not Opened」。苹果的 `syspolicy_check` 对它还报了「Internal Xprotect Error」,含义不清楚。`Pearl-Wallet-3.0.0-arm64-resigned.dmg` sha256 `7ce2fac11976ca55d233521c40ebebf27954154106f3511618e22adf6fb47a85`。
  - 在干净的机器上用同样的检查复测([Intel 复测](../../actions/runs/39475598457)):app 能打开,内置 oyster 钱包实测通过。复测和重签两次运行显示失败,只是因为「清标记后重新打开」那一步(见上面 Gatekeeper)。
  - 打开方法:把 app 拷进「应用程序」,**第一次打开之前**运行 `xattr -dr com.apple.quarantine "/Applications/Pearl Wallet.app"`。
- 没测过:任何平台上 app 自己的钱包界面(在界面里新建或恢复钱包;只从命令行测了内置 oyster)、真机(只用了 GitHub 的 macOS 15.7.9 和 Windows Server 2025 机器)、其它版本的 macOS(更老的或更新的,比如 macOS 26)、实际转币。

</details>
