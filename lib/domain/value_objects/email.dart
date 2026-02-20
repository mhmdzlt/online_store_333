class Email {
  Email(this.value) : assert(value.contains('@'), 'Invalid email format');

  final String value;
}
