# How to Build and Install Gen4 Spinning on iPhone

Follow these steps exactly on a MacBook.

---

## Step 1 - Install Homebrew

Open the **Terminal** app on the Mac and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

If Homebrew is already installed, skip this step.

---

## Step 2 - Install XcodeGen

```bash
brew install xcodegen
```

---

## Step 3 - Install Xcode

1. Open the **App Store** on the Mac
2. Search for **Xcode**
3. Click **Get** and wait for it to download and install (around 10 GB)
4. After install, open Xcode once and accept the license agreement

---

## Step 4 - Clone the Repository

In Terminal, run:

```bash
git clone https://github.com/Jeeva-Embedded/Gen4_Kotlin_App_ios.git
cd Gen4_Kotlin_App_ios
```

---

## Step 5 - Generate the Xcode Project

```bash
xcodegen generate
```

This creates the `Gen4Spinning.xcodeproj` file.

---

## Step 6 - Open in Xcode

```bash
open Gen4Spinning.xcodeproj
```

---

## Step 7 - Sign In with Apple ID

1. In Xcode go to **Xcode > Settings** (or press Cmd+,)
2. Click the **Accounts** tab
3. Click **+** at the bottom left
4. Choose **Apple ID** and sign in (a free Apple ID works)

---

## Step 8 - Set the Signing Team

1. In Xcode click **Gen4Spinning** in the left sidebar (the blue project icon)
2. Click the **Gen4Spinning** target under TARGETS
3. Go to the **Signing & Capabilities** tab
4. Under **Team** select your Apple ID from the dropdown

---

## Step 9 - Connect iPhone and Run

1. Connect the iPhone to the Mac with a USB cable
2. On the iPhone tap **Trust** if a popup appears and enter the passcode
3. In Xcode click the device selector at the top and choose the connected iPhone
4. Press **Cmd+R** or click the **Play** button
5. The app will build and install on the iPhone automatically

> **Untrusted Developer error on iPhone?**
> Go to **Settings > General > VPN & Device Management**
> Find your Apple ID and tap **Trust**, then open the app again

---

## All Terminal Commands in Order

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install xcodegen
git clone https://github.com/Jeeva-Embedded/Gen4_Kotlin_App_ios.git
cd Gen4_Kotlin_App_ios
xcodegen generate
open Gen4Spinning.xcodeproj
```

Then set the Team in Xcode and press **Cmd+R** with the iPhone connected.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `xcodegen: command not found` | Run `brew install xcodegen` again and restart Terminal |
| `No such file: Gen4Spinning.xcodeproj` | Run `xcodegen generate` inside the `Gen4_Kotlin_App_ios` folder |
| No Team options in dropdown | Go to Xcode > Settings > Accounts and sign in with an Apple ID |
| Untrusted Developer on iPhone | Settings > General > VPN & Device Management > tap your Apple ID > Trust |
| iPhone not showing in Xcode | Unlock the iPhone, reconnect USB, and tap Trust on the iPhone |
| Build failed: Signing error | Make sure a Team is selected under Signing & Capabilities |