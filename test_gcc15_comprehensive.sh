#!/bin/bash
# Comprehensive GCC 15 test suite for Tiger PPC
# Tests C, C++17, C++20, C++23, optimization, linking, exceptions, STL
# Run on iMac G5: bash test_gcc15_comprehensive.sh [gcc-path] [g++-path]

GCC="${1:-/usr/local/bin/gcc}"
GXX="${2:-/usr/local/bin/g++}"
TMPDIR="${TMPDIR:-/tmp}"
PASS=0; FAIL=0; TOTAL=0; ERRORS=""

cleanup() { rm -f "$TMPDIR"/gcc_test_* 2>/dev/null; }
trap cleanup EXIT

T() {
    TOTAL=$((TOTAL+1))
    local label="$1"; shift
    if eval "$@" > /dev/null 2>&1; then
        PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
    else
        FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
        ERRORS="$ERRORS\n  $label"
    fi
}

# Compile C, run, check output
CC() {
    local label="$1" std="$2" opt="$3" src="$4" expected="$5"
    local sf="$TMPDIR/gcc_test_$TOTAL.c" bf="$TMPDIR/gcc_test_$TOTAL"
    echo "$src" > "$sf"
    TOTAL=$((TOTAL+1))
    if $GCC $std $opt -o "$bf" "$sf" 2>/dev/null && [ "$("$bf" 2>&1)" = "$expected" ]; then
        PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
    else
        FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
        ERRORS="$ERRORS\n  $label"
    fi
    rm -f "$sf" "$bf"
}

# Compile C++, run, check output
CX() {
    local label="$1" std="$2" opt="$3" src="$4" expected="$5"
    local sf="$TMPDIR/gcc_test_$TOTAL.cc" bf="$TMPDIR/gcc_test_$TOTAL"
    echo "$src" > "$sf"
    TOTAL=$((TOTAL+1))
    if $GXX $std $opt -o "$bf" "$sf" 2>/dev/null && [ "$("$bf" 2>&1)" = "$expected" ]; then
        PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
    else
        FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
        ERRORS="$ERRORS\n  $label"
    fi
    rm -f "$sf" "$bf"
}

# Compile C++ only (no run, just check compilation)
CX_COMPILE() {
    local label="$1" std="$2" opt="$3" src="$4"
    local sf="$TMPDIR/gcc_test_$TOTAL.cc" bf="$TMPDIR/gcc_test_$TOTAL.o"
    echo "$src" > "$sf"
    TOTAL=$((TOTAL+1))
    if $GXX $std $opt -c -o "$bf" "$sf" 2>/dev/null; then
        PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
    else
        FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
        ERRORS="$ERRORS\n  $label"
    fi
    rm -f "$sf" "$bf"
}

echo "========================================"
echo " GCC 15 Comprehensive Test Suite"
echo "========================================"
echo "GCC:  $($GCC --version 2>&1 | head -1)"
echo "G++:  $($GXX --version 2>&1 | head -1)"
echo "Host: $(uname -m) $(uname -s) $(uname -r)"
echo "========================================"
START=$(date +%s)

########################################
echo ""
echo "=== 1. COMPILER BASICS ==="
########################################

T "gcc --version" "$GCC --version"
T "g++ --version" "$GXX --version"
T "gcc -dumpmachine" "$GCC -dumpmachine | grep -q powerpc"
T "gcc -dumpversion" "$GCC -dumpversion | grep -q 15"
T "gcc -v" "$GCC -v 2>&1 | grep -q 'gcc version 15'"

########################################
echo ""
echo "=== 2. C LANGUAGE (C11/C23) ==="
########################################

CC "c: hello world" "-std=c11" "-O2" \
    '#include <stdio.h>
    int main() { printf("hello"); return 0; }' \
    "hello"

CC "c: printf formatting" "-std=c11" "-O2" \
    '#include <stdio.h>
    int main() { printf("%d %.2f %s", 42, 3.14, "ok"); return 0; }' \
    "42 3.14 ok"

CC "c: struct + typedef" "-std=c11" "-O2" \
    '#include <stdio.h>
    typedef struct { int x; float y; } Point;
    int main() { Point p = {10, 2.5f}; printf("%d", p.x); return 0; }' \
    "10"

CC "c: function pointers" "-std=c11" "-O2" \
    '#include <stdio.h>
    int add(int a, int b) { return a+b; }
    int main() { int (*f)(int,int) = add; printf("%d", f(3,4)); return 0; }' \
    "7"

CC "c: variadic function" "-std=c11" "-O2" \
    '#include <stdio.h>
    #include <stdarg.h>
    int sum(int n, ...) { va_list ap; va_start(ap,n); int s=0;
    for(int i=0;i<n;i++) s+=va_arg(ap,int); va_end(ap); return s; }
    int main() { printf("%d", sum(4, 10, 20, 30, 40)); return 0; }' \
    "100"

CC "c: malloc + free" "-std=c11" "-O2" \
    '#include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    int main() { char *p = malloc(64); strcpy(p, "heap"); printf("%s", p); free(p); return 0; }' \
    "heap"

