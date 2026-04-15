part 'baz.dart';

Foo fooFromJson(Map<String, dynamic> json) {
  return Foo(json['name'], json['age']);
}

class Foo {
  String name;
  int age;

  Foo(this.name, this.age);

  void sayHello() {
    final baz = Baz(name, age);
    return baz.sayHello();
  }
}

class Bar {
  String? name;
  int? age;

  Bar(this.name, this.age);

  void sayHello() {}
}
