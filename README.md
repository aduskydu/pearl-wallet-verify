# pearl-wallet-verify

Checks the **official Pearl Wallet** desktop release from [pearl-research-labs/pearl](https://github.com/pearl-research-labs/pearl) on GitHub's own machines, without building anything.

`.github/workflows/verify.yml` (run by hand, input: the release tag, default `pearl-wallet-v3.0.0`):

- **checksums** (Ubuntu): downloads every asset of the release and checks each one against the release's `checksums.txt` and against GitHub's own SHA-256 digest of the upload.
- **macos** (Intel `macos-15-intel` and Apple Silicon `macos-15`): checks the DMG hash, then reports the app and Electron versions, the minimum macOS, the architectures, the code signature, the Gatekeeper verdict and the notarization ticket; copies the app out of the DMG, launches it, takes a screenshot, and runs the wallet test below on the bundled `oyster`.
- **windows** (`windows-latest`): checks the installer hash and Authenticode signatures, installs silently (per user), launches the app, takes a screenshot, runs the wallet test on the bundled `oyster`, then uninstalls.

Wallet test (`scripts/oyster-smoke.sh`), the same flow the desktop app uses: a new mainnet wallet from `--createfromfile` prints a 12-word mnemonic → the wallet runs in SPV mode and returns a `prl1…` address that `validateaddress` reports as valid and owned → a wallet restored from the mnemonic returns the same first address → a second new wallet returns a different one. Throwaway wallets only, deleted at the end; the SPV progress against the live network is reported for information.

Results: each run's Summary page, plus the `macos-x86_64`, `macos-arm64` and `windows` artifacts (report and screenshot).

## Notes

- English is the default language here; other languages are added in this section.

<details>
<summary>中文说明</summary>

在 GitHub 的机器上核验 **官方 Pearl Wallet** 桌面钱包的发布包,不自己编译。手动运行 `verify.yml`(输入发布 tag,默认 `pearl-wallet-v3.0.0`):

- checksums:下载全部发布文件,和发布里的 `checksums.txt`、GitHub 自己记录的 SHA-256 逐个核对。
- macos(Intel 和 Apple 芯片各一台):核对 DMG 哈希,查版本、Electron 版本、最低 macOS、架构、签名、Gatekeeper 判定和公证;把 app 拷出来装上、打开、截图,再对内置的 `oyster` 做钱包实测。
- windows:核对安装包哈希和签名,静默安装(当前用户)、打开、截图、钱包实测,最后卸载。

钱包实测和桌面钱包的流程一样:新建主网钱包得到 12 个助记词 → SPV 模式运行并生成 `prl1…` 地址(validateaddress 确认有效、属于本钱包)→ 用助记词恢复的钱包第一个地址相同 → 再新建一个钱包地址不同。只用临时钱包,结束就删。

</details>