CC "c: file I/O" "-std=c11" "-O2" \
    '#include <stdio.h>
    int main() {
    FILE *f = fopen("/tmp/gcc_test_fio.txt", "w"); fprintf(f, "data"); fclose(f);
    f = fopen("/tmp/gcc_test_fio.txt", "r"); char buf[16]; fgets(buf, 16, f); fclose(f);
    remove("/tmp/gcc_test_fio.txt"); printf("%s", buf); return 0; }' \
    "data"

CC "c: recursion (fibonacci)" "-std=c11" "-O2" \
    '#include <stdio.h>
    int fib(int n) { return n<2 ? n : fib(n-1)+fib(n-2); }
    int main() { printf("%d", fib(10)); return 0; }' \
    "55"

CC "c: bitwise operations" "-std=c11" "-O2" \
    '#include <stdio.h>
    int main() { unsigned x=0xDEADBEEF; printf("%x", (x>>16)^(x&0xFFFF)); return 0; }' \
    "6042"

CC "c: long long arithmetic" "-std=c11" "-O2" \
    '#include <stdio.h>
    int main() { long long a=1000000000LL; printf("%lld", a*a); return 0; }' \
    "1000000000000000000"

CC "c: compound literals (C11)" "-std=c11" "-O2" \
    '#include <stdio.h>
    int main() { int *p = (int[]){1,2,3}; printf("%d", p[0]+p[1]+p[2]); return 0; }' \
    "6"

CC "c: _Generic (C11)" "-std=c11" "-O2" \
    '#include <stdio.h>
    #define typename(x) _Generic((x), int: "int", double: "double", default: "other")
    int main() { printf("%s %s", typename(42), typename(3.14)); return 0; }' \
    "int double"

CC "c: _Static_assert (C11)" "-std=c11" "-O2" \
    '#include <stdio.h>
    _Static_assert(sizeof(int) == 4, "int must be 4 bytes");
    int main() { printf("ok"); return 0; }' \
    "ok"

CC "c: _Alignof/_Alignas (C11)" "-std=c11" "-O2" \
    '#include <stdio.h>
    #include <stdalign.h>
    int main() { printf("%zu", alignof(double)); return 0; }' \
    "4"

CC "c: VLA (variable-length array)" "-std=c11" "-O2" \
    '#include <stdio.h>
    int sum(int n, int a[n]) { int s=0; for(int i=0;i<n;i++) s+=a[i]; return s; }
    int main() { int a[]={1,2,3,4,5}; printf("%d", sum(5,a)); return 0; }' \
    "15"

CC "c: designated initializers" "-std=c11" "-O2" \
    '#include <stdio.h>
    struct S { int a; int b; int c; };
    int main() { struct S s = {.c=30, .a=10, .b=20}; printf("%d", s.a+s.b+s.c); return 0; }' \
    "60"

CC "c: inline function" "-std=c11" "-O2" \
    '#include <stdio.h>
    static inline int sq(int x) { return x*x; }
    int main() { printf("%d", sq(7)); return 0; }' \
    "49"

########################################
echo ""
echo "=== 3. C++ BASICS (C++11/14/17) ==="
########################################

CX "c++: hello world" "-std=c++17" "-O2" \
    '#include <iostream>
    int main() { std::cout << "hello"; return 0; }' \
    "hello"

CX "c++: auto + range-for" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <vector>
    int main() { std::vector<int> v{1,2,3,4,5}; int s=0;
    for(auto x : v) s+=x; std::cout << s; }' \
    "15"

CX "c++: lambda" "-std=c++17" "-O2" \
    '#include <iostream>
    int main() { auto f = [](int a, int b) { return a*b; }; std::cout << f(6,7); }' \
    "42"

CX "c++: lambda capture" "-std=c++17" "-O2" \
    '#include <iostream>
    int main() { int x=10; auto f = [&x](int a) { x+=a; }; f(5); std::cout << x; }' \
    "15"

CX "c++: class + inheritance" "-std=c++17" "-O2" \
    '#include <iostream>
    struct Base { virtual int val() { return 1; } };
    struct Derived : Base { int val() override { return 2; } };
    int main() { Derived d; Base *b=&d; std::cout << b->val(); }' \
    "2"

CX "c++: templates" "-std=c++17" "-O2" \
    '#include <iostream>
    template<typename T> T max2(T a, T b) { return a>b?a:b; }
    int main() { std::cout << max2(3,5) << max2(2.5,1.5); }' \
    "52.5"

CX "c++: variadic templates" "-std=c++17" "-O2" \
    '#include <iostream>
    template<typename... Args> int count(Args... args) { return sizeof...(args); }
    int main() { std::cout << count(1,2,3,"four",5.0); }' \
    "5"

CX "c++: fold expressions (C++17)" "-std=c++17" "-O2" \
    '#include <iostream>
    template<typename... Args> auto sum(Args... args) { return (args + ...); }
    int main() { std::cout << sum(1,2,3,4,5); }' \
    "15"

CX "c++: RAII + move semantics" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <utility>
    struct R { int id;
    R(int i):id(i){std::cout<<id<<"c";}
    R(R&&o):id(o.id){o.id=0;std::cout<<id<<"m";}
    ~R(){std::cout<<id<<"d";}};
    int main() { R a(1); R b(std::move(a)); }' \
    "1c1m1d0d"

CX "c++: smart pointers" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <memory>
    struct S { int x; S(int v):x(v){} };
    int main() { auto p = std::make_unique<S>(42); std::cout << p->x; }' \
    "42"

