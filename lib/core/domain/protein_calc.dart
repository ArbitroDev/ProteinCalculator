/// Default reference quantity for the protein content of a product.
const defaultReferenceGrams = 100.0;

/// Protein grams in [consumedGrams] of a product containing
/// [proteinPerReference] grams of protein per [referenceGrams], rounded to
/// one decimal like the protein amounts typed: 15.75 g makes 15.8 g.
double computeProtein({
  required double consumedGrams,
  required double proteinPerReference,
  required double referenceGrams,
}) => (consumedGrams * proteinPerReference / referenceGrams * 10).round() / 10;
