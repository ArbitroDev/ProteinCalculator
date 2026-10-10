# Messages between the phone app and the watch app

The phone app and its Wear OS watch app exchange the messages below through
the `MessageClient` of the Wearable Data Layer API, from Google Play services.
This module is the only place where they are written and read: both apps use
it.

## Nearby devices only

Messages only go between **nearby** devices, connected by Bluetooth or on the
same Wi-Fi network (`Node.isNearby`). Google Play services can also carry
messages between distant devices through Google servers: the apps never send
to such a device, and the phone does not answer a request coming from one.
The `DataClient`, which may sync through Google servers, is not used.

## Format

Each message is a JSON object in UTF-8. Its `v` field holds the version of
the messages it belongs to, an integer, currently **1**.

- Any change of the messages (a field added, removed, renamed, or used with
  another meaning) comes with a new version, written here.
- A message of a version the app does not read is never read: its fields may
  mean something else. A request of such a version is answered with
  `{"unsupported": [1]}`, the versions the app reads. This answer never
  changes, whatever the version. The watch then tells the user which app to
  update.

## Finding the other device

Each app sends to the devices connected to its own (`NodeClient`), nearby
ones only: a device without the app drops the message. The capabilities
below, declared in the resources of each app (`android_wear_capabilities`),
only tell when the other app comes nearby: Google Play services may take a
while to sync them, so they are not needed to send.

| Capability | Declared by |
|---|---|
| `protein_calculator_phone` | The phone app |
| `protein_calculator_watch_v1` | The watch app, reading the messages of version 1 |

## Version 1

### State of the day: `/protein_calculator/state`

Sent by the phone to the watch when the day changes (an entry, the goal, the
products, the start of a new day), when the phone app starts, and when the
watch comes nearby. Also the answer to `/protein_calculator/sync`.

```json
{
  "v": 1,
  "day": 20261008,
  "dayStartHour": 3,
  "total": 87.5,
  "goal": 140.0,
  "products": [
    { "id": 3, "name": "Skyr", "protein": 25.0, "favorite": true }
  ]
}
```

| Field | Meaning |
|---|---|
| `day` | App day of `total`, as `yyyymmdd`. |
| `dayStartHour` | Hour the app days start, from 0 to 7: the watch starts a new day at that hour, with a total of zero, without waiting for the phone. |
| `total` | Protein grams of the entries of `day`, exact. The watch truncates it to the unit, as the phone app does. |
| `goal` | Goal of `day` in grams, or `null` until the first launch of the phone app is done. |
| `products` | Saved products, 100 at most: the favorite first, then in the order chosen in the products tab. |
| `products[].id` | Id of the product on the phone. |
| `products[].name` | Name of the product. |
| `products[].protein` | Protein grams of one portion. |
| `products[].favorite` | Whether it is the favorite product; one at most. |

A state whose values are out of range (a date that does not exist, a negative
total...) is ignored.

### Request for the state: `/protein_calculator/sync`

Request (`MessageClient.sendRequest`) of the watch, answered by the phone with
the state of the day, even when the phone app is closed.

```json
{ "v": 1 }
```
