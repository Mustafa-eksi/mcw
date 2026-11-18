module mcw.tests.launcher_actions;

import mcw.launcher_actions : calculate, defaultSearchUrl;

unittest {
    string result;
    assert(calculate("2 + 3 * 4", result) && result == "14");
    assert(calculate("(2 + 3) * 4", result) && result == "20");
    assert(calculate("2^3^2", result) && result == "512");
    assert(calculate("-2^2", result) && result == "-4");
    assert(calculate("2^-2", result) && result == "0.25");
    assert(calculate("sqrt(9) + sin(pi / 2)", result) && result == "4");
    assert(calculate("1e3 + 2", result) && result == "1002");
    assert(!calculate("1 / 0", result));
    assert(!calculate("sqrt(-1)", result));
    assert(!calculate("2 +", result));
    assert(!calculate("foo(2)", result));
    assert(defaultSearchUrl("C++ & D") ==
        "https://duckduckgo.com/?q=C%2B%2B%20%26%20D");
    assert(defaultSearchUrl("İTÜ") ==
        "https://duckduckgo.com/?q=%C4%B0T%C3%9C");
}
