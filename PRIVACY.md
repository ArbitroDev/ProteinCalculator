# Politique de confidentialité — Protein Calculator

*[English version below](#privacy-policy--protein-calculator)*

**Date d'entrée en vigueur : 14 octobre 2026**

Cette politique explique quelles données l'application **Protein Calculator** (Android) traite,
pourquoi, et quels sont tes droits. Elle s'applique à l'application publiée sur Google Play.

## Qui est responsable

Protein Calculator est développée et publiée par **ArbitroDev**, responsable du traitement.
Contact : <arbitro.contact@gmail.com>.

## En résumé

- Pas de compte, pas de publicité, pas de suivi publicitaire, pas de revente de données.
- Ton suivi (entrées, produits, objectif, réglages) **reste sur ton téléphone**, et sur ta
  montre si tu en utilises une. Nous n'y avons jamais accès.
- Deux choses seulement peuvent quitter ton téléphone : un **rapport d'erreur technique**,
  **seulement si tu l'acceptes** (désactivé par défaut), et le **code-barres** d'un produit que tu
  scannes, envoyé à **Open Food Facts** pour en trouver les valeurs.
- L'appareil photo ne sert qu'à lire les codes-barres : l'image est analysée **sur ton téléphone**
  et n'en sort jamais.
- Si tu utilises l'application sur une montre Wear OS, ton téléphone et ta montre échangent ton
  suivi **directement**, sans passer par un serveur.

## 1. Données stockées sur ton appareil

L'application enregistre localement, dans une base de données sur ton téléphone :

- tes entrées (nom facultatif, quantités, protéines, date et heure) ;
- tes produits enregistrés, ton produit favori et leurs routines quotidiennes (rappel ou ajout
  automatique, et son heure) ;
- les codes-barres de tes produits, et les derniers produits scannés avec les valeurs données par
  Open Food Facts ;
- ton objectif quotidien et tes réglages (tri des produits, choix concernant les rapports
  d'erreur).

Ces données ne sont **ni envoyées à nous ni à un tiers**, à l'exception du code-barres d'un
produit scanné, envoyé à Open Food Facts (voir la section 2). Tu peux les supprimer à tout moment
en supprimant les entrées et produits dans l'application, en effaçant les données de l'application
dans les réglages d'Android, ou en la désinstallant.

**Export et import.** Si tu utilises « Exporter mes données », un fichier est créé à l'endroit que
tu choisis. Ce que tu en fais ensuite (le garder, le partager) relève de ton choix ; nous n'y
avons pas accès.

**Sauvegarde Android.** Si la sauvegarde Google est activée sur ton appareil, Android peut inclure
les données de l'application dans cette sauvegarde. Elle est gérée par Google, chiffrée, liée à
ton compte Google et inaccessible pour nous. Tu peux la désactiver dans les réglages de ton
téléphone.

**Capteurs.** L'accéléromètre sert uniquement à animer le shaker de l'écran principal (liquide
qui reste à niveau, mélange quand tu secoues). Ses mesures sont traitées sur le moment, sur ton
appareil, et ne sont ni enregistrées ni transmises.

**Montre Wear OS (facultative).** Si tu installes l'application sur ta montre Wear OS, ton
téléphone lui envoie le total, l'objectif et les entrées du jour ainsi que tes produits
enregistrés, et ta montre lui envoie les entrées que tu y ajoutes (une portion d'un produit, ou
des grammes avec un nom facultatif) et celles que tu y supprimes. Ces échanges se font
**directement entre ton téléphone et ta montre**, en Bluetooth ou sur le même réseau Wi-Fi, par
les services Google Play de tes appareils : ils ne passent par **aucun serveur**, ni le nôtre ni
celui de Google. Quand ta montre est hors de portée, rien n'est envoyé : ces ajouts et
suppressions attendent sur la montre que le téléphone revienne. La montre garde une copie de la
journée et de tes produits, et ce qui attend ; elle n'a pas accès à Internet et ses données sont
exclues des sauvegardes. Pour les supprimer, désinstalle l'application de la montre. Le nom d'une
entrée se tape ou se dicte avec le clavier ou la dictée de ta montre : l'application n'en reçoit
que le texte.

## 2. Scan des codes-barres (facultatif)

**Appareil photo.** La première fois que tu touches le bouton de scan, l'application te demande
l'accès à l'appareil photo. L'image de la caméra est analysée **sur ton téléphone**, par une
bibliothèque libre (zxing-cpp), sans service de Google ni d'aucun tiers : elle n'est **ni
enregistrée ni transmise**. Tu peux aussi saisir le code à la main.

**Ce qui est envoyé.** Si le produit n'est pas déjà sur ton téléphone, ou si ses valeurs datent de
plus de 30 jours, l'application envoie **uniquement son code-barres** à **Open Food Facts**, une
base de données libre et collaborative de produits alimentaires gérée par l'association Open Food
Facts (France), pour obtenir son nom, sa marque, sa teneur en protéines et sa portion. Comme pour
toute connexion à Internet, Open Food Facts voit aussi l'adresse IP de ton téléphone ; la demande
indique le nom et la version de l'application et notre adresse de contact, comme Open Food Facts
le demande aux applications. Rien d'autre n'est envoyé : ni tes entrées, ni tes produits, ni ton
objectif, ni aucun identifiant. Nous ne recevons rien de ces échanges.

**Ce qui est gardé.** Les réponses restent sur ton téléphone, pour ne pas redemander le même
produit : les 20 derniers produits scannés, et les dernières valeurs connues de tes produits qui
ont un code-barres. Les produits scannés ne figurent pas dans l'export de tes données ; le
code-barres de tes produits enregistrés, si. Rien n'est ajouté à ton suivi sans que tu le valides.

**Base légale.** L'envoi n'a lieu qu'à ta demande, quand tu scannes ou saisis un code, pour te
rendre le service que tu utilises (article 6.1.b du RGPD). Pour l'éviter, remplis les valeurs à la
main. Open Food Facts traite ces demandes selon sa propre politique de confidentialité :
<https://world.openfoodfacts.org/privacy>.

## 3. Rapports d'erreur (facultatifs)

Pour corriger les bugs, l'application peut envoyer des rapports d'erreur à **Sentry**, un service
de suivi des erreurs. Cet envoi est **désactivé par défaut** : il n'a lieu que si tu coches la case
proposée au premier lancement ou si tu l'actives dans **Menu → Données et confidentialité**. Tu
peux le désactiver à tout moment au même endroit ; l'arrêt est immédiat.

**Ce qu'un rapport contient :**

- la description technique de l'erreur et l'endroit du code où elle s'est produite ;
- la version de l'application ;
- des informations techniques sur l'appareil et le système : modèle, fabricant, version
  d'Android, langue, et des caractéristiques telles que la taille de l'écran ou la mémoire
  disponible ;
- un identifiant aléatoire propre à l'installation, généré par le service, sans lien avec ton
  identité ;
- un historique technique des derniers événements de l'application (par exemple l'écran ouvert),
  sans contenu saisi.

**Ce qu'un rapport ne contient jamais :** tes entrées, tes produits, ton objectif, les
codes-barres que tu scannes, ton nom, ton adresse e-mail, des captures d'écran ou ta localisation.
L'adresse IP de connexion, nécessairement vue lors de l'envoi, **n'est pas conservée** (réglage
activé sur notre projet Sentry).