CX "c++: shared_ptr" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <memory>
    int main() { auto p = std::make_shared<int>(99);
    auto q = p; std::cout << *q << " " << p.use_count(); }' \
    "99 2"

CX "c++: std::string" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <string>
    int main() { std::string s = "hello"; s += " world"; std::cout << s.length() << " " << s.substr(6); }' \
    "11 world"

CX "c++: std::map" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <map>
    int main() { std::map<std::string,int> m; m["a"]=1; m["b"]=2; m["c"]=3;
    for(auto&[k,v]:m) std::cout << k << v; }' \
    "a1b2c3"

CX "c++: std::unordered_map" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <unordered_map>
    int main() { std::unordered_map<int,int> m; m[1]=10; m[2]=20;
    std::cout << m[1]+m[2]; }' \
    "30"

CX "c++: std::optional (C++17)" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <optional>
    std::optional<int> find(int x) { return x>0 ? std::optional(x*2) : std::nullopt; }
    int main() { auto a=find(5); auto b=find(-1);
    std::cout << a.value_or(0) << " " << b.value_or(0); }' \
    "10 0"

CX "c++: std::variant (C++17)" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <variant>
    int main() { std::variant<int,double,std::string> v = 42;
    std::cout << std::get<int>(v); v = 3.14;
    std::cout << " " << std::get<double>(v); }' \
    "42 3.14"

CX "c++: std::any (C++17)" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <any>
    int main() { std::any a = 42; std::cout << std::any_cast<int>(a);
    a = std::string("hi"); std::cout << " " << std::any_cast<std::string>(a); }' \
    "42 hi"

CX "c++: if constexpr (C++17)" "-std=c++17" "-O2" \
    '#include <iostream>
    template<typename T> void show(T v) {
    if constexpr(std::is_integral_v<T>) std::cout << "int:" << v;
    else std::cout << "other:" << v; }
    int main() { show(42); std::cout << " "; show(3.14); }' \
    "int:42 other:3.14"

CX "c++: structured bindings (C++17)" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <tuple>
    int main() { auto [a,b,c] = std::tuple(1,2.5,"hi");
    std::cout << a << " " << b << " " << c; }' \
    "1 2.5 hi"

CX "c++: std::string_view (C++17)" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <string_view>
    void greet(std::string_view sv) { std::cout << sv.substr(0,5); }
    int main() { greet("hello world"); }' \
    "hello"

CX_COMPILE "c++: std::filesystem (C++17)" "-std=c++17" "-O2" \
    '#include <filesystem>
    int main() { namespace fs = std::filesystem;
    auto p = fs::path("/usr/local/bin/gcc"); (void)p; }'

CX "c++: constexpr if + type_traits" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <type_traits>
    template<typename T> constexpr bool is_ptr = std::is_pointer_v<T>;
    int main() { std::cout << is_ptr<int> << is_ptr<int*>; }' \
    "01"

CX "c++: nested namespaces (C++17)" "-std=c++17" "-O2" \
    '#include <iostream>
    namespace A::B::C { int val = 42; }
    int main() { std::cout << A::B::C::val; }' \
    "42"

########################################
echo ""
echo "=== 4. EXCEPTIONS ==="
########################################

CX "exc: throw int" "-std=c++17" "-O2" \
    '#include <iostream>
    int main() { try { throw 42; } catch(int e) { std::cout << e; } }' \
    "42"

CX "exc: throw string" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <string>
    int main() { try { throw std::string("err"); }
    catch(const std::string& e) { std::cout << e; } }' \
    "err"

CX "exc: runtime_error" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <stdexcept>
    int main() { try { throw std::runtime_error("oops"); }
    catch(const std::exception& e) { std::cout << e.what(); } }' \
    "oops"

CX "exc: custom class" "-std=c++17" "-O2" \
    '#include <iostream>
    struct MyExc { int code; const char* msg; };
    int main() { try { throw MyExc{404,"not found"}; }
    catch(const MyExc& e) { std::cout << e.code << " " << e.msg; } }' \
    "404 not found"

CX "exc: rethrow" "-std=c++17" "-O2" \
    '#include <iostream>
    void inner() { try { throw 99; } catch(...) { std::cout << "caught "; throw; } }
    int main() { try { inner(); } catch(int e) { std::cout << e; } }' \
    "caught 99"

CX "exc: deep unwind (5 levels)" "-std=c++17" "-O2" \
    '#include <iostream>
    void f5() { throw 5; }
    void f4() { f5(); }
    void f3() { f4(); }
    void f2() { f3(); }
    void f1() { f2(); }
    int main() { try { f1(); } catch(int e) { std::cout << "depth " << e; } }' \
    "depth 5"

CX "exc: multi-catch" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <stdexcept>
    void thrower(int x) { if(x==1) throw 42; if(x==2) throw std::runtime_error("rt"); }
    int main() {
    for(int i=1;i<=2;i++) {
    try { thrower(i); }
    catch(int e) { std::cout << "int:" << e << " "; }
    catch(const std::exception& e) { std::cout << "exc:" << e.what(); } } }' \
    "int:42 exc:rt"

