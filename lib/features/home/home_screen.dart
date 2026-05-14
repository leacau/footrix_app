import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏠 Footrix'),
        actions: [
          // 🌐 Selector de idioma
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            onSelected: (locale) {
              // Aquí podrías implementar cambio de idioma con Riverpod
              // Por ahora, solo mostramos un mensaje
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Idioma: ${locale.languageCode.toUpperCase()}',
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: Locale('es'),
                child: Text('🇪🇸 Español'),
              ),
              const PopupMenuItem(
                value: Locale('en'),
                child: Text('🇬🇧 English'),
              ),
            ],
          ),
          // 👤 Menú de perfil rápido
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            onSelected: (value) {
              if (value == 'profile' && context.mounted) {
                context.push('/profile');
              } else if (value == 'logout') {
                FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('👤 Mi Perfil'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('🚪 Cerrar Sesión'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 Welcome header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👋 ¡Hola, ${user?.displayName ?? 'Usuario'}!',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Elegí una sección para comenzar:',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 🎯 Grid de navegación
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                // ⚽ Fixture
                _NavCard(
                  icon: Icons.sports_soccer,
                  title: 'Fixture',
                  subtitle: 'Predice partidos',
                  color: Colors.blue,
                  onTap: () => context.push('/fixture'),
                ),
                // 🎮 Trivia
                _NavCard(
                  icon: Icons.quiz,
                  title: 'Trivia',
                  subtitle: 'Preguntas rápidas',
                  color: Colors.purple,
                  onTap: () => context.push('/trivia'),
                ),
                // 👥 Grupos
                _NavCard(
                  icon: Icons.group,
                  title: 'Grupos',
                  subtitle: 'Competí con amigos',
                  color: Colors.green,
                  onTap: () => context.push('/groups'),
                ),
                // 🏆 Rankings
                _NavCard(
                  icon: Icons.emoji_events,
                  title: 'Rankings',
                  subtitle: 'Tabla de posiciones',
                  color: Colors.amber,
                  onTap: () => context.push('/rankings'),
                ),
                // 👤 Perfil
                _NavCard(
                  icon: Icons.person,
                  title: 'Perfil',
                  subtitle: 'Mis datos y stats',
                  color: Colors.teal,
                  onTap: () => context.push('/profile'),
                ),
                // ⚙️ Configuración
                _NavCard(
                  icon: Icons.settings,
                  title: 'Ajustes',
                  subtitle: 'Idioma, notificaciones',
                  color: Colors.grey,
                  onTap: () => _showSettingsDialog(context),
                ),
                // 🛠️ Panel Admin (solo para usuarios con permisos)
                _NavCard(
                  icon: Icons.admin_panel_settings,
                  title: 'Admin',
                  subtitle: 'Gestión',
                  color: Colors.red,
                  onTap: () => context.push('/admin'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 📊 Stats rápidos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 Tus Stats',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statChip(
                          '⚽ Puntos',
                          user != null ? "Cargando..." : "0",
                        ),
                        _statChip('🎮 Trivia', '0'),
                        _statChip('🔥 Racha', '0'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom nav para móvil
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          final routes = [
            '/fixture',
            '/trivia',
            '/groups',
            '/rankings',
            '/profile',
          ];
          if (index < routes.length && context.mounted) {
            context.push(routes[index]);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_soccer),
            label: 'Fixture',
          ),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Trivia'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Grupos'),
          NavigationDestination(
            icon: Icon(Icons.emoji_events),
            label: 'Rankings',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚙️ Ajustes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Idioma:'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Aquí implementarías cambio de idioma real
                  },
                  child: const Text('🇪🇸 ES'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Aquí implementarías cambio de idioma real
                  },
                  child: const Text('🇬🇧 EN'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Notificaciones:'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Activar push'),
              value: true,
              onChanged: (value) {
                // Aquí implementarías toggle de notificaciones
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// Widget auxiliar para las tarjetas de navegación
class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _statChip(String label, String value) {
  return Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ],
  );
}