**Finalité et base légale.** Les rapports servent uniquement à détecter et corriger les
erreurs de l'application. Leur envoi repose sur ton **consentement** (article 6.1.a du RGPD),
que tu peux retirer à tout moment.

**Hébergement et durée de conservation.** Les rapports sont hébergés par Sentry (Functional
Software, Inc.) dans sa **région de données de l'Union européenne** (Allemagne). Ils sont
supprimés automatiquement par Sentry au bout de **90 jours au plus**. Sentry agit en tant que
sous-traitant ; s'il fait appel à des prestataires situés hors de l'Union européenne, les
transferts sont encadrés par les garanties prévues par le RGPD (clauses contractuelles types de
la Commission européenne ou cadre de protection des données UE–États-Unis). Voir la politique de
confidentialité de Sentry : <https://sentry.io/privacy/>.

**Sécurité.** Les rapports sont transmis de façon chiffrée (HTTPS).

## 4. Partage des données

Nous ne vendons, ne louons et ne partageons aucune donnée. En dehors de Sentry pour les rapports
d'erreur que tu as acceptés, et d'Open Food Facts qui reçoit le code-barres des produits que tu
scannes, aucun tiers ne reçoit de données de l'application. L'application ne contient ni
publicité, ni outil d'analyse d'audience.

## 5. Autorisations Android

- **Internet** : utilisée pour chercher sur Open Food Facts les produits que tu scannes, et pour
  envoyer les rapports d'erreur si tu les as acceptés.
- **Appareil photo** : demandée la première fois que tu scannes un code-barres, uniquement pour le
  lire. L'image est analysée sur ton téléphone ; elle n'est ni enregistrée ni transmise.