CX "exc: RAII cleanup during unwind" "-std=c++17" "-O2" \
    '#include <iostream>
    struct Guard { int id; Guard(int i):id(i){} ~Guard(){std::cout<<id;} };
    void f() { Guard g1(1); Guard g2(2); throw 0; }
    int main() { try { f(); } catch(...) { std::cout << "c"; } }' \
    "21c"

CX "exc: exception in constructor" "-std=c++17" "-O2" \
    '#include <iostream>
    struct S { S(bool fail) { if(fail) throw "ctor"; std::cout << "ok"; }
    ~S() { std::cout << "d"; } };
    int main() { try { S a(false); S b(true); } catch(const char* e) { std::cout << e; } }' \
    "okdctor"

CX "exc: noexcept function" "-std=c++17" "-O2" \
    '#include <iostream>
    void safe() noexcept { }
    int main() { std::cout << noexcept(safe()) << " " << noexcept(throw 1); }' \
    "1 0"

########################################
echo ""
echo "=== 5. C++20 FEATURES ==="
########################################

CX "c++20: concepts (basic)" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <concepts>
    template<std::integral T> T twice(T x) { return x*2; }
    int main() { std::cout << twice(21); }' \
    "42"

CX "c++20: concept with requires" "-std=c++20" "-O2" \
    '#include <iostream>
    template<typename T> concept Addable = requires(T a, T b) { a + b; };
    template<Addable T> T add(T a, T b) { return a+b; }
    int main() { std::cout << add(3,4) << " " << add(1.5,2.5); }' \
    "7 4"

CX "c++20: requires clause" "-std=c++20" "-O2" \
    '#include <iostream>
    template<typename T> requires (sizeof(T) >= 4)
    void show(T x) { std::cout << x; }
    int main() { show(42); show(3.14); }' \
    "423.14"

CX "c++20: spaceship operator <=>" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <compare>
    struct Val { int x;
    auto operator<=>(const Val&) const = default; };
    int main() { Val a{1}, b{2};
    std::cout << (a<b) << (a==a) << (b>a); }' \
    "111"

CX "c++20: designated initializers" "-std=c++20" "-O2" \
    '#include <iostream>
    struct P { int x=0; int y=0; int z=0; };
    int main() { P p{.x=1, .z=3}; std::cout << p.x << p.y << p.z; }' \
    "103"

CX "c++20: consteval" "-std=c++20" "-O2" \
    '#include <iostream>
    consteval int square(int n) { return n*n; }
    int main() { constexpr int r = square(7); std::cout << r; }' \
    "49"

CX "c++20: constinit" "-std=c++20" "-O2" \
    '#include <iostream>
    constinit int global = 42;
    int main() { std::cout << global; }' \
    "42"

CX "c++20: template lambda" "-std=c++20" "-O2" \
    '#include <iostream>
    int main() { auto f = []<typename T>(T x, T y) { return x+y; };
    std::cout << f(3,4) << " " << f(1.5,2.5); }' \
    "7 4"

CX "c++20: init-statement in range-for" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <vector>
    int main() { std::vector v{1,2,3,4,5};
    for(int s=0; auto x : v) { s+=x; if(x==5) std::cout<<s; } }' \
    "15"

CX "c++20: std::span" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <span>
    int sum(std::span<const int> s) { int r=0; for(auto x:s) r+=x; return r; }
    int main() { int a[]={10,20,30}; std::cout << sum(a); }' \
    "60"

CX "c++20: std::to_array" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <array>
    int main() { auto a = std::to_array({1,2,3}); std::cout << a.size() << " " << a[2]; }' \
    "3 3"

CX "c++20: std::bit_cast" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <bit>
    #include <cstdint>
    int main() { float f = 1.0f; auto i = std::bit_cast<uint32_t>(f);
    std::cout << (i == 0x3f800000 ? "ok" : "fail"); }' \
    "ok"

CX "c++20: std::endian" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <bit>
    int main() { if constexpr(std::endian::native == std::endian::big)
    std::cout << "big"; else std::cout << "little"; }' \
    "big"

CX "c++20: using enum" "-std=c++20" "-O2" \
    '#include <iostream>
    enum class Color { Red, Green, Blue };
    int main() { using enum Color; std::cout << (int)Red << (int)Green << (int)Blue; }' \
    "012"

CX "c++20: char8_t" "-std=c++20" "-O2" \
    '#include <iostream>
    int main() { char8_t c = u8'"'"'A'"'"'; std::cout << (int)c; }' \
    "65"

CX "c++20: aggregate init with parens" "-std=c++20" "-O2" \
    '#include <iostream>
    struct S { int a; int b; };
    int main() { S* p = new S(10, 20); std::cout << p->a + p->b; delete p; }' \
    "30"

CX "c++20: constexpr std::array" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <array>
    constexpr int sum() { std::array<int,5> a = {1,2,3,4,5}; int s=0; for(int i=0;i<5;i++) s+=a[i]; return s; }
    int main() { std::cout << sum(); }' \
    "15"


CX "c++20: constexpr vector" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <vector>
    constexpr int sum() { std::vector<int> v{1,2,3}; int s=0; for(auto x:v) s+=x; return s; }
    int main() { std::cout << sum(); }' \
    "6"

CX "c++20: source_location" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <source_location>
    int main() { auto loc = std::source_location::current();
    std::cout << loc.function_name(); }' \
    "int main()"

