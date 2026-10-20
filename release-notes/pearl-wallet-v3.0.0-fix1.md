**Unofficial.** Repackaged by this repository from the official [Pearl Wallet v3.0.0](https://github.com/pearl-research-labs/pearl/releases/tag/pearl-wallet-v3.0.0) (tag `pearl-wallet-v3.0.0`, commit `837c69c5`). Not published or endorsed by Pearl Research Labs; use an official fixed release once there is one. For Windows, use the official installer: its hash matches, it launched and its bundled `oyster` passed the wallet test on a Windows Server 2025 runner; it is unsigned and SmartScreen was not tested (see the [README](https://github.com/aduskydu/pearl-wallet-verify#results-for-pearl-wallet-v300-2026-10-20)).

| File | For | What changed | SHA-256 |
|---|---|---|---|
| `Pearl-Wallet-3.0.0-intel-fixed.dmg` | Intel Macs, macOS 12 or later | `Contents/Resources/bin/oyster-darwin-x64` rebuilt natively for x86_64 from the same commit; the official one is an arm64 build that cannot run on an Intel Mac. The other 93 regular files in the app are byte-identical to the official ones. | `dc0dd87dbca44036ec6d8d8fc517f436d386c827a2ea6006e457e47918ffaa32` |
| `Pearl-Wallet-3.0.0-arm64-resigned.dmg` | Apple Silicon Macs | The whole app is re-signed ad hoc. In the official app only the main binary carries the linker's automatic ad-hoc signature and the bundle itself is not signed, so macOS calls a downloaded copy "damaged". 84 files are byte-identical, 10 Mach-O binaries differ only in their code signature, 9 `_CodeSignature` files are new or changed. | `7ce2fac11976ca55d233521c40ebebf27954154106f3511618e22adf6fb47a85` |
| `oyster-darwin-x64` | the rebuilt Intel `oyster` on its own (x86_64, macOS 12+, version 1.5.0) | – | `7a8cf8bb60e1e40846d45bbf2d03b2a0703a650f0bd32135127a350f29be3753` |
| `SHA256SUMS.txt` | the hashes above | | |

**Checked on fresh GitHub macOS 15 runners:** each app launches, and its bundled `oyster` passes the wallet test (a new wallet gives a `prl1…` address, a wallet restored from its 12-word mnemonic gives the same address, a second new wallet gives a different one). Runs: [Intel fix](https://github.com/aduskydu/pearl-wallet-verify/actions/runs/39470086444), [Apple Silicon re-sign](https://github.com/aduskydu/pearl-wallet-verify/actions/runs/39476343050), [Intel recheck](https://github.com/aduskydu/pearl-wallet-verify/actions/runs/39475598457), [Gatekeeper](https://github.com/aduskydu/pearl-wallet-verify/actions/runs/39477056980). The re-sign and recheck runs show as failed only because of their relaunch-after-`xattr` step, explained below; launch and wallet test passed.

**Opening it on macOS.** The Intel build is not signed at all; the Apple Silicon build has only the ad-hoc signature made by this repository. Neither is notarized. (Tested on GitHub's macOS 15.7.9 runners, with the quarantine flag that a browser sets added by hand.)
- Copy the app to Applications. Before opening it for the first time, run `xattr -dr com.apple.quarantine "/Applications/Pearl Wallet.app"` in Terminal. Tested: all four builds (official and fixed, Intel and Apple Silicon) then start.
- If you open it first, macOS blocks it with "“Pearl Wallet” Not Opened". With the re-signed build this replaces the official build's "damaged" message. In our test the first dialog stayed on screen (the test could not close it, and clicking Done was not simulated); with it still open, removing the flag from that copy (`xattr -dr`, then `xattr -cr`) and opening it again was blocked again. Whether that works after clicking Done was not tested. The usual route is System Settings → Privacy & Security → Open Anyway; another is to delete the copy, copy the app again from the DMG and run the command above before opening it. Neither was tested after a blocked launch.

**Not tested:** the app's own wallet screens (creating or restoring a wallet in the app; only the bundled `oyster` was tested from the command line), real Macs, macOS versions other than 15.7.9 (older or newer, such as macOS 26), sending coins. The Intel build needs macOS 12 or later (Go 1.26); the official app states 10.15. On the re-signed Apple Silicon app, Apple's `syspolicy_check` also reports "Internal Xprotect Error" (its meaning is not clear to us; the app launched and its wallet test passed).

---

<details>
<summary>中文说明</summary>

**非官方。** 本仓库在官方 [Pearl Wallet v3.0.0](https://github.com/pearl-research-labs/pearl/releases/tag/pearl-wallet-v3.0.0)(tag `pearl-wallet-v3.0.0`,commit `837c69c5`)基础上重新打包,不是 Pearl Research Labs 发布或认可的;官方出修复版后请用官方的。Windows 请直接用官方安装包:在 Windows Server 2025 的 runner 上哈希一致、能打开、内置 oyster 钱包实测通过;它没签名,SmartScreen 没测。详见 [README](https://github.com/aduskydu/pearl-wallet-verify#results-for-pearl-wallet-v300-2026-10-20)。

- `Pearl-Wallet-3.0.0-intel-fixed.dmg`(Intel Mac,macOS 12 及以上):用同一个 commit 在 Intel 机器上原生重编 `oyster-darwin-x64`;官方的那个是 arm64 版,Intel Mac 上跑不起来。app 内其余 93 个普通文件和官方逐字节相同。sha256 `dc0dd87dbca44036ec6d8d8fc517f436d386c827a2ea6006e457e47918ffaa32`。
- `Pearl-Wallet-3.0.0-arm64-resigned.dmg`(Apple 芯片 Mac):整个 app 重新做临时签名(ad hoc)。官方 app 只有主程序带链接器自动加的临时签名,整个 app 没签,浏览器下载后 macOS 会说它「已损坏」。84 个文件逐字节相同,10 个程序文件只有签名不同,9 个 `_CodeSignature` 文件是新增或改动的。sha256 `7ce2fac11976ca55d233521c40ebebf27954154106f3511618e22adf6fb47a85`。
- `oyster-darwin-x64`:单独的 Intel 版 oyster(x86_64,macOS 12+,1.5.0),sha256 `7a8cf8bb60e1e40846d45bbf2d03b2a0703a650f0bd32135127a350f29be3753`。
- `SHA256SUMS.txt`:以上文件的哈希。

**在干净的 GitHub macOS 15 机器上检查过:** app 能打开;内置 oyster 钱包实测通过(新钱包出 `prl1…` 地址、用 12 个助记词恢复后地址相同、再新建的钱包地址不同)。运行记录:[Intel 修复](https://github.com/aduskydu/pearl-wallet-verify/actions/runs/39470086444)、[Apple 芯片重签](https://github.com/aduskydu/pearl-wallet-verify/actions/runs/39476343050)、[Intel 复测](https://github.com/aduskydu/pearl-wallet-verify/actions/runs/39475598457)、[Gatekeeper](https://github.com/aduskydu/pearl-wallet-verify/actions/runs/39477056980)。重签和复测两次运行显示失败,只是因为下面说的「清标记后重新打开」那一步;打开和钱包实测都通过。

**在 Mac 上打开:** Intel 版完全没签名;Apple 芯片版只有本仓库加的临时签名;两个都没有公证。(在 GitHub 的 macOS 15.7.9 机器上测,浏览器下载会加的隔离标记是手动加的。)
- 把 app 拷进「应用程序」。**第一次打开之前**在终端运行 `xattr -dr com.apple.quarantine "/Applications/Pearl Wallet.app"`。实测:四个包(官方和修复版,Intel 和 Apple 芯片)这样都能打开。
- 如果先打开了,macOS 会弹「“Pearl Wallet” Not Opened」拦下(重签版的提示就是这个,不再是官方版的「已损坏」)。实测时第一次弹出的拦截框没能关掉(测试没关掉它,也没模拟点「完成」);它还开着时删标记(先 `xattr -dr`、再 `xattr -cr`)再打开,这份拷贝仍被拦。点了「完成」之后再删标记是否有效没测。常规做法是「系统设置 > 隐私与安全性 > 仍要打开」;也可以删掉这份,从 DMG 重新拷一份,第一次打开前运行上面的命令。被拦之后这两种都没实测。

**没测过:** app 自己的钱包界面(在 app 里新建或恢复钱包;只从命令行测了内置 oyster)、真机、15.7.9 以外的 macOS(更老的或更新的,比如 macOS 26)、实际转币。Intel 版要 macOS 12 及以上(Go 1.26),官方 app 标的是 10.15。重签后的 Apple 芯片 app,苹果的 `syspolicy_check` 还报了「Internal Xprotect Error」(含义我们不清楚;app 能打开,钱包实测通过)。

</details>