- **Notifications** : demandée quand tu choisis une routine quotidienne pour un produit, pour te
  le rappeler ou te dire qu'il a été ajouté. Les notifications sont créées sur ton téléphone ;
  rien n'est envoyé.
- **Démarrage du téléphone** : permet de reprogrammer ces notifications après un redémarrage.
- **Alarmes et rappels** : permet d'afficher ces notifications à l'heure choisie. Sans elle,
  Android peut les retarder.

L'application ne demande ni la localisation, ni les contacts, ni le micro.

L'application de la montre n'a pas l'autorisation Internet. Elle n'utilise que des autorisations
techniques, accordées à l'installation, pour envoyer en arrière-plan les ajouts et suppressions
en attente, même après un redémarrage de la montre.

## 6. Tes droits

Conformément au RGPD, tu disposes d'un droit d'accès, de rectification, d'effacement, de
limitation, d'opposition et de retrait de ton consentement. Les données de suivi étant
uniquement sur ton appareil, tu les contrôles directement. Pour les rapports d'erreur, ils ne
contiennent aucune information permettant de t'identifier ; pour toute demande, écris-nous à
l'adresse ci-dessus. Pour les codes-barres reçus par Open Food Facts, adresse-toi à lui, comme
l'indique sa politique de confidentialité. Tu peux aussi déposer une réclamation auprès de
l'autorité de protection des données de ton pays (en France, la CNIL : <https://www.cnil.fr>).

## 7. Enfants

L'application n'est pas destinée aux enfants de moins de 13 ans et ne collecte sciemment aucune
donnée les concernant.

## 8. Modifications

Cette politique peut évoluer, par exemple si l'application change. La date d'entrée en vigueur en
haut de page sera alors mise à jour. Toute nouvelle collecte de données ferait l'objet d'une
demande de consentement dans l'application.

---

# Privacy policy — Protein Calculator

**Effective date: October 14, 2026**

This policy explains what data the **Protein Calculator** Android app processes, why, and what
your rights are. It applies to the app published on Google Play.

## Who is responsible

Protein Calculator is developed and published by **ArbitroDev**, the data controller.
Contact: <arbitro.contact@gmail.com>.

## In short

- No account, no ads, no ad tracking, no data sale.
- Your tracking data (entries, products, goal, settings) **stays on your phone**, and on your
  watch if you use one. We never have access to it.
- Only two things may leave your phone: a **technical crash report**, **only if you agree** (off by
  default), and the **barcode** of a product you scan, sent to **Open Food Facts** to find its
  values.
- The camera is only used to read barcodes: the picture is analyzed **on your phone** and never
  leaves it.
- If you use the app on a Wear OS watch, your phone and your watch exchange your tracking data
  **directly**, without going through a server.

## 1. Data stored on your device

The app stores locally, in a database on your phone:

- your entries (optional name, quantities, protein, date and time);
- your saved products, your favorite product and their daily routines (reminder or automatic
  addition, and its time);
- the barcodes of your products, and the latest products scanned with the values given by Open Food
  Facts;
- your daily goal and your settings (product sort, crash report choice).

This data is **never sent to us or to any third party**, except the barcode of a product scanned,
sent to Open Food Facts (see section 2). You can delete it at any time by deleting entries and
products in the app, by clearing the app's data in Android settings, or by uninstalling the app.

**Export and import.** If you use "Export my data", a file is created where you choose. What you
do with it afterwards (keep it, share it) is up to you; we have no access to it.

**Android backup.** If Google backup is turned on for your device, Android may include the app's
data in that backup. It is managed by Google, encrypted, tied to your Google account and not
accessible to us. You can turn it off in your phone settings.

**Sensors.** The accelerometer is only used to animate the shaker on the main screen (the liquid
staying level, mixing when you shake). Its readings are processed on the fly, on your device,
and are neither stored nor sent.

**Wear OS watch (optional).** If you install the app on your Wear OS watch, your phone sends it
the total, the goal and the entries of the day and your saved products, and your watch sends it
the entries you add there (a portion of a product, or grams with an optional name) and the ones
you delete there. These exchanges go **directly between your phone and your watch**,
over Bluetooth or the same Wi-Fi network, through the Google Play services of your devices: they
go through **no server**, neither ours nor Google's. When your watch is out of range, nothing is
sent: these additions and deletions wait on the watch for the phone to come back. The watch keeps
a copy of the day and of your products, and what waits; it has no Internet access and its data is
left out of backups. To delete it, uninstall the app from the watch. The name of an entry is typed
or dictated with the keyboard or the dictation of your watch: the app only gets its text.