CX "c++20: contains() for maps" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <map>
    int main() { std::map<int,int> m{{1,10},{2,20}};
    std::cout << m.contains(1) << m.contains(3); }' \
    "10"

CX "c++20: starts_with/ends_with" "-std=c++20" "-O2" \
    '#include <iostream>
    #include <string>
    int main() { std::string s = "hello world";
    std::cout << s.starts_with("hello") << s.ends_with("world"); }' \
    "11"

CX_COMPILE "c++20: coroutines (compile)" "-std=c++20" "-O2 -fcoroutines" \
    '#include <coroutine>
    struct Task {
      struct promise_type {
        Task get_return_object() { return {}; }
        std::suspend_never initial_suspend() { return {}; }
        std::suspend_never final_suspend() noexcept { return {}; }
        void return_void() {}
        void unhandled_exception() {}
      };
    };
    Task hello() { co_return; }
    int main() { hello(); }'

########################################
echo ""
echo "=== 6. C++23 FEATURES ==="
########################################

CX "c++23: if consteval" "-std=c++23" "-O2" \
    '#include <iostream>
    constexpr int f(int x) {
    if consteval { return x*2; } else { return x*3; } }
    int main() { constexpr int a = f(5); int b = f(5); std::cout << a << " " << b; }' \
    "10 15"

CX "c++23: size_t literal" "-std=c++23" "-O2" \
    '#include <iostream>
    int main() { auto x = 42uz; std::cout << sizeof(x) << " " << x; }' \
    "4 42"

CX "c++23: multidimensional subscript" "-std=c++23" "-O2" \
    '#include <iostream>
    struct Mat { int data[4];
    int& operator[](int r, int c) { return data[r*2+c]; } };
    int main() { Mat m{{1,2,3,4}}; std::cout << m[1,0] << m[1,1]; }' \
    "34"

CX "c++23: deducing this" "-std=c++23" "-O2" \
    '#include <iostream>
    struct S { int x;
    void show(this const S& self) { std::cout << self.x; } };
    int main() { S s{42}; s.show(); }' \
    "42"

CX "c++23: auto(x) decay copy" "-std=c++23" "-O2" \
    '#include <iostream>
    int main() { int arr[] = {1,2,3}; auto p = auto(arr); std::cout << *p; }' \
    "1"

CX "c++23: static operator()" "-std=c++23" "-O2" \
    '#include <iostream>
    struct Add { static int operator()(int a, int b) { return a+b; } };
    int main() { std::cout << Add{}(3,4); }' \
    "7"

CX "c++23: constexpr unique_ptr" "-std=c++23" "-O2" \
    '#include <iostream>
    #include <memory>
    constexpr int test() { auto p = std::make_unique<int>(42); return *p; }
    int main() { std::cout << test(); }' \
    "42"

CX "c++23: std::optional transform" "-std=c++23" "-O2" \
    '#include <iostream>
    #include <optional>
    int main() { std::optional<int> o = 5;
    auto r = o.transform([](int x){ return x * 2; });
    std::cout << r.value(); }' \
    "10"


CX "c++23: std::unreachable" "-std=c++23" "-O2" \
    '#include <iostream>
    #include <utility>
    int f(int x) { switch(x) { case 1: return 10; default: std::unreachable(); } }
    int main() { std::cout << f(1); }' \
    "10"

CX_COMPILE "c++23: std::print (compile)" "-std=c++23" "-O2" \
    '#include <print>
    int main() { std::print("hello {}!", 42); }'

CX "c++23: lambda trailing return auto" "-std=c++23" "-O2" \
    '#include <iostream>
    int main() { auto f = [](auto x, auto y) -> decltype(x+y) { return x+y; };
    std::cout << f(3,4); }' \
    "7"

########################################
echo ""
echo "=== 7. OPTIMIZATION LEVELS ==="
########################################

for opt in -O0 -O1 -O2 -O3 -Os; do
    CX "opt: C++ at $opt" "-std=c++17" "$opt" \
        '#include <iostream>
        int fib(int n) { return n<2?n:fib(n-1)+fib(n-2); }
        int main() { std::cout << fib(20); }' \
        "6765"
done

CC "opt: C at -O3 -mcpu=G3" "-std=c11" "-O3 -mcpu=G3" \
    '#include <stdio.h>
    int main() { int s=0; for(int i=1;i<=100;i++) s+=i; printf("%d",s); return 0; }' \
    "5050"

CC "opt: C at -O3 -mcpu=G4" "-std=c11" "-O3 -mcpu=G4" \
    '#include <stdio.h>
    int main() { int s=0; for(int i=1;i<=100;i++) s+=i; printf("%d",s); return 0; }' \
    "5050"

CC "opt: C at -O3 -mcpu=G5" "-std=c11" "-O3 -mcpu=970" \
    '#include <stdio.h>
    int main() { int s=0; for(int i=1;i<=100;i++) s+=i; printf("%d",s); return 0; }' \
    "5050"

########################################
echo ""
echo "=== 8. MULTI-FILE + LINKING ==="
########################################

