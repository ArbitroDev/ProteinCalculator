import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:protein_calculator/core/food_facts/food_facts.dart';

/// Why Open Food Facts could not tell whether it knows a product.
enum FoodFactsProblem {
  /// The phone has no connection.
  offline,

  /// No answer in time, see [OpenFoodFacts.timeout].
  timeout,

  /// Too many requests from the same address: asked again later, it
  /// answers.
  busy,

  /// The server failed, or its answer could not be read.
  failed,
}

/// Answer of Open Food Facts about a barcode.
sealed class FoodFactsAnswer {
  const FoodFactsAnswer();
}

final class FoodFactsFound extends FoodFactsAnswer {
  const FoodFactsFound(this.facts);

  final FoodFacts facts;
}

final class FoodFactsNotFound extends FoodFactsAnswer {
  const FoodFactsNotFound();
}

final class FoodFactsUnavailable extends FoodFactsAnswer {
  const FoodFactsUnavailable(this.problem);

  final FoodFactsProblem problem;
}

/// Open Food Facts, the open database of food products, asked about the
/// products scanned: only the barcode is sent, with the name and version of
/// the app and a contact, as Open Food Facts asks of the apps using it.
class OpenFoodFacts {
  OpenFoodFacts(this._client, {required this._appVersion});

  final http.Client _client;
  final Future<String> _appVersion;

  /// Longest wait for an answer: the user then fills in the values.
  static const timeout = Duration(seconds: 5);

  static const _host = 'world.openfoodfacts.org';
  static const _contact = 'arbitro.contact@gmail.com';

  /// What is read of a product: nothing more is downloaded.
  static const _fields = [
    'product_name',
    'product_name_fr',
    'product_name_en',
    'brands',
    'nutriments.proteins_100g',
    'serving_quantity',
    'serving_quantity_unit',
    'product_quantity_unit',
  ];

  /// Asks for the product of [barcode], named in [language] when it has a
  /// name in it. Never throws: a failure is an answer too.
  Future<FoodFactsAnswer> lookUp(
    String barcode, {
    required String language,
  }) async {
    final uri = Uri.https(_host, '/api/v3/product/$barcode', {
      'fields': _fields.join(','),
    });
    try {
      final userAgent = 'ProteinCalculator/${await _appVersion} ($_contact)';
      final response = await _client
          .get(uri, headers: {'User-Agent': userAgent})
          .timeout(timeout);
      return switch (response.statusCode) {
        200 => _read(response, language),
        // The answer of a product it does not know.
        404 => const FoodFactsNotFound(),
        429 || 503 => const FoodFactsUnavailable(FoodFactsProblem.busy),
        _ => const FoodFactsUnavailable(FoodFactsProblem.failed),
      };
    } on TimeoutException {
      return const FoodFactsUnavailable(FoodFactsProblem.timeout);
    } on http.ClientException {
      return const FoodFactsUnavailable(FoodFactsProblem.offline);
    } on Object {
      return const FoodFactsUnavailable(FoodFactsProblem.failed);
    }
  }

  static FoodFactsAnswer _read(http.Response response, String language) {
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      return const FoodFactsUnavailable(FoodFactsProblem.failed);
    }
    final result = json['result'];
    final product = json['product'];
    if (result is Map && result['id'] == 'product_found' && product is Map) {
      return FoodFactsFound(
        FoodFacts.fromJson(product.cast<String, dynamic>(), language: language),
      );
    }
    return const FoodFactsNotFound();
  }
}
