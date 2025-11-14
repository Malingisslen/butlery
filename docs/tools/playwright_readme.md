# Playwright MCP Integration Guide

**Version**: 0.0.45
**Project**: Butlery
**Last Updated**: November 2025

## Overview

Playwright MCP is a Model Context Protocol (MCP) server that provides browser automation capabilities using [Playwright](https://playwright.dev). It enables AI assistants (like Claude Code) to interact with web pages through structured accessibility snapshots, bypassing the need for screenshots or vision models.

### Key Benefits

- **Fast and Lightweight**: Uses Playwright's accessibility tree, not pixel-based input
- **LLM-Friendly**: No vision models needed, operates purely on structured data
- **Deterministic**: Avoids ambiguity common with screenshot-based approaches
- **Integration-Ready**: Works seamlessly with Claude Code and other MCP clients

---

## Installation

### For Butlery Project (Claude Code)

The Playwright MCP server is already installed and configured for this project.

**Configuration location**: `.claude/settings.json`

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

**Permissions configured**: `"mcp__playwright__*"` in allow list (all Playwright tools pre-approved)

---

## Use Cases for Butlery

### 1. Web Scraping for Recipe Import
Extract recipes from cooking websites automatically:
```
User: "Go to allrecipes.com and extract the ingredients from the first recipe"
Claude: [Uses Playwright to navigate, extract, and format data]
```

### 2. Testing Web Features
Test Butlery's web interface (if applicable):
```
User: "Navigate to our staging site and verify the login form works"
Claude: [Tests form fields, validates behavior]
```

### 3. Competitive Analysis
Analyze competitor recipe apps:
```
User: "Check how Tasty.co displays their recipe cards"
Claude: [Screenshots, analyzes layout, extracts patterns]
```

### 4. Documentation & Screenshots
Capture UI states for documentation:
```
User: "Take screenshots of each step in the recipe creation flow"
Claude: [Navigates through flow, captures each screen]
```

### 5. Data Validation
Verify external API responses:
```
User: "Navigate to this API endpoint and show me the response"
Claude: [Fetches, formats, displays JSON data]
```

---

## Available Tools

### Core Automation (18 tools)

**Navigation:**
- `browser_navigate` - Go to a URL
- `browser_navigate_back` - Go back to previous page

**Interaction:**
- `browser_click` - Click on elements (single/double, with modifiers)
- `browser_type` - Type text into fields (with submit option)
- `browser_hover` - Hover over elements
- `browser_drag` - Drag and drop between elements
- `browser_press_key` - Press keyboard keys (e.g., ArrowLeft, Enter, a)

**Forms:**
- `browser_fill_form` - Fill multiple form fields at once
- `browser_select_option` - Select dropdown options
- `browser_file_upload` - Upload files

**Information:**
- `browser_snapshot` - Capture accessibility snapshot (preferred for actions)
- `browser_take_screenshot` - Capture visual screenshot (PNG/JPEG)
- `browser_console_messages` - Get console output (including errors)
- `browser_network_requests` - List all network requests
- `browser_evaluate` - Execute JavaScript on page

**Utilities:**
- `browser_wait_for` - Wait for text to appear/disappear or time to pass
- `browser_handle_dialog` - Accept/dismiss browser dialogs
- `browser_resize` - Resize browser window
- `browser_close` - Close the browser

### Tab Management
- `browser_tabs` - List, create, close, or select tabs

### Optional Capabilities

Enable with `--caps` flag in configuration:

**Vision** (`--caps=vision`):
- `browser_mouse_click_xy` - Click at specific coordinates
- `browser_mouse_drag_xy` - Drag to coordinates
- `browser_mouse_move_xy` - Move mouse to coordinates

**PDF** (`--caps=pdf`):
- `browser_pdf_save` - Save page as PDF

**Testing** (`--caps=testing`):
- `browser_generate_locator` - Generate test locators
- `browser_verify_element_visible` - Assert element visibility
- `browser_verify_list_visible` - Assert list contents
- `browser_verify_text_visible` - Assert text presence
- `browser_verify_value` - Assert element values

**Tracing** (`--caps=tracing`):
- `browser_start_tracing` - Start recording trace
- `browser_stop_tracing` - Stop recording trace

---

## Configuration Options

### Current Setup (Persistent Profile)

**Mode**: Persistent browser profile (default)
**Location**: `C:\Users\malla\AppData\Local\ms-playwright\mcp-chrome-profile`

**What this means**:
- Browser remembers cookies, logins, and settings between sessions
- Accepted cookie consents persist
- No need to re-authenticate on websites
- Profile can be deleted to clear state

### Alternative Modes

#### Isolated Mode
For testing scenarios where you want clean state:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--isolated",
        "--storage-state=path/to/storage.json"
      ]
    }
  }
}
```

**Use cases**: E2E testing, clean environment testing

#### Browser Extension Mode
Connect to existing browser tabs:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--extension"
      ]
    }
  }
}
```

**Requires**: Playwright MCP Bridge extension (Chrome/Edge)
**Use cases**: Leverage existing logged-in sessions

---

## Common Configuration Flags

Add these to the `"args"` array in configuration:

### Browser Selection
```bash
--browser chrome          # Use Chrome
--browser firefox         # Use Firefox
--browser webkit          # Use WebKit (Safari engine)
--browser msedge          # Use Microsoft Edge
```

### Display Mode
```bash
--headless                # Run without visible browser (faster)
```
*Note: Default is headed (visible browser)*