TOTAL=$((TOTAL+1))
label="link: multi-file C++ project"
cat > "$TMPDIR/gcc_test_lib.h" << 'HEOF'
#pragma once
int compute(int x);
extern const char* version;
HEOF
cat > "$TMPDIR/gcc_test_lib.cc" << 'CEOF'
#include "gcc_test_lib.h"
const char* version = "1.0";
int compute(int x) { return x * x + 1; }
CEOF
cat > "$TMPDIR/gcc_test_main.cc" << 'MEOF'
#include <iostream>
#include "gcc_test_lib.h"
int main() { std::cout << version << " " << compute(5); }
MEOF
if $GXX -std=c++17 -O2 -I"$TMPDIR" -o "$TMPDIR/gcc_test_multi" \
    "$TMPDIR/gcc_test_lib.cc" "$TMPDIR/gcc_test_main.cc" 2>/dev/null \
    && [ "$("$TMPDIR/gcc_test_multi")" = "1.0 26" ]; then
    PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
else
    FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
    ERRORS="$ERRORS\n  $label"
fi
rm -f "$TMPDIR"/gcc_test_lib.* "$TMPDIR"/gcc_test_main.* "$TMPDIR"/gcc_test_multi

TOTAL=$((TOTAL+1))
label="link: static archive (.a)"
cat > "$TMPDIR/gcc_test_arlib.c" << 'EOF'
int triple(int x) { return x*3; }
EOF
cat > "$TMPDIR/gcc_test_armain.c" << 'EOF'
#include <stdio.h>
int triple(int x);
int main() { printf("%d", triple(14)); return 0; }
EOF
if $GCC -c -O2 -o "$TMPDIR/gcc_test_arlib.o" "$TMPDIR/gcc_test_arlib.c" 2>/dev/null \
    && ar rcs "$TMPDIR/gcc_test_arlib.a" "$TMPDIR/gcc_test_arlib.o" 2>/dev/null \
    && $GCC -O2 -o "$TMPDIR/gcc_test_armain" "$TMPDIR/gcc_test_armain.c" "$TMPDIR/gcc_test_arlib.a" 2>/dev/null \
    && [ "$("$TMPDIR/gcc_test_armain")" = "42" ]; then
    PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
else
    FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
    ERRORS="$ERRORS\n  $label"
fi
rm -f "$TMPDIR"/gcc_test_ar*

TOTAL=$((TOTAL+1))
label="link: C and C++ mixed"
cat > "$TMPDIR/gcc_test_cfunc.c" << 'EOF'
int c_add(int a, int b) { return a + b; }
EOF
cat > "$TMPDIR/gcc_test_cxxmain.cc" << 'EOF'
#include <iostream>
extern "C" int c_add(int a, int b);
int main() { std::cout << c_add(20, 22); }
EOF
if $GCC -c -O2 -o "$TMPDIR/gcc_test_cfunc.o" "$TMPDIR/gcc_test_cfunc.c" 2>/dev/null \
    && $GXX -std=c++17 -O2 -o "$TMPDIR/gcc_test_mixed" "$TMPDIR/gcc_test_cxxmain.cc" "$TMPDIR/gcc_test_cfunc.o" 2>/dev/null \
    && [ "$("$TMPDIR/gcc_test_mixed")" = "42" ]; then
    PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
else
    FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
    ERRORS="$ERRORS\n  $label"
fi
rm -f "$TMPDIR"/gcc_test_cfunc.* "$TMPDIR"/gcc_test_cxxmain.* "$TMPDIR"/gcc_test_mixed

########################################
echo ""
echo "=== 9. STL CONTAINERS + ALGORITHMS ==="
########################################

CX "stl: std::vector operations" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <vector>
    #include <algorithm>
    #include <numeric>
    int main() { std::vector<int> v{5,3,1,4,2};
    std::sort(v.begin(),v.end());
    std::cout << v.front() << v.back() << " " << std::accumulate(v.begin(),v.end(),0); }' \
    "15 15"

CX "stl: std::set + iterators" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <set>
    int main() { std::set<int> s{3,1,4,1,5,9}; std::cout << s.size();
    for(auto x:s) std::cout << x; }' \
    "513459"

CX "stl: std::deque" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <deque>
    int main() { std::deque<int> d; d.push_back(2); d.push_front(1); d.push_back(3);
    for(auto x:d) std::cout << x; }' \
    "123"

CX "stl: std::priority_queue" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <queue>
    int main() { std::priority_queue<int> pq;
    pq.push(3); pq.push(1); pq.push(4); pq.push(2);
    while(!pq.empty()) { std::cout << pq.top(); pq.pop(); } }' \
    "4321"

CX "stl: std::transform" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <vector>
    #include <algorithm>
    int main() { std::vector<int> v{1,2,3}; std::vector<int> r(3);
    std::transform(v.begin(),v.end(),r.begin(),[](int x){return x*x;});
    for(auto x:r) std::cout << x << " "; }' \
    "1 4 9 "

CX "stl: std::find_if" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <vector>
    #include <algorithm>
    int main() { std::vector<int> v{1,3,5,8,9};
    auto it = std::find_if(v.begin(),v.end(),[](int x){return x%2==0;});
    std::cout << *it; }' \
    "8"

CX "stl: std::tuple" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <tuple>
    int main() { auto t = std::make_tuple(1, 2.5, "hi");
    std::cout << std::get<0>(t) << " " << std::get<1>(t) << " " << std::get<2>(t); }' \
    "1 2.5 hi"