## 2. Barcode scanning (optional)

**Camera.** The first time you tap the scan button, the app asks for access to the camera. The
camera picture is analyzed **on your phone**, by an open source library (zxing-cpp), with no
Google or other third-party service: it is **neither stored nor sent**. You can also type the
code.

**What is sent.** If the product is not on your phone yet, or if its values are more than 30 days
old, the app sends **only its barcode** to **Open Food Facts**, a free and collaborative database
of food products run by the Open Food Facts association (France), to get its name, brand, protein
content and serving. As with any Internet connection, Open Food Facts also sees the IP address of
your phone; the request gives the name and version of the app and our contact address, as Open
Food Facts asks of apps. Nothing else is sent: none of your entries, products or goal, and no
identifier. We receive nothing from these exchanges.

**What is kept.** The answers stay on your phone, so the same product is not asked again: the 20
latest products scanned, and the latest known values of your products that have a barcode. The
products scanned are not in the export of your data; the barcode of your saved products is.
Nothing is added to your tracking without your approval.

**Legal basis.** The barcode is only sent at your request, when you scan or type a code, to
provide the feature you use (Article 6(1)(b) GDPR). To avoid it, fill in the values yourself. Open
Food Facts processes these requests under its own privacy policy:
<https://world.openfoodfacts.org/privacy>.

## 3. Crash reports (optional)

To fix bugs, the app can send crash reports to **Sentry**, an error tracking service. This is
**off by default**: it only happens if you check the box offered on first launch or turn it on
in **Menu → Data and privacy**. You can turn it off at any time in the same place; it stops at
once.

**A report contains:**

- the technical description of the error and where in the code it happened;
- the app version;
- technical information about the device and system: model, manufacturer, Android version,
  language, and characteristics such as screen size or available memory;
- a random installation identifier generated by the service, not linked to your identity;
- a technical history of the app's latest events (for example the screen opened), without any
  content you typed.

**A report never contains:** your entries, products or goal, the barcodes you scan, your name,
your email address, screenshots or your location. The connection IP address, necessarily seen when
sending, **is not stored** (setting turned on for our Sentry project).

**Purpose and legal basis.** Reports are only used to detect and fix errors in the app. Sending
them relies on your **consent** (Article 6(1)(a) GDPR), which you can withdraw at any time.

**Hosting and retention.** Reports are hosted by Sentry (Functional Software, Inc.) in its
**European Union data region** (Germany). Sentry deletes them automatically after **90 days at
most**. Sentry acts as a processor; where it relies on providers outside the European Union,
transfers are covered by the safeguards provided by the GDPR (European Commission standard
contractual clauses or the EU–U.S. Data Privacy Framework). See Sentry's privacy policy:
<https://sentry.io/privacy/>.

**Security.** Reports are sent encrypted (HTTPS).

## 4. Data sharing

We do not sell, rent or share any data. Apart from Sentry for the crash reports you agreed to, and
Open Food Facts, which receives the barcode of the products you scan, no third party receives data
from the app. The app contains no ads and no audience analytics.

## 5. Android permissions

- **Internet**: used to look up the products you scan on Open Food Facts, and to send crash reports
  if you agreed to them.
- **Camera**: requested the first time you scan a barcode, only to read it. The picture is analyzed
  on your phone; it is neither stored nor sent.
- **Notifications**: requested when you choose a daily routine for a product, to remind you of it
  or tell you it was added. Notifications are created on your phone; nothing is sent.
- **Phone startup**: lets the app plan these notifications again after a restart.
- **Alarms & reminders**: lets the app show these notifications at the chosen time. Without it,
  Android may delay them.

The app does not request location, contacts or microphone access.

The watch app has no Internet permission. It only uses technical permissions, granted on
install, to send the waiting additions and deletions in the background, even after the watch
restarts.

## 6. Your rights

Under the GDPR, you have the right of access, rectification, erasure, restriction, objection and
withdrawal of consent. Your tracking data is only on your device, so you control it directly.
Crash reports contain no information identifying you; for any request, write to us at the address
above. For the barcodes Open Food Facts receives, contact it as its privacy policy says. You may
also lodge a complaint with your country's data protection authority (in France, the CNIL:
<https://www.cnil.fr>).

## 7. Children

The app is not intended for children under 13 and does not knowingly collect data about them.

## 8. Changes

This policy may change, for example if the app changes. The effective date at the top will then
be updated. Any new data collection would be subject to a consent request in the app.
