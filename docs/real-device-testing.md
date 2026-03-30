# Real-Device Testing Guide

This document explains how to set up, run, and test FaceBridge on physical Mac and iPhone hardware.

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Mac** | macOS 14.0 (Sonoma) or later |
| **iPhone** | iOS 17.0 or later, with Face ID or Touch ID |
| **Xcode** | 15.0 or later |
| **Apple Developer Account** | Required for code signing on physical devices |
| **Network** | Both devices on the same local network, or within BLE range |

> **Secure Enclave.** FaceBridge uses Secure Enclave key generation on physical iOS devices. The iOS Simulator uses a software key fallback and cannot test hardware-backed biometric flows.

## Building

### Mac App

1. Open the project in Xcode (`Package.swift` or `FaceBridge.xcodeproj`)
2. Select the **FaceBridgeMacApp** scheme
3. Set the signing team to your Apple Developer account
4. Build and run (Cmd+R)

### iPhone App

1. Select the **FaceBridgeiOSApp** scheme
2. Select your physical iPhone as the run destination
3. Set the signing team and bundle identifier
4. Build and run (Cmd+R)

### Mac Agent (Headless)

```bash
swift build --product FaceBridgeMacAgent
.build/debug/FaceBridgeMacAgent
```

The agent runs as a background process, listening for authorization requests.

## Pairing

1. Launch both apps on Mac and iPhone
2. On the Mac, navigate to the **Devices** section
3. The Mac generates a 6-digit pairing code
4. On the iPhone, enter the pairing code
5. Both devices exchange signed identities and persist trust in Keychain
6. The Mac dashboard should show the iPhone as a **Trusted Device**
7. The iPhone dashboard should show the Mac as a **Trusted Device**

## Testing Authorization

### Unlock Secure Vault

1. On the Mac dashboard, locate **Protected Actions**
2. Tap **Unlock Secure Vault**
3. The Mac sends a signed authorization request to the iPhone
4. The iPhone displays an authorization prompt: "Unlock Secure Vault"
5. Authenticate with Face ID on the iPhone
6. The iPhone signs the response and sends it back
7. The Mac verifies the response and unlocks the vault panel

### Run Protected Command

1. On the Mac dashboard, tap **Run Protected Command**
2. Approve with Face ID on the iPhone
3. The Mac executes the predefined command (opens Safari)
4. The Mac UI shows the command result

### Reveal Protected File

1. On the Mac dashboard, tap **Reveal Protected File**
2. Approve with Face ID on the iPhone
3. The Mac UI reveals the hidden content

### Expected Results

After each successful authorization:

| What you see | Where |
|--------------|-------|
| Authorization prompt with action name and device identity | iPhone |
| Face ID system dialog | iPhone |
| "Approved" confirmation with checkmark | iPhone |
| Action status changes from "Pending" to "Approved" | Mac |
| Protected content is revealed or command executes | Mac |

After a denied authorization:

| What you see | Where |
|--------------|-------|
| "Denied" status on the authorization prompt | iPhone |
| Action status changes to "Denied" | Mac |
| No protected content is revealed | Mac |

### Denial Flow

1. Trigger any protected action on the Mac
2. On the iPhone, tap **Deny** instead of authenticating
3. The Mac should show a "Denied" status

### Expiration Flow

1. Trigger a protected action on the Mac
2. Wait for the request to expire without responding on the iPhone (default: 60 seconds)
3. The Mac should show an expiration status

## Authorization Lab

In developer mode, the Mac app includes an **Authorization Lab** panel with dedicated buttons to test each flow individually, inspect transport state, and send custom authorization requests.

## Common Issues

### "No Trusted Device Connected"

- Verify both devices are on the same network or within BLE range
- Check that pairing completed successfully on both sides
- Try removing and re-pairing the devices

### "Transport Unavailable"

- The transport connection may have dropped
- Relaunch both apps to re-establish transport connections
- Check that the Mac's local network permissions allow Bonjour discovery

### "Send Failed"

- The selected transport route may be stale
- Check the Mac debug console for routing decisions
- Verify the iPhone app is in the foreground and actively listening

### Duplicate Device Entries

- If the iPhone app was reinstalled, a new device identity was generated
- Remove stale entries from the Devices section on both platforms
- Re-pair the devices

### Face ID Not Prompting

- Verify Face ID is enrolled on the iPhone (Settings → Face ID & Passcode)
- Check that the FaceBridge app has not been denied biometric access
- Ensure the authorization request arrived (check iPhone debug console)

### Signature Verification Failed

- This may indicate a timestamp precision mismatch or stale trust entry
- Remove the paired device and re-pair
- Check that both apps are running the same build

## Network Configuration

FaceBridge uses Bonjour for local network discovery:

- **Service type:** `_facebridge._tcp`
- **Port:** Assigned dynamically by the system
- **TLS:** Enabled by default

Ensure your network allows:

- mDNS/Bonjour traffic (UDP port 5353)
- Direct TCP connections between devices on the local network

Corporate networks with client isolation may block device discovery.

## Debug Console

Both apps include a debug console (accessible in developer mode) that shows structured logs for:

- Transport connections and disconnections
- Device discovery events
- Authorization request routing decisions
- Signature verification results
- Error details with specific failure reasons
