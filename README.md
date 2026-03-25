# QueuePaste

<p align="center">
  <img src="QueuePaste/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="QueuePaste Logo" width="128">
</p>

[![macOS](https://img.shields.io/badge/macOS-15.0+-black.svg?style=flat&logo=apple)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10+-F05138.svg?style=flat&logo=swift)](https://developer.apple.com/swift/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**QueuePaste** is a native, lightweight, and highly performant utility for macOS designed to sequentially paste items from a loaded list across any target application with a single global hotkey. It is engineered with robust security, state preservation, and zero-context-switching in mind.

QueuePaste was built to eliminate the repetitive strain and error-prone nature of copying and pasting hundreds of text payloads repeatedly into target applications (e.g., rigid databases, internal campus portals, and restricted CRM platforms) that do not support automated API integration.

---

## Key Features

- **Global Execution:** Seamlessly register `⌥ Space` across macOS to securely advance paste buffers in any foreground application.
- **HUD (Heads-Up Display):** A frictionless, non-intrusive floating `NSWindow` built securely above standard software layers. It persists target tracking without stealing key focus.
- **Deep System Integration:** Leverages raw `CGEvent` synthesis coupled with `NSPasteboard` automation for guaranteed accuracy.
- **State Continuity:** Built-in fault tolerance. Queue sequences and pointer indexes are atomically sequenced into `UserDefaults`, ensuring zero data loss during application restarts or crashes.
- **Data Ingestion:** Instantaneous processing of raw multi-line Strings and comma-separated `.csv` structures.

---

## System Architecture

QueuePaste adheres strictly to the **MVVM (Model-View-ViewModel)** architectural pattern, leveraging Apple's modern concurrency paradigms (`@MainActor`) and the Swift 5.10 `@Observable` macro to power real-time UI synchrony.

### Sub-Domain Documentation

For an engineering deep route into the internal mechanisms of this engine, please consult the directory-level Readmes:

- **[Models (Data Domain)](QueuePaste/Models/README.md):** The primitives governing state logic, Codable continuity payloads, and session structures.
- **[ViewModels (State Presentation)](QueuePaste/ViewModels/README.md):** The Source of Truth acting as the principal conductor bridging user interactions to systemic low-level execution.
- **[Views (SwiftUI Interfae)](QueuePaste/Views/README.md):** An overview of the Windowing infrastructure, declarative routing, and HUD deployment.
- **[Services (AppKit/CoreFoundation Int)](QueuePaste/Services/README.md):** Pure Swift wrappers bridging system accessibility rights, memory pasteboards, and `CGEvent` tap interceptors.

---

## Getting Started

### Prerequisites

To compile and execute this macOS binary, your environment must meet the following criteria:

- **macOS:** version 13.0 (Ventura) or later.
- **Xcode:** version 15.0 or later (with macOS SDK 14.0+).
- **Swift:** version 5.10.

### Build Instructions

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/tmarhguy/QueuePaste.git
   cd QueuePaste
   ```

2. **Open the Project:**
   Locate and open the Xcode Project file (`QueuePaste.xcodeproj`) to instantiate the workspace.
   ```bash
   open QueuePaste.xcodeproj
   ```

3. **Compile & Run:**
   - Select your valid local internal Mac hardware as the active run destination.
   - Execute **Product > Run** (`⌘R`).

### Permissions and Accessibility

Due to the nature of global hotkey interceptions and keystroke simulations, QueuePaste fundamentally relies on macOS Accessibility frameworks.
Upon initial invocation of the global execution hotkey (`⌥Space`), the application will transparently prompt standard OS security dialogs to grant authorization. 

If this bypasses silently, engineers can enforce the configuration via:
**System Settings > Privacy & Security > Accessibility > [Toggle QueuePaste On]**

---

## Visual Tour

QueuePaste is composed of lightweight utility panes. 

### Foundation Loading
<p align="left">
  <img src="QueuePaste/images/start-page.png" alt="Start Page" width="350">
  <img src="QueuePaste/images/example-list-page.png" alt="Example List" width="350">
</p>

### Execution Monitoring Layer
<p align="center">
  <img src="QueuePaste/images/queue-page.png" alt="Queue Page" width="450">
  <img src="QueuePaste/images/hud-page.png" alt="HUD Overlay" width="350">
</p>

### Global Context Management
<p align="center">
  <img src="QueuePaste/images/control-page.png" alt="Control Page" width="500">
</p>

---

## Deployment & Distribution

QueuePaste is currently distributed as an ongoing utility designed initially to fulfill institutional obligations. Continuous architectural refinements are anticipated. Standalone `.dmg` packaging is generated via standard Xcode Organizer archiving protocols against Apple Developer ID certifications.

---

## License

This architecture is released securely under the **MIT License**.
See [LICENSE](LICENSE) for categorical declarations.

---

## About the Author

**Hi, I'm Tyrone Marhguy** (Penn Engineering '28). I build systems from first principles. Whether designing discrete-transistor ALUs with 3,400+ transistors, routing ASIC tapeouts, or architecting 3D websites and native macOS software, my goal is to bridge the gap between raw silicon and elegant desktop utilities.

<div align="center">

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/tmarhguy) [![Email](https://img.shields.io/badge/Email-EA4335?style=for-the-badge&logo=gmail&logoColor=white)](mailto:tmarhguy@seas.upenn.edu) [![Portfolio](https://img.shields.io/badge/Portfolio-000000?style=for-the-badge&logo=githubpages&logoColor=white)](https://tmarhguy.com) [![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/tmarhguy)

</div>
