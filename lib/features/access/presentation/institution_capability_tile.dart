import 'package:flutter/material.dart';

import '../data/access_dtos.dart';

const launcherDeniedMessage =
    'No tienes permiso de lanzador para esta institución.';

const administratorIsNotLauncherMessage =
    'Ser administrador no otorga permiso de lanzador.';

/// Institución del usuario con la capacidad de lanzador que reporta imSafeAPI
/// (`capabilities.launcher`). `administrator` no se interpreta como permiso de
/// lanzador.
class InstitutionCapabilityTile extends StatelessWidget {
  const InstitutionCapabilityTile({
    super.key,
    required this.item,
    this.onSelected,
  });

  final MyInstitution item;

  /// Solo se usa si la institución tiene permiso de lanzador.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final launcher = item.isLauncher;
    return Card(
      child: ListTile(
        leading: Icon(
          launcher ? Icons.verified_user_outlined : Icons.block_outlined,
        ),
        title: Text(item.institution.name),
        subtitle: Text(
          launcher
              ? 'Autorizado como lanzador'
              : item.isAdministrator
              ? '$launcherDeniedMessage\n$administratorIsNotLauncherMessage'
              : launcherDeniedMessage,
        ),
        trailing: launcher && onSelected != null
            ? const Icon(Icons.chevron_right)
            : null,
        onTap: launcher ? onSelected : null,
      ),
    );
  }
}
