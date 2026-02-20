class PhoneNumber {
  PhoneNumber(this.value)
      : assert(value.trim().isNotEmpty, 'Phone number cannot be empty');

  final String value;
}
