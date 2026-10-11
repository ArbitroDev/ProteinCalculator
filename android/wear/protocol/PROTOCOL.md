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
watch comes nearby. Also the answer to `/protein_calculator/sync`, and part of
the answers to `/protein_calculator/add` and `/protein_calculator/delete`.

```json
{
  "v": 1,
  "day": 20261008,
  "dayStartHour": 3,
  "total": 87.5,
  "goal": 140.0,
  "entries": [
    { "id": 42, "name": "Skyr", "protein": 25.0, "time": 1791637440000, "fromWatch": true }
  ],
  "products": [
    { "id": 3, "name": "Skyr", "protein": 25.0, "favorite": true }
  ],
  "handled": ["0b6f6f0e-4c1e-4a39-9a8e-5d1f2a3c4b5d"]
}
```

| Field | Meaning |
|---|---|
| `day` | App day of `total`, as `yyyymmdd`. |
| `dayStartHour` | Hour the app days start, from 0 to 7: the watch starts a new day at that hour, with a total of zero, without waiting for the phone. |
| `total` | Protein grams of the entries of `day`, exact. The watch truncates it to the unit, as the phone app does. |
| `goal` | Goal of `day` in grams, or `null` until the first launch of the phone app is done. |
| `entries` | Entries of `day`, the most recent first, 100 at most. |
| `entries[].id` | Id of the entry on the phone. |
| `entries[].name` | Name of the entry, or `null` for an entry without a name. |
| `entries[].protein` | Protein grams of the entry. |
| `entries[].time` | When it was added, in milliseconds since the epoch. |
| `entries[].fromWatch` | Whether it was added on the watch. |
| `products` | Saved products, 100 at most: the favorite first, then in the order chosen in the products tab. |
| `products[].id` | Id of the product on the phone. |
| `products[].name` | Name of the product. |
| `products[].protein` | Protein grams of one portion. |
| `products[].favorite` | Whether it is the favorite product; one at most. |
| `handled` | Ids of the additions and deletions of the watch the phone made since the start of the previous app day (see below). |

A state whose values are out of range (a date that does not exist, a negative
total...) is ignored.

### Request for the state: `/protein_calculator/sync`

Request (`MessageClient.sendRequest`) of the watch, answered by the phone with
the state of the day, even when the phone app is closed.

```json
{ "v": 1 }
```

### Additions: `/protein_calculator/add`

Request of the watch, answered by the phone once the additions are made, even
when the phone app is closed. A tap on a product adds one portion of it on the
watch at once, as does a free entry of protein grams typed on the watch: the watch keeps it, with a random id, until the phone answers
for it, and sends it again each time the phone is nearby, oldest first, 50 at
most at once.

```json
{
  "v": 1,
  "requests": [
    {
      "id": "0b6f6f0e-4c1e-4a39-9a8e-5d1f2a3c4b5d",
      "productId": 3,
      "name": "Skyr",
      "protein": 25.0,
      "addedAt": 1791637440000
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | Random id of the addition, 64 characters at most, the same each time it is sent. |
| `productId` | Id of the product on the phone, or `null` for a free entry. |
| `name`, `protein` | Name and protein grams of one portion, as the watch showed them; for a free entry, those typed, the name `null` if none was given. A product always has a name. |
| `addedAt` | When it was added on the watch, in milliseconds since the epoch. |

The phone adds each one at its time (its app day and part of the day follow
from it), or at the current time if it says later:

- a portion of the product of that id, if it still has that name;
- otherwise (a free entry, product deleted, or ids changed by a backup
  restored), an entry with the name and protein the watch showed: the
  addition is never lost.

It saves the id with the entry, at once: an addition sent again, its answer
lost, is not made twice. Ids are kept 60 days.

```json
{
  "v": 1,
  "results": [
    { "id": "0b6f6f0e-4c1e-4a39-9a8e-5d1f2a3c4b5d", "status": "added" }
  ],
  "state": { "day": 20261008, "dayStartHour": 3, "total": 112.5, "goal": 140.0, "entries": [], "products": [], "handled": [] }
}
```

| `status` | Meaning |
|---|---|
| `added` | Made now. |
| `duplicate` | Already made from an earlier sending. |
| `invalid` | Values the phone cannot add (a blank name, a protein out of range...): the watch drops it. |

The watch drops the additions the answer gives a status for, and those listed
in `handled` of any state it receives.

### Deletions: `/protein_calculator/delete`

Request of the watch, answered by the phone once the deletions are made, even
when the phone app is closed. Swiping an entry of the day deletes it on the
watch, after a few seconds to undo it:

- an entry the phone has not made yet, waiting on the watch, is dropped
  there: nothing is sent;
- otherwise the watch hides the entry and keeps the deletion, with a random
  id, until the phone answers for it, and sends it again each time the phone
  is nearby, oldest first, 50 at most at once, after the waiting additions.

```json
{
  "v": 1,
  "requests": [
    {
      "id": "6d3a1c2e-8f4b-4e7a-b1d2-0c9e8f7a6b5c",
      "entryId": 42,
      "time": 1791637440000
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | Random id of the deletion, 64 characters at most, the same each time it is sent. |
| `entryId` | Id of the entry on the phone, from the state of the day. |
| `time` | Time of the entry, from the state of the day. |

The phone deletes the entry of that id only if it still has that time: after
a backup is restored, the id may name another entry. It saves the id of the
deletion at once, as for the additions: a deletion sent again, its answer
lost, is not made twice.

```json
{
  "v": 1,
  "results": [
    { "id": "6d3a1c2e-8f4b-4e7a-b1d2-0c9e8f7a6b5c", "status": "deleted" }
  ],
  "state": { "day": 20261008, "dayStartHour": 3, "total": 87.5, "goal": 140.0, "entries": [], "products": [], "handled": [] }
}
```

| `status` | Meaning |
|---|---|
| `deleted` | Made now. |
| `duplicate` | Already made from an earlier sending. |
| `missing` | No entry of that id and time: already deleted on the phone, or changed by a backup restored. |
| `invalid` | Values the phone cannot read: the watch drops it. |

The watch drops the deletions the answer gives a status for, and those listed
in `handled` of any state it receives.
