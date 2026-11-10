import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

TileLayer openStreetMapTileLayer() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.trotot.app',
);

RichAttributionWidget openStreetMapAttribution() => RichAttributionWidget(
  showFlutterMapAttribution: false,
  attributions: [
    TextSourceAttribution(
      'OpenStreetMap contributors',
      onTap: () =>
          launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
    ),
  ],
);
