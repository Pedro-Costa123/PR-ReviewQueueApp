import 'package:flutter/material.dart';

import '../../shared/widgets.dart';

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key, required this.teamName});
  final String teamName;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageHeading(
        eyebrow: '$teamName / workspace',
        title: 'Archive',
        subtitle: 'A place for the work your team has finished reviewing.',
      ),
      const SizedBox(height: 28),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.inventory_2_outlined, size: 40),
            SizedBox(height: 20),
            Text('History starts here'),
            SizedBox(height: 10),
            Text(
              'This is an archive placeholder. Manual archiving, reasons, preserved comments, and restoration are planned for a later step. Nothing has been archived or saved.',
            ),
          ],
        ),
      ),
    ],
  );
}