CX "stl: std::array" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <array>
    #include <algorithm>
    int main() { std::array<int,5> a{5,2,4,1,3}; std::sort(a.begin(),a.end());
    for(auto x:a) std::cout << x; }' \
    "12345"

CX "stl: std::regex" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <regex>
    int main() { std::string s = "abc123def456";
    std::regex re("\\d+"); std::smatch m;
    std::regex_search(s,m,re); std::cout << m[0]; }' \
    "123"

CX "stl: std::chrono" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <chrono>
    int main() { using namespace std::chrono;
    auto d = hours(1) + minutes(30); std::cout << duration_cast<minutes>(d).count(); }' \
    "90"

########################################
echo ""
echo "=== 10. ADVANCED FEATURES ==="
########################################

CX "adv: CRTP pattern" "-std=c++17" "-O2" \
    '#include <iostream>
    template<typename D> struct Base { void call() { static_cast<D*>(this)->impl(); } };
    struct Derived : Base<Derived> { void impl() { std::cout << "crtp"; } };
    int main() { Derived d; d.call(); }' \
    "crtp"

CX "adv: type erasure (std::function)" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <functional>
    int apply(std::function<int(int)> f, int x) { return f(x); }
    int main() { std::cout << apply([](int x){return x*3;}, 14); }' \
    "42"

CX "adv: SFINAE" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <type_traits>
    template<typename T, std::enable_if_t<std::is_integral_v<T>, int> = 0>
    const char* classify(T) { return "int"; }
    template<typename T, std::enable_if_t<std::is_floating_point_v<T>, int> = 0>
    const char* classify(T) { return "float"; }
    int main() { std::cout << classify(42) << " " << classify(3.14); }' \
    "int float"

CX "adv: perfect forwarding" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <utility>
    void process(int& x) { std::cout << "lref"; }
    void process(int&& x) { std::cout << "rref"; }
    template<typename T> void fwd(T&& x) { process(std::forward<T>(x)); }
    int main() { int a=1; fwd(a); fwd(42); }' \
    "lrefrref"

CX "adv: constexpr computation" "-std=c++17" "-O2" \
    '#include <iostream>
    constexpr int factorial(int n) { int r=1; for(int i=2;i<=n;i++) r*=i; return r; }
    int main() { static_assert(factorial(10)==3628800); std::cout << factorial(10); }' \
    "3628800"

CX "adv: thread_local" "-std=c++17" "-O2" \
    '#include <iostream>
    thread_local int tls = 42;
    int main() { std::cout << tls; tls = 99; std::cout << " " << tls; }' \
    "42 99"

CX "adv: alignas/alignof" "-std=c++17" "-O2" \
    '#include <iostream>
    struct alignas(16) Aligned { int x; };
    int main() { std::cout << alignof(Aligned) << " " << sizeof(Aligned); }' \
    "16 16"

CX "adv: placement new" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <new>
    struct S { int x; S(int v):x(v){} };
    int main() { alignas(S) char buf[sizeof(S)];
    S* p = new(buf) S(42); std::cout << p->x; p->~S(); }' \
    "42"

CX "adv: multiple inheritance + virtual" "-std=c++17" "-O2" \
    '#include <iostream>
    struct A { virtual int val() = 0; };
    struct B { virtual int num() = 0; };
    struct C : A, B { int val() override { return 1; } int num() override { return 2; } };
    int main() { C c; A* a=&c; B* b=&c; std::cout << a->val() << b->num(); }' \
    "12"

CX "adv: operator overloading" "-std=c++17" "-O2" \
    '#include <iostream>
    struct Vec { int x,y;
    Vec operator+(const Vec& o) const { return {x+o.x, y+o.y}; }
    friend std::ostream& operator<<(std::ostream& os, const Vec& v) {
    return os << "(" << v.x << "," << v.y << ")"; } };
    int main() { Vec a{1,2}, b{3,4}; std::cout << a+b; }' \
    "(4,6)"

CX "adv: recursive templates (fibonacci)" "-std=c++17" "-O2" \
    '#include <iostream>
    template<int N> struct Fib { static constexpr int val = Fib<N-1>::val + Fib<N-2>::val; };
    template<> struct Fib<0> { static constexpr int val = 0; };
    template<> struct Fib<1> { static constexpr int val = 1; };
    int main() { std::cout << Fib<20>::val; }' \
    "6765"

########################################
echo ""
echo "=== 11. PREPROCESSOR + DIAGNOSTICS ==="
########################################

TOTAL=$((TOTAL+1))
label="cpp: preprocessor output (-E)"
echo '#define X 42
int main() { return X; }' > "$TMPDIR/gcc_test_pp.c"
if $GCC -E "$TMPDIR/gcc_test_pp.c" 2>/dev/null | grep -q "return 42"; then
    PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
else
    FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
    ERRORS="$ERRORS\n  $label"
fi
rm -f "$TMPDIR/gcc_test_pp.c"

TOTAL=$((TOTAL+1))
label="cpp: predefined macros"
if $GCC -dM -E - < /dev/null 2>/dev/null | grep -q __GNUC__; then
    PASS=$((PASS+1)); printf "  %-55s PASS\n" "$label"