### Viewport & Device
```bash
--viewport-size 1280x720  # Set browser window size
--device "iPhone 15"      # Emulate mobile device
```

### Privacy & Security
```bash
--ignore-https-errors     # Ignore SSL certificate errors
--grant-permissions geolocation,clipboard-read  # Grant permissions
```

### Output & Debugging
```bash
--output-dir ./screenshots  # Directory for screenshots/PDFs
--save-trace               # Save Playwright trace for debugging
--save-video 800x600       # Record session video
--save-session             # Save session for replay
```

### Network
```bash
--proxy-server http://proxy:3128      # Use HTTP proxy
--proxy-bypass .com,chromium.org      # Bypass proxy for domains
```

### Timeouts
```bash
--timeout-action 5000      # Action timeout (ms) - default 5000
--timeout-navigation 60000 # Navigation timeout (ms) - default 60000
```

---

## Example Workflows

### 1. Recipe Scraping Workflow

```
User: "Go to https://www.allrecipes.com/recipe/12345/ and extract the recipe"

Claude Process:
1. browser_navigate to URL
2. browser_snapshot to get page structure
3. browser_evaluate to extract ingredients JSON
4. Format and present data to user
```

### 2. Testing Butlery Web App

```
User: "Test the login flow on staging.butlery.app"

Claude Process:
1. browser_navigate to staging site
2. browser_type username into email field
3. browser_type password into password field
4. browser_click on "Logga in" button
5. browser_wait_for to confirm redirect
6. browser_take_screenshot to verify logged-in state
```

### 3. Competitive Analysis

```
User: "Analyze how Tasty displays their recipe ingredients"

Claude Process:
1. browser_navigate to tasty.co
2. browser_take_screenshot of homepage
3. browser_click on first recipe
4. browser_snapshot to analyze ingredient layout
5. Summarize findings with screenshots
```

---

## Best Practices

### 1. Use Snapshots for Actions
- ✅ `browser_snapshot` - For understanding page structure and taking actions
- ⚠️ `browser_take_screenshot` - For visual captures only (cannot interact with screenshots)

### 2. Wait for Elements
Always wait for dynamic content:
```
browser_wait_for text="Recipe loaded"
```

### 3. Handle Errors Gracefully
Check console messages for errors:
```
browser_console_messages onlyErrors=true
```

### 4. Network Monitoring
Track API calls during page load:
```
browser_network_requests
```

### 5. Clean Up
Close browser when done with intensive sessions:
```
browser_close
```

---

## Troubleshooting

### Issue: Browser not found error
**Solution**: Install browser
```bash
npx @playwright/mcp@latest --browser chrome
# Then run:
mcp__playwright__browser_install
```

### Issue: Timeout errors
**Solution**: Increase timeout
```json
"args": ["@playwright/mcp@latest", "--timeout-navigation", "90000"]
```

### Issue: Permission denied errors
**Solution**: Check `.claude/settings.json` has `"mcp__playwright__*"` in allow list

### Issue: Cookie consent popups keep appearing
**Solution**: Your persistent profile is working! Accepted consents are saved automatically.

### Issue: Need to clear browser data
**Solution**: Delete the profile directory:
```
C:\Users\malla\AppData\Local\ms-playwright\mcp-chrome-profile
```

---

## Advanced Usage

### Configuration File

Create `playwright-config.json`:

```json
{
  "browser": {
    "browserName": "chromium",
    "isolated": false,
    "launchOptions": {
      "headless": false,
      "channel": "chrome"
    },
    "contextOptions": {
      "viewport": {
        "width": 1280,
        "height": 720
      }
    }
  },
  "capabilities": ["pdf", "testing"],
  "outputDir": "./playwright-output",
  "network": {
    "blockedOrigins": ["*ads*", "*analytics*"]
  }
}
```

Use with:
```json
"args": ["@playwright/mcp@latest", "--config", "./playwright-config.json"]
```

### Running as Standalone Server

For remote access or headless systems:

```bash
npx @playwright/mcp@latest --port 8931
```

Then connect via HTTP:
```json
{
  "mcpServers": {
    "playwright": {
      "url": "http://localhost:8931/mcp"
    }
  }
}
```

---

## Resources

- **Official Repo**: [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp)
- **Playwright Docs**: [playwright.dev](https://playwright.dev)
- **MCP Documentation**: [modelcontextprotocol.io](https://modelcontextprotocol.io)
- **Issue Tracker**: [GitHub Issues](https://github.com/microsoft/playwright-mcp/issues)

---

## Version History

- **v0.0.45** (Oct 31, 2025) - Latest stable release
- **Installation Date**: November 7, 2025
- **Configured By**: Butlery Team

---

## Notes for Butlery Team

### Current Setup
- ✅ Installed and configured in Claude Code
- ✅ Persistent profile mode (cookies/sessions saved)
- ✅ All tools pre-approved (no permission prompts)
- ✅ Default browser: Chrome

### Recommended Use Cases
1. **Recipe Import**: Scrape recipes from popular cooking sites
2. **Website Testing**: Validate Butlery web app functionality
3. **Documentation**: Capture UI screenshots for guides
4. **Research**: Analyze competitor features
5. **API Testing**: Validate external API integrations

### Future Enhancements
- Consider enabling `--caps=pdf` for saving recipes as PDFs
- Consider `--caps=testing` for automated E2E tests
- Create custom scraping scripts for common recipe sites
- Document recipe site scraping patterns

---

*This document is part of the Butlery development toolkit. For questions, contact the development team.*
