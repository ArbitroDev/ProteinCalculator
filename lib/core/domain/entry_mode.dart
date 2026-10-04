/// How the protein amount of an entry or a product is expressed.
enum EntryMode {
  /// The protein amount is entered directly, in grams.
  direct,

  /// The protein amount is computed from the quantity consumed and the
  /// protein content of the product for a reference quantity.
  perQuantity,
}
