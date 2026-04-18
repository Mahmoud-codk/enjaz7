import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:intl/intl.dart';
import '../models/bus_line.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'last_used';
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<BusLine> _selectedLines = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  List<BusLine> _getSortedFavorites(List<BusLine> favorites) {
    final List<BusLine> sorted = List.from(favorites);

    switch (_sortBy) {
      case 'last_used':
        sorted.sort((a, b) {
          final aTime = a.lastUsed ?? DateTime(1970);
          final bTime = b.lastUsed ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
        break;
      case 'usage_count':
        sorted.sort((a, b) => (b.usageCount ?? 0).compareTo(a.usageCount ?? 0));
        break;
      case 'number':
        sorted.sort((a, b) => a.routeNumber.compareTo(b.routeNumber));
        break;
      case 'name':
        sorted.sort((a, b) => a.type.compareTo(b.type));
        break;
    }

    if (_searchQuery.isNotEmpty) {
      return sorted
          .where(
            (line) =>
                line.routeNumber.contains(_searchQuery) ||
                line.type.contains(_searchQuery) ||
                line.stops.any((s) => s.contains(_searchQuery)),
          )
          .toList();
    }

    return sorted;
  }

  void _shareFavorites(List<BusLine> favorites, bool isEn) {
    final lines = favorites
        .map((l) => isEn
            ? '• Line ${l.routeNumber} - ${l.type}'
            : '• خط ${l.routeNumber} - ${l.type}')
        .join('\n');
    share_plus.SharePlus.instance.share(
      share_plus.ShareParams(
        text: isEn
            ? '''
My favorite lines in Cairo Bus Guide:

$lines

I'm using the best transport app in Egypt!
Download now: https://busguide.com
'''
            : '''
خطوطي المفضلة في دليل حافلات القاهرة:

$lines

أنا بستخدم أقوى تطبيق مواصلات في مصر!
حمّله الآن: https://busguide.com
  ''',
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedLines.clear();
      }
    });
  }

  void _toggleLineSelection(BusLine line) {
    setState(() {
      if (_selectedLines.contains(line)) {
        _selectedLines.remove(line);
      } else {
        _selectedLines.add(line);
      }
    });
  }

  void _selectAll() {
    final favorites = context.read<FavoritesProvider>().favorites;
    setState(() {
      _selectedLines.addAll(favorites);
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedLines.clear();
    });
  }

  void _deleteSelected() {
    final favoritesProvider = context.read<FavoritesProvider>();
    final selectedFutures = <Future<void>>[];

    for (final line in _selectedLines) {
      selectedFutures.add(favoritesProvider.removeFavorite(line));
    }

    // انتظر انتهاء جميع عمليات الحذف
    Future.wait(selectedFutures).then((_) {
      setState(() {
        _selectedLines.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'en'
                ? 'Selected lines deleted'
                : 'تم حذف الخطوط المحددة')),
      );
    });
  }

  void _shareSelected() {
    if (_selectedLines.isEmpty) return;
    _shareFavorites(_selectedLines.toList(),
        Localizations.localeOf(context).languageCode == 'en');
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'favorites_logo',
                    child: Image.asset(
                      'assets/images/play_store_512.png',
                      height: 32,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEn ? 'Favorites' : 'المفضلة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 70,
                    left: 20,
                    right: 20,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isEn ? 'Your Daily Routes' : 'خطوطك اليومية',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isEn
                                ? 'The routes you use every day in one place'
                                : 'الخطوط اللي بتستخدمها كل يوم في مكان واحد',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: _selectedLines.length ==
                          context.read<FavoritesProvider>().favorites.length
                      ? _deselectAll
                      : _selectAll,
                  tooltip: _selectedLines.length ==
                          context.read<FavoritesProvider>().favorites.length
                      ? 'إلغاء تحديد الكل'
                      : 'تحديد الكل',
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _selectedLines.isNotEmpty ? _shareSelected : null,
                  tooltip: 'مشاركة المحدد',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedLines.isNotEmpty ? _deleteSelected : null,
                  tooltip: 'حذف المحدد',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'إلغاء التحديد',
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () => _toggleSelectionMode(),
                  tooltip: 'تحديد متعدد',
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    final favorites =
                        context.read<FavoritesProvider>().favorites;
                    if (favorites.isNotEmpty) _shareFavorites(favorites, isEn);
                  },
                  tooltip: 'مشاركة المفضلة',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () => _showClearDialog(context),
                  tooltip: 'حذف الكل',
                ),
              ],
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // عداد المفضلات والحد الأقصى
                  Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      final count = favoritesProvider.count;
                      final maxCount = FavoritesProvider.maxFavorites;
                      final remaining = maxCount - count;
                      final isNearMax = remaining <= 2;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isNearMax ? Colors.orange[100] : Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isNearMax ? Colors.orange : Colors.blue,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.favorite,
                                  color:
                                      isNearMax ? Colors.orange : Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isEn
                                      ? 'Favorites: $count / $maxCount'
                                      : 'المفضلات: $count / $maxCount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isNearMax
                                        ? Colors.orange[900]
                                        : Colors.blue[900],
                                  ),
                                ),
                              ],
                            ),
                            if (isNearMax)
                              Text(
                                isEn
                                    ? '$remaining left'
                                    : 'متبقي: $remaining فقط',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText:
                          isEn ? 'Search favorites...' : 'ابحث في المفضلة...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sort Options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEn ? 'Sort by' : 'ترتيب حسب',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox(),
                        items: [
                          _sortItem(
                            'last_used',
                            Icons.access_time,
                            isEn ? 'Last used' : 'آخر استخدام',
                          ),
                          _sortItem(
                            'usage_count',
                            Icons.bar_chart,
                            isEn ? 'Most used' : 'الأكثر استخدامًا',
                          ),
                          _sortItem(
                            'number',
                            Icons.format_list_numbered,
                            isEn ? 'Line number' : 'رقم الخط',
                          ),
                          _sortItem('name', Icons.sort_by_alpha,
                              isEn ? 'Type' : 'النوع'),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _sortBy = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              final favorites = _getSortedFavorites(
                favoritesProvider.favorites,
              );

              if (favorites.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            'assets/animations/empty_favorites.json',
                            width: 250,
                            height: 250,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isEn
                                ? 'No favorite lines yet'
                                : 'لا توجد خطوط مفضلة بعد',
                            style: TextStyle(
                              // تم إزالة const لدعم Colors.grey[600]
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isEn
                                ? 'Tap the heart on any line to add it here'
                                : 'اضغط على القلب في أي خط لإضافته هنا',
                            style: TextStyle(color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.search),
                            label: Text(isEn
                                ? 'Search for your favorite lines'
                                : 'ابحث عن خطوطك المفضلة'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final line = favorites[index];
                  final lastUsed = line.lastUsed != null
                      ? DateFormat(isEn ? 'd MMM, h:mm a' : 'd MMM، h:mm a')
                          .format(line.lastUsed!)
                      : (isEn ? 'Not used yet' : 'لم يُستخدم بعد');
                  final usage = line.usageCount ?? 0;

                  return Dismissible(
                    key: Key(line.routeNumber),
                    direction: _isSelectionMode
                        ? DismissDirection.none
                        : DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: _isSelectionMode
                        ? null
                        : (direction) {
                            favoritesProvider.removeFavorite(line).then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEn
                                        ? 'Line ${line.routeNumber} removed from favorites'
                                        : 'تم حذف خط ${line.routeNumber} من المفضلة',
                                  ),
                                  action: SnackBarAction(
                                    label: isEn ? 'Undo' : 'تراجع',
                                    onPressed: () =>
                                        favoritesProvider.addFavorite(line),
                                  ),
                                ),
                              );
                            });
                          },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: _selectedLines.contains(line),
                                onChanged: (bool? value) {
                                  _toggleLineSelection(line);
                                },
                              )
                            : CircleAvatar(
                                backgroundColor: theme.colorScheme.primary,
                                child: Text(
                                  line.routeNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        title: Text(
                          isEn
                              ? 'Line ${line.routeNumber}'
                              : 'خط ${line.routeNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.getLocalizedType(locale)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isEn
                                      ? 'Last used: $lastUsed'
                                      : 'آخر استخدام: $lastUsed',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.bar_chart,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isEn
                                      ? 'Used $usage times'
                                      : 'استخدمت $usage مرة',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: _isSelectionMode
                            ? null
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _isSelectionMode
                            ? () => _toggleLineSelection(line)
                            : () {
                                favoritesProvider.updateFavorite(line);
                                Navigator.pushNamed(
                                  context,
                                  '/line_details',
                                  arguments: line,
                                );
                              },
                        onLongPress: _isSelectionMode
                            ? null
                            : () => _toggleSelectionMode(),
                      ),
                    ),
                  );
                }, childCount: favorites.length),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              tooltip: isEn ? 'Search for new lines' : 'البحث عن خطوط جديدة',
              child: const Icon(Icons.search),
            ),
    );
  }

  DropdownMenuItem<String> _sortItem(String value, IconData icon, String text) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(text)],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          // تم إزالة const لدعم النصوص الديناميكية
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 12),
            Text(Localizations.localeOf(context).languageCode == 'en'
                ? 'Delete all favorites'
                : 'حذف جميع المفضلات'),
          ],
        ),
        content: Text(
          // تم إزالة const لدعم التحقق من اللغة
          Localizations.localeOf(context).languageCode == 'en'
              ? 'Are you sure? All lines will be permanently removed from favorites.'
              : 'هل أنت متأكد؟ سيتم حذف كل الخطوط من المفضلة نهائيًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Localizations.localeOf(context).languageCode == 'en'
                ? 'Cancel'
                : 'إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FavoritesProvider>().clearAllFavorites().then((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          Localizations.localeOf(context).languageCode == 'en'
                              ? 'All favorites cleared'
                              : 'تم حذف جميع المفضلات')),
                );
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(Localizations.localeOf(context).languageCode == 'en'
                ? 'Delete All'
                : 'حذف الكل'),
          ),
        ],
      ),
    );
  }
}
