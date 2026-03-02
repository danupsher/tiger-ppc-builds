// Stub for __throw_bad_array_new_length - needed by new libstdc++ headers
// when linked against old ABI libstdc++.a that lacks this symbol
namespace std {
  void __throw_bad_array_new_length()  __attribute__((__noreturn__));
  void __throw_bad_array_new_length() {
    __builtin_abort();
  }
}
