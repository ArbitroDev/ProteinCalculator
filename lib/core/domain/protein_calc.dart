/// Default reference quantity for the protein content of a product.
const defaultReferenceGrams = 100.0;

/// Protein grams in [consumedGrams] of a product containing
/// [proteinPerReference] grams of protein per [referenceGrams].
double computeProtein({
  required double consumedGrams,
  required double proteinPerReference,
  required double referenceGrams,
}) => consumedGrams * proteinPerReference / referenceGrams;
