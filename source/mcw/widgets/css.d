module mcw.widgets.css;

import std.algorithm : canFind;
import std.conv : to;
import std.file : readText;
import std.string : indexOf, lastIndexOf, split, strip, toLower;

import bindbc.sdl;
import mcw.widgets.styling;
import mcw.widgets.widget;
import mcw.widgets.container;

class CSSException : Exception {
    this(string message) { super(message); }
}

private struct Declaration {
    string name;
    SDL_Color color;
    int[4] numbers;
}

private struct Rule {
    string kind, id;
    string[] cssClasses, states;
    int specificity;
    Declaration[] declarations;

    bool matches(Widget widget) const {
        if (kind.length && kind != "*") {
            bool found;
            for (auto info = widget.classinfo; info !is null; info = info.base) {
                auto fullName = info.name;
                auto dot = fullName.lastIndexOf('.');
                if (fullName[dot < 0 ? 0 : dot + 1 .. $] == kind) {
                    found = true;
                    break;
                }
            }
            if (!found) return false;
        }
        if (id.length && widget.styleId != id) return false;
        foreach (cssClass; cssClasses)
            if (!widget.styleClasses.canFind(cssClass)) return false;
        foreach (state; states)
            if (!widget.cssState(state)) return false;
        return true;
    }
}

/// A deliberately small CSS subset for MCW widgets. Rules are evaluated when
/// drawn, so hover, focus, pressed and disabled styles update automatically.
class StyleSheet {
    private Rule[] rules;

    static StyleSheet parse(string source) {
        auto sheet = new StyleSheet;
        string clean;
        for (size_t i = 0; i < source.length;) {
            if (i + 1 < source.length && source[i .. i + 2] == "/*") {
                auto end = source[i + 2 .. $].indexOf("*/");
                if (end < 0) throw new CSSException("Unclosed CSS comment");
                i += end + 4;
            } else clean ~= source[i++];
        }
        while (clean.strip.length) {
            auto open = clean.indexOf('{');
            auto close = clean.indexOf('}');
            if (open < 0 || close < open)
                throw new CSSException("Expected a CSS rule with { and }");
            auto selectorText = clean[0 .. open].strip;
            auto body = clean[open + 1 .. close];
            if (!selectorText.length) throw new CSSException("Empty CSS selector");
            Declaration[] declarations;
            foreach (part; body.split(';')) {
                part = part.strip;
                if (!part.length) continue;
                auto colon = part.indexOf(':');
                if (colon < 1) throw new CSSException("Expected property: value in CSS");
                declarations ~= parseDeclaration(part[0 .. colon].strip.toLower,
                    part[colon + 1 .. $].strip);
            }
            foreach (selector; selectorText.split(',')) {
                auto rule = parseSelector(selector.strip);
                rule.declarations = declarations;
                sheet.rules ~= rule;
            }
            clean = clean[close + 1 .. $];
        }
        foreach (i; 1 .. sheet.rules.length) {
            auto current = sheet.rules[i];
            size_t j = i;
            while (j > 0 && sheet.rules[j - 1].specificity > current.specificity) {
                sheet.rules[j] = sheet.rules[j - 1];
                j--;
            }
            sheet.rules[j] = current;
        }
        return sheet;
    }

    void apply(Widget root) {
        if (root is null) return;
        root.styleSheet = this;
        if (auto container = cast(Container) root) {
            foreach (child; container.children) apply(child);
            auto computed = compute(root);
            if (computed.gap >= 0) {
                if (!container.cssGapApplied)
                    container.cssBaseSpacing = container.spacing;
                container.cssGapApplied = true;
                container.spacing = computed.gap;
            } else if (container.cssGapApplied) {
                container.spacing = container.cssBaseSpacing;
                container.cssGapApplied = false;
            }
            container.adjustLayout();
        }
    }

    Style compute(Widget widget) const {
        Style result = widget.style;
        foreach (ref rule; rules) {
            if (!rule.matches(widget)) continue;
            foreach (ref declaration; rule.declarations)
                applyDeclaration(result, declaration);
        }
        return result;
    }
}

StyleSheet loadCSS(string path) {
    return StyleSheet.parse(readText(path));
}

/// Poll a CSS file from a timed event-loop wakeup. A failed read or parse
/// leaves the last successfully applied sheet in place.
class StyleSheetWatcher {
    string path;
    string lastError;
    ulong intervalMs;
    ulong revision;
    StyleSheet sheet;

    private Widget[] roots;
    private string lastSource;
    private ulong lastCheck;
    private bool checkedOnce;

    this(string path, Widget root, ulong intervalMs = 250) {
        this.path = path;
        this.intervalMs = intervalMs;
        roots ~= root;
        poll(true);
    }

    void addRoot(Widget root) {
        if (root is null) return;
        roots ~= root;
        if (sheet !is null) sheet.apply(root);
    }

    /// Returns true only after successfully applying new file contents.
    bool poll(bool force = false) {
        ulong now = SDL_GetTicks();
        if (!force && checkedOnce && now - lastCheck < intervalMs) return false;
        lastCheck = now;
        checkedOnce = true;

        string source;
        try {
            source = readText(path);
        } catch (Exception e) {
            lastError = e.msg;
            return false;
        }
        if (sheet !is null && source == lastSource) {
            lastError = "";
            return false;
        }
        StyleSheet parsed;
        try {
            parsed = StyleSheet.parse(source);
        } catch (CSSException e) {
            lastError = e.msg;
            return false;
        }
        foreach (root; roots) parsed.apply(root);
        sheet = parsed;
        lastSource = source;
        lastError = "";
        revision++;
        return true;
    }
}

