class Price {
  const Price(this.value) : assert(value >= 0, 'Price cannot be negative');

  final double value;
}
