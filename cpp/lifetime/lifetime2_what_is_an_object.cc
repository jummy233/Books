#include <iostream>
#include <type_traits>

// what is an object?

struct Int {
  int i;
};

int use_Int() {
  static_assert(sizeof(Int) == sizeof(int));
  Int s{15};

  // reinterpret a struct to the first element of struct.
  int &i = reinterpret_cast<int &>(s);
  i = 23;
  return s.i;
}

int use_int() {
  static_assert(sizeof(int) == sizeof(int));
  int s{15};
  int &i = reinterpret_cast<int &>(s);
  i = 23;
  return i;
}

void trait_check() {
  static_assert(std::is_trivially_constructible<Int>::value);
  static_assert(std::is_trivially_constructible<int>::value);

  static_assert(std::is_trivially_destructible<Int>::value);
  static_assert(std::is_trivially_destructible<int>::value);

  static_assert(std::is_trivially_copyable<Int>::value);
  static_assert(std::is_trivially_copyable<int>::value);

  static_assert(std::is_trivially_move_constructible<Int>::value);
  static_assert(std::is_trivially_move_constructible<int>::value);

  static_assert(std::is_pod<Int>::value);
  static_assert(std::is_pod<int>::value);

  // they both objects
  // an object is a type that is not a function, not a reference, not void.
  // so pretty much everything is an object.
  static_assert(std::is_object<Int>::value);
  static_assert(std::is_object<int>::value);
}

int main(void) {
  trait_check();

  return 0;
}
