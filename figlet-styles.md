# Figlet Font Styles and Settings Reference

## Getting Non-Interactive Man Pages

Use `man -P cat figlet` to print the entire manual page at once without interactive mode.

---

## Basic Usage

```bash
figlet "Your Text"          # Default font (usually 'standard')
figlet -f script "Text"     # Specify different font
figlet -c "Centered text"   # Center alignment
```

---

## Font Selection

### Common Built-in Fonts

| Font | Style | Best For |
|------|-------|----------|
| `standard` | Default ASCII | General use |
| `big` | Large block capitals | Headings, titles |
| `slant` | Slanted letters | Emphasized text |
| `script` | Cursive style | Elegant signatures |
| `digital` | Grid-style blocks | Tech/terminal look |
| `shadow` | Drop shadow effect | 3D-ish appearance |
| `lean` | Thin lines only (`/`, `_`) | Minimalist design |
| **`thick`** | **Thicker ASCII characters** | **Boxy, substantial look** |
| `block` | Thick vertical blocks | Bold block letters |
| `broadway` | Decorative capitals | Big impact titles |

### Font Commands

```bash
figlist                              # List all available fonts
figlet -I3                          # Show current font name
figlet -d /path/to/fonts -f myfont  # Use custom font directory
```

---

## Justification Options

| Flag | Effect |
|------|--------|
| `-c` | Center horizontally |
| `-l` | Flush-left (default for LTR) |
| `-r` | Flush-right (default for RTL) |
| `-x` | Auto-detect based on text direction |

Examples:
```bash
figlet -c "Centered"     # Centered output
figlet -r "Right aligned"
```

---

## Output Width Control

| Flag | Effect |
|------|--------|
| `-t` | Use terminal width (auto) |
| `-w N` | Set specific width in columns |
| `-w 1` | Put each character on separate line |

Examples:
```bash
figlet -t "Fits terminal"    # Auto-detects your terminal width
figlet -w 120 "Wide output"
figlet -w 1 "Vertical text"  # One char per line
```

---

## Text Direction

| Flag | Effect |
|------|--------|
| `-L` | Force left-to-right |
| `-R` | Force right-to-right |
| `-X` | Use font's built-in direction (default) |

Example:
```bash
figlet -L "English text"      # Left-to-right
figlet -R "Hebrew font"       # Right-to-left
```

---

## Spacing/Smushing Modes

These control how characters connect to each other:

| Flag | Effect | When to Use |
|------|--------|-------------|
| `-s` (default) | Smush characters, remove overlapping parts | Most cases - compact output |
| `-S` | Aggressive smushing (overrides font defaults) | Force maximum compaction |
| `-k` | Kerning - remove blanks but don't smush | Keep character shapes intact |
| `-W` | Full width - display at max width | Variable-width fonts |
| `-o` | Overlap mode - basic kerning with removal | Manual spacing control |

Examples:
```bash
figlet "Smushed (default)"           # Compact, connected
figlet -k "Kerned (touching)"        # Touching but not merged
figlet -W "Full width characters"    # Maximum spacing
```

### Layout Mode (`-m`)

Use numeric layout modes 1-63 for fine control:

| Flag | Equivalent |
|------|-----------|
| `-m 0` | `-k` (kerning) |
| `-m -1` | `-W` (full width) |
| `-m -2` | `-s` (smushing) |

Example:
```bash
figlet -m 3 "Custom layout"
```

---

## Control Files

Control files map input characters to other output characters, useful for:

- Character set translation (Latin-2 through Latin-5)
- Cyrillic support
- Hebrew character mapping
- Custom substitutions

```bash
figlet -C utf8 < unicode.txt        # UTF-8 input
figlet -C 8859-5 "Russian text"    # Russian/Cyrillic
```

Common control files:
- `utf8` - UTF-8 Unicode support
- `8859-2` through `8859-9` - ISO Latin character sets
- `koi8r` - Cyrillic KOI8-R encoding
- `jis0201` - Japanese JIS X 0201

---

## Information Options

| Flag | Output |
|------|--------|
| `-v` | Version and copyright info |
| `-I1` | Font name being used |
| `-I2` | Default font directory path |
| `-I3` | Version number (e.g., 20205 for v2.2.5) |
| `-I4` | Output width that will be used |

Examples:
```bash
figlet -v              # Version info
figlet -I1             # Current font name
figlet -I3             # Numeric version (useful for scripts)
```

---

## Boxier Fonts (Thick Characters)

For fonts that use blocky, substantial characters instead of thin `|`, `/`, `-` lines:

### Recommended "Boxy" Fonts

**1. `thick`** - Uses heavier ASCII characters (`8`, `d`, `p`, `w`) for a bolder look
```bash
figlet -f thick "THICK STYLE"
```

**2. `digital`** - Grid-style with borders (uses `+`, `-`, `|`)
```bash
figlet -f digital "DIGITAL"
# Output: +-+-+-+-+
         \|D|i|g|i|t|a|l|
         +-+-+-+-+
```

**3. `broadway`** - Thick, decorative capital letters with fill characters
```bash
figlet -f broadway "BROADWAY"
```

**4. `big`** - Bold uppercase only (large blocky capitals)
```bash
figlet -f big "BIG STYLE"
```

### Finding More Box Fonts

```bash
# Search available fonts for boxy styles
figlist | grep -iE "(bold|heavy|fat|block)"

# Get font directory location
figlet -I2
```

---

## Practical Examples

### Email Signature (Lean + tr)
```bash
figlet -f lean "Your Name" | tr '_/' '()'
```

### Terminal-Style Display
```bash
figlet -f digital "System Status"
```

### Centered, Terminal-Width Output
```bash
figlet -t -c "Welcome Message"
```

### Multi-line Paragraph
```bash
figlet -p < paragraphs.txt     # Paragraph mode preserves line breaks smartly
```

### Kerned Text (Characters touch but don't merge)
```bash
figlet -k -f script "Elegant Signature"
```

### Bold, Boxy Text
```bash
figlet -f thick "IMPORTANT NOTICE"
```

---

## Environment Variables

| Variable | Effect |
|----------|--------|
| `FIGLETDIR` | Custom font directory path |

Example:
```bash
export FIGLETDIR="/path/to/custom/fonts"
figlet "Uses custom fonts"
```

---

## Font Storage

- Fonts are stored as `.flf` files (FIGlet Font format)
- Can be compressed with zip (rename to `.flf`)
- Default location: `/usr/share/figlet/fonts` or `/opt/homebrew/Cellar/figlet/*/share/figlet/fonts`
- Download additional fonts from http://www.figlet.org/fonts.html

---

## Getting Help

```bash
man -P cat figlet           # Full manual (non-interactive)
figlet -v                   # Version info
figlist                     # List all fonts
```