private Rule parseSelector(string selector) {
    Rule rule;
    if (!selector.length) throw new CSSException("Empty CSS selector");
    size_t i;
    if (selector[0] == '*') { rule.kind = "*"; i++; }
    else if (selector[0] != '.' && selector[0] != '#' && selector[0] != ':') {
        auto start = i;
        while (i < selector.length && isIdentifier(selector[i])) i++;
        rule.kind = selector[start .. i];
        rule.specificity++;
    }
    while (i < selector.length) {
        char marker = selector[i++];
        if (marker != '.' && marker != '#' && marker != ':')
            throw new CSSException("Unsupported CSS selector: " ~ selector);
        auto start = i;
        while (i < selector.length && (isIdentifier(selector[i]) ||
                (marker == ':' && selector[i] == '-'))) i++;
        if (start == i) throw new CSSException("Empty CSS selector component");
        auto part = selector[start .. i];
        switch (marker) {
        case '.': rule.cssClasses ~= part; rule.specificity += 10; break;
        case '#': rule.id = part; rule.specificity += 100; break;
        case ':':
            if (part != "hover" && part != "focus" && part != "focus-visible" &&
                    part != "pressed" && part != "disabled" && part != "checked" &&
                    part != "selected")
                throw new CSSException("Unsupported CSS state: " ~ part);
            rule.states ~= part; rule.specificity += 10; break;
        default: assert(false);
        }
    }
    return rule;
}

private bool isIdentifier(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '_' || c == '-';
}

private Declaration parseDeclaration(string name, string value) {
    Declaration result;
    result.name = name;
    switch (name) {
    case "background": case "background-color": case "border-color": case "focused-border-color":
    case "hover-color": case "pressed-color": case "disabled-color":
    case "color": case "track-color": case "thumb-color": case "fill-color":
    case "selection-color":
        result.color = parseColor(value); break;
    case "border-width": case "border-radius": case "gap":
        result.numbers[0] = parsePixels(value); break;
    case "border":
        if (value == "none") { result.color = SDL_Color(0, 0, 0, 0); break; }
        auto parts = value.split;
        if (parts.length != 3 || parts[1] != "solid")
            throw new CSSException("border needs: width solid color");
        result.numbers[0] = parsePixels(parts[0]);
        result.color = parseColor(parts[2]);
        break;
    case "padding":
        auto parts = value.split;
        if (parts.length < 1 || parts.length > 4)
            throw new CSSException("padding needs 1 to 4 values");
        int[] n;
        foreach (part; parts) n ~= parsePixels(part);
        final switch (n.length) {
        case 1: result.numbers = [n[0], n[0], n[0], n[0]]; break;
        case 2: result.numbers = [n[0], n[1], n[0], n[1]]; break;
        case 3: result.numbers = [n[0], n[1], n[2], n[1]]; break;
        case 4: result.numbers = [n[0], n[1], n[2], n[3]]; break;
        }
        break;
    default: throw new CSSException("Unsupported CSS property: " ~ name);
    }
    return result;
}

private int parsePixels(string value) {
    if (value.length >= 2 && value[$ - 2 .. $] == "px") value = value[0 .. $ - 2];
    try {
        int n = value.strip.to!int;
        if (n < 0) throw new CSSException("CSS sizes must be nonnegative");
        return n;
    } catch (Exception) {
        throw new CSSException("Invalid CSS size: " ~ value);
    }
}

private int hexDigit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    throw new CSSException("Invalid hexadecimal CSS color");
}

private SDL_Color parseColor(string value) {
    if (value == "transparent") return SDL_Color(0, 0, 0, 0);
    if (!value.length || value[0] != '#')
        throw new CSSException("CSS colors must be #RGB, #RRGGBB, #RRGGBBAA or transparent");
    if (value.length == 4)
        return SDL_Color(cast(ubyte)(hexDigit(value[1]) * 17),
            cast(ubyte)(hexDigit(value[2]) * 17),
            cast(ubyte)(hexDigit(value[3]) * 17), 255);
    if (value.length != 7 && value.length != 9)
        throw new CSSException("Invalid CSS color: " ~ value);
    ubyte[4] channels = [0, 0, 0, 255];
    foreach (i; 0 .. (value.length - 1) / 2)
        channels[i] = cast(ubyte)(hexDigit(value[1 + i * 2]) * 16 +
            hexDigit(value[2 + i * 2]));
    return SDL_Color(channels[0], channels[1], channels[2], channels[3]);
}

private void applyDeclaration(ref Style style, ref const Declaration d) {
    switch (d.name) {
    case "background": case "background-color": style.background_color = d.color; break;
    case "border":
        style.border_width = d.numbers[0]; style.has_border_width = true;
        style.border_color = d.color; break;
    case "border-color": style.border_color = d.color; break;
    case "focused-border-color": style.focused_border_color = d.color; break;
    case "hover-color": style.hover_color = d.color; break;
    case "pressed-color": style.pressed_color = d.color; break;
    case "disabled-color": style.disabled_color = d.color; break;
    case "color": style.text_color = d.color; style.has_text_color = true; break;
    case "track-color": style.track_color = d.color; style.has_track_color = true; break;
    case "thumb-color": style.thumb_color = d.color; style.has_thumb_color = true; break;
    case "fill-color": style.fill_color = d.color; style.has_fill_color = true; break;
    case "selection-color": style.selection_color = d.color; style.has_selection_color = true; break;
    case "border-width":
        style.border_width = d.numbers[0]; style.has_border_width = true; break;
    case "border-radius": style.border_radius = d.numbers[0]; break;
    case "gap": style.gap = d.numbers[0]; break;
    case "padding":
        style.padding_top = d.numbers[0]; style.padding_right = d.numbers[1];
        style.padding_bottom = d.numbers[2]; style.padding_left = d.numbers[3];
        break;
    default: assert(false);
    }
}