else
    FAIL=$((FAIL+1)); printf "  %-55s FAIL\n" "$label"
    ERRORS="$ERRORS\n  $label"
fi

T "cpp: -Werror catches warnings" \
    "echo 'int main(){int x;}' | $GCC -x c -Werror -Wunused-variable - -o /dev/null 2>&1 | grep -q error"

T "cpp: dependency generation (-MM)" \
    "echo '#include <stdio.h>
    int main(){}' > $TMPDIR/gcc_test_dep.c && $GCC -MM $TMPDIR/gcc_test_dep.c 2>/dev/null | grep -q gcc_test_dep && rm -f $TMPDIR/gcc_test_dep.c"

########################################
echo ""
echo "=== 12. COMPILER FLAGS ==="
########################################

T "flag: -mcpu=native works" "$GCC -mcpu=native -x c -c /dev/null -o /dev/null 2>/dev/null"
T "flag: -pipe works" "$GCC -pipe -x c -c /dev/null -o /dev/null 2>/dev/null"
T "flag: -Wall -Wextra -pedantic" "$GXX -Wall -Wextra -pedantic -std=c++17 -x c++ -c /dev/null -o /dev/null 2>/dev/null"
T "flag: -fPIC" "$GCC -fPIC -x c -c /dev/null -o /dev/null 2>/dev/null"
T "flag: -static (compile)" "$GCC -static -x c -c /dev/null -o /dev/null 2>/dev/null"

CC "flag: -mcpu=G3 targeting" "-std=c11" "-O2 -mcpu=G3" \
    '#include <stdio.h>
    int main() { printf("g3"); return 0; }' \
    "g3"

CC "flag: -mcpu=G4 targeting" "-std=c11" "-O2 -mcpu=G4" \
    '#include <stdio.h>
    int main() { printf("g4"); return 0; }' \
    "g4"

CC "flag: -mcpu=970 (G5) targeting" "-std=c11" "-O2 -mcpu=970" \
    '#include <stdio.h>
    int main() { printf("g5"); return 0; }' \
    "g5"

########################################
echo ""
echo "=== 13. REAL-WORLD PATTERNS ==="
########################################

CX "real: JSON-like parser" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <string>
    #include <variant>
    #include <map>
    #include <vector>
    using JSON = std::variant<int, std::string, std::vector<int>>;
    int main() {
    std::map<std::string, JSON> obj;
    obj["name"] = std::string("test");
    obj["value"] = 42;
    obj["list"] = std::vector<int>{1,2,3};
    std::cout << std::get<std::string>(obj["name"]) << " "
              << std::get<int>(obj["value"]) << " "
              << std::get<std::vector<int>>(obj["list"]).size(); }' \
    "test 42 3"

CX "real: builder pattern" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <string>
    struct Config {
    std::string host="localhost"; int port=80; bool ssl=false;
    Config& setHost(std::string h) { host=h; return *this; }
    Config& setPort(int p) { port=p; return *this; }
    Config& enableSSL() { ssl=true; return *this; }
    };
    int main() { auto c = Config().setHost("example.com").setPort(443).enableSSL();
    std::cout << c.host << ":" << c.port << (c.ssl?" ssl":""); }' \
    "example.com:443 ssl"

CX "real: observer pattern" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <vector>
    #include <functional>
    struct Event {
    std::vector<std::function<void(int)>> listeners;
    void subscribe(std::function<void(int)> f) { listeners.push_back(f); }
    void emit(int v) { for(auto& f:listeners) f(v); }
    };
    int main() { Event e; int sum=0;
    e.subscribe([&](int v){ sum+=v; });
    e.subscribe([&](int v){ sum+=v*2; });
    e.emit(10); std::cout << sum; }' \
    "30"

CX "real: compile-time string hash" "-std=c++17" "-O2" \
    '#include <iostream>
    constexpr unsigned fnv1a(const char* s) {
    unsigned h=2166136261u;
    while(*s) { h^=*s++; h*=16777619u; } return h; }
    int main() { constexpr auto h = fnv1a("hello");
    static_assert(h != 0); std::cout << h; }' \
    "1335831723"

CX "real: simple state machine" "-std=c++17" "-O2" \
    '#include <iostream>
    #include <variant>
    struct Idle{}; struct Running{int n;}; struct Done{int result;};
    using State = std::variant<Idle, Running, Done>;
    State step(State s) {
    return std::visit([](auto& st) -> State {
    using T = std::decay_t<decltype(st)>;
    if constexpr(std::is_same_v<T,Idle>) return Running{0};
    else if constexpr(std::is_same_v<T,Running>) {
    if(st.n>=5) return Done{st.n}; return Running{st.n+1}; }
    else return st; }, s); }
    int main() { State s = Idle{};
    while(!std::holds_alternative<Done>(s)) s = step(s);
    std::cout << std::get<Done>(s).result; }' \
    "5"

########################################
echo ""
echo "========================================="
END=$(date +%s)
ELAPSED=$((END - START))
echo " Results: $PASS/$TOTAL passed, $FAIL failed ($ELAPSED seconds)"
echo "========================================="
if [ $FAIL -gt 0 ]; then
    echo ""
    echo " Failed tests:"
    printf "$ERRORS\n"
fi
echo ""
