module mcw.launcher_actions;

import std.conv : to;
import std.format : format;
import std.math : abs, cos, fmod, isFinite, log, log10, pow, sin, sqrt, tan;
import std.string : toLower;

string defaultSearchUrl(string query) {
    enum hex = "0123456789ABCDEF";
    string encoded;
    foreach (ubyte byteValue; cast(const(ubyte)[]) query) {
        if ((byteValue >= 'a' && byteValue <= 'z') ||
            (byteValue >= 'A' && byteValue <= 'Z') ||
            (byteValue >= '0' && byteValue <= '9') ||
            byteValue == '-' || byteValue == '_' || byteValue == '.' ||
            byteValue == '~') {
            encoded ~= cast(char) byteValue;
        } else {
            encoded ~= '%';
            encoded ~= hex[byteValue >> 4];
            encoded ~= hex[byteValue & 15];
        }
    }
    return "https://duckduckgo.com/?q=" ~ encoded;
}

private struct Calculator {
    string input;
    size_t pos;

    void spaces() {
        while (pos < input.length &&
                (input[pos] == ' ' || input[pos] == '\t')) pos++;
    }

    bool take(char token) {
        spaces();
        if (pos < input.length && input[pos] == token) { pos++; return true; }
        return false;
    }

    double expression() {
        double value = term();
        while (true) {
            if (take('+')) value += term();
            else if (take('-')) value -= term();
            else return value;
        }
    }

    double term() {
        double value = unary();
        while (true) {
            if (take('*')) value *= unary();
            else if (take('/')) value /= unary();
            else if (take('%')) value = fmod(value, unary());
            else return value;
        }
    }

    double unary() {
        if (take('+')) return unary();
        if (take('-')) return -unary();
        return power();
    }

    double power() {
        double value = primary();
        if (take('^')) value = pow(value, unary());
        return value;
    }

    double primary() {
        spaces();
        if (take('(')) {
            double value = expression();
            if (!take(')')) throw new Exception("Missing closing parenthesis");
            return value;
        }
        if (pos >= input.length) throw new Exception("Incomplete expression");

        if ((input[pos] >= 'a' && input[pos] <= 'z') ||
                (input[pos] >= 'A' && input[pos] <= 'Z')) {
            auto start = pos;
            while (pos < input.length &&
                    ((input[pos] >= 'a' && input[pos] <= 'z') ||
                     (input[pos] >= 'A' && input[pos] <= 'Z'))) pos++;
            auto name = input[start .. pos].toLower();
            if (name == "pi") return 3.14159265358979323846;
            if (name == "e") return 2.71828182845904523536;
            if (!take('(')) throw new Exception("Unknown value");
            double argument = expression();
            if (!take(')')) throw new Exception("Missing closing parenthesis");
            switch (name) {
            case "sqrt": return sqrt(argument);
            case "sin": return sin(argument);
            case "cos": return cos(argument);
            case "tan": return tan(argument);
            case "abs": return abs(argument);
            case "ln": return log(argument);
            case "log": return log10(argument);
            default: throw new Exception("Unknown function");
            }
        }

        auto start = pos;
        bool digits;
        while (pos < input.length && input[pos] >= '0' && input[pos] <= '9') {
            pos++; digits = true;
        }
        if (pos < input.length && input[pos] == '.') {
            pos++;
            while (pos < input.length && input[pos] >= '0' && input[pos] <= '9') {
                pos++; digits = true;
            }
        }
        if (!digits) throw new Exception("Expected number");
        if (pos < input.length && (input[pos] == 'e' || input[pos] == 'E')) {
            pos++;
            if (pos < input.length && (input[pos] == '+' || input[pos] == '-')) pos++;
            auto exponentStart = pos;
            while (pos < input.length && input[pos] >= '0' && input[pos] <= '9') pos++;
            if (pos == exponentStart) throw new Exception("Invalid exponent");
        }
        return input[start .. pos].to!double;
    }
}

bool calculate(string input, out string result) {
    try {
        auto parser = Calculator(input);
        double value = parser.expression();
        parser.spaces();
        if (parser.pos != input.length || !isFinite(value)) return false;
        if (value == 0) value = 0; // Avoid displaying negative zero.
        result = format("%.12g", value);
        return true;
    } catch (Exception) {
        return false;
    }
}
