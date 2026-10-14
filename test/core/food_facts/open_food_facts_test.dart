import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';
import 'package:protein_calculator/core/food_facts/food_facts.dart';
import 'package:protein_calculator/core/food_facts/open_food_facts.dart';

/// Answer of Open Food Facts for a product it knows, as the API v3 gives it.
http.Response found(Map<String, dynamic> product) => http.Response(
  jsonEncode({
    'code': '3017620422003',
    'errors': <Object>[],
    'product': product,
    'result': {'id': 'product_found'},
    'status': 'success',
    'warnings': <Object>[],
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('FoodFacts.fromJson', () {
    FoodFacts read(Map<String, dynamic> product, {String language = 'fr'}) =>
        FoodFacts.fromJson(product, language: language);

    test('reads the name in the language of the app, then the others', () {
      final product = {
        'product_name': 'Coca-Cola',
        'product_name_fr': 'Coca-Cola en canette',
        'product_name_en': 'Coca-Cola can',
      };
      expect(read(product).name, 'Coca-Cola en canette');
      expect(read(product, language: 'en').name, 'Coca-Cola can');
      expect(read({...product, 'product_name_fr': ' '}).name, 'Coca-Cola');
      expect(read({'product_name_en': 'Skyr'}).name, 'Skyr');
      expect(read({}).name, isNull);
    });

    test('reads the protein content, also given as text', () {
      expect(
        read({
          'nutriments': {'proteins_100g': 6.3},
        }).proteinPer100,
        6.3,
      );
      expect(
        read({
          'nutriments': {'proteins_100g': '10,5'},
        }).proteinPer100,
        10.5,
      );
      expect(
        read({
          'nutriments': {'proteins_100g': 0},
        }).proteinPer100,
        0,
      );
      // One decimal, as typed in the form.
      expect(
        read({
          'nutriments': {'proteins_100g': 6.36},
        }).proteinPer100,
        6.4,
      );
    });

    test('leaves out a protein content missing or out of range', () {
      expect(read({}).proteinPer100, isNull);
      expect(read({'nutriments': <String, Object>{}}).proteinPer100, isNull);
      expect(
        read({
          'nutriments': {'proteins_100g': -1},
        }).proteinPer100,
        isNull,
      );
      expect(
        read({
          'nutriments': {'proteins_100g': 101},
        }).proteinPer100,
        isNull,
      );
      expect(
        read({
          'nutriments': {'proteins_100g': 'a'},
        }).proteinPer100,
        isNull,
      );
    });

    test('reads the serving in grams, a whole number', () {
      final facts = read({
        'serving_quantity': '30.4',
        'serving_quantity_unit': 'g',
      });
      expect(facts.servingQuantity, 30);
      expect(facts.unit, QuantityUnit.grams);
      expect(read({'serving_quantity': 15}).servingQuantity, 15);
    });

    test('counts drinks in milliliters', () {
      final can = read({
        'serving_quantity': 330,
        'serving_quantity_unit': 'ml',
      });
      expect(can.servingQuantity, 330);
      expect(can.unit, QuantityUnit.milliliters);
      final bottle = read({'product_quantity_unit': 'ml'});
      expect(bottle.servingQuantity, isNull);
      expect(bottle.unit, QuantityUnit.milliliters);
    });

    test('leaves out a serving in another unit or out of range', () {
      expect(
        read({'serving_quantity': 2, 'serving_quantity_unit': 'cups'})
            .servingQuantity,
        isNull,
      );
      expect(read({'serving_quantity': 0}).servingQuantity, isNull);
      expect(read({'serving_quantity': 20000}).servingQuantity, isNull);
    });
  });

  group('OpenFoodFacts.lookUp', () {
    late List<http.Request> requests;

    Future<FoodFactsAnswer> lookUp(
      FutureOr<http.Response> Function(http.Request) answer,
    ) {
      requests = [];
      final client = MockClient((request) async {
        requests.add(request);
        return answer(request);
      });
      return OpenFoodFacts(
        client,
        appVersion: Future.value('1.3.0'),
      ).lookUp('3017620422003', language: 'fr');
    }

    test('asks for the few fields used, with the app and a contact', () async {
      await lookUp((_) => found({}));

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.host, 'world.openfoodfacts.org');
      expect(request.url.path, '/api/v3/product/3017620422003');
      expect(
        request.url.queryParameters['fields']!.split(','),
        containsAll(['product_name', 'brands', 'nutriments.proteins_100g']),
      );
      expect(
        request.headers['User-Agent'],
        'ProteinCalculator/1.3.0 (arbitro.contact@gmail.com)',
      );
    });

    test('reads a product found', () async {
      final answer = await lookUp(
        (_) => found({
          'product_name': 'Nutella',
          'brands': 'Nutella',
          'nutriments': {'proteins_100g': 6.3},
        }),
      );

      expect(
        (answer as FoodFactsFound).facts,
        const FoodFacts(name: 'Nutella', brands: 'Nutella', proteinPer100: 6.3),
      );
    });

    test('tells a product it does not know', () async {
      final answer = await lookUp(
        (_) => http.Response(
          jsonEncode({
            'result': {'id': 'product_not_found'},
            'status': 'failure',
          }),
          404,
        ),
      );
      expect(answer, isA<FoodFactsNotFound>());
    });

    test('tells it is busy when it refuses too many requests', () async {
      final answer = await lookUp((_) => http.Response('', 429));
      expect((answer as FoodFactsUnavailable).problem, FoodFactsProblem.busy);
    });

    test('tells a failure of the server or an answer it cannot read', () async {
      for (final response in [
        http.Response('', 500),
        http.Response('<html>', 200),
        http.Response('[]', 200),
      ]) {
        final answer = await lookUp((_) => response);
        expect(
          (answer as FoodFactsUnavailable).problem,
          FoodFactsProblem.failed,
        );
      }
    });

    test('tells the phone is offline', () async {
      final answer = await lookUp(
        (request) => throw http.ClientException('Failed host lookup'),
      );
      expect(
        (answer as FoodFactsUnavailable).problem,
        FoodFactsProblem.offline,
      );
    });

    test('tells there was no answer in time', () async {
      final answer = await lookUp((request) => throw TimeoutException(null));
      expect(
        (answer as FoodFactsUnavailable).problem,
        FoodFactsProblem.timeout,
      );
    });
  });
}
