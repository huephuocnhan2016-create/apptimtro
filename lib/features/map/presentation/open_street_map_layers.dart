import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

TileLayer openStreetMapTileLayer() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.example.apptimtro',
);

RichAttributionWidget openStreetMapAttribution() => RichAttributionWidget(
  showFlutterMapAttribution: false,
  attributions: [
    TextSourceAttribution(
      'OpenStreetMap contributors',
      onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
    ),
  ],
);
