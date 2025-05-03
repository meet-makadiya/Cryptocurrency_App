import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

typedef CryptoData = Map<String, dynamic>;

void main() {
  runApp(CryptoApp());
}

class CryptoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crypto Tracker',
      theme: ThemeData.dark(),
      home: CryptoHomePage(),
    );
  }
}

class CryptoHomePage extends StatefulWidget {
  @override
  _CryptoHomePageState createState() => _CryptoHomePageState();
}

class _CryptoHomePageState extends State<CryptoHomePage>
    with SingleTickerProviderStateMixin {
  List<CryptoData> _cryptoPrices = [];
  List<Map<String, dynamic>> _transactionHistory = [];
  List<CryptoData> _favorites = [];
  CryptoData? _selectedCrypto;
  List<List<dynamic>> _priceHistory = [];
  double? _lastBuyPrice;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    fetchCryptoData();
  }

  Future<void> fetchCryptoData() async {
    final url = Uri.parse(
      'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        _cryptoPrices = List<CryptoData>.from(json.decode(response.body));
      });
    }
  }

  Future<void> fetchCryptoHistory(String id) async {
    final url = Uri.parse(
      'https://api.coingecko.com/api/v3/coins/$id/market_chart?vs_currency=usd&days=7',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _priceHistory = List<List<dynamic>>.from(data['prices']);
      });
    }
  }

  void selectCrypto(CryptoData crypto) {
    setState(() {
      _selectedCrypto = crypto;
    });
    fetchCryptoHistory(crypto['id']);
    _tabController.animateTo(1);
  }

  void buyCrypto(CryptoData crypto) {
    setState(() {
      _lastBuyPrice = crypto['current_price'];
      _transactionHistory.add({
        'type': 'Buy',
        'crypto': crypto['name'],
        'price': crypto['current_price'],
      });
    });
  }

  void sellCrypto(CryptoData crypto) {
    if (_lastBuyPrice != null) {
      double profitLoss = crypto['current_price'] - _lastBuyPrice!;
      setState(() {
        _transactionHistory.add({
          'type': 'Sell',
          'crypto': crypto['name'],
          'price': crypto['current_price'],
          'profitLoss': profitLoss,
        });
      });
    }
  }

  void toggleFavorite(CryptoData crypto) {
    setState(() {
      bool isFavorite = _favorites.any((c) => c['id'] == crypto['id']);
      if (isFavorite) {
        _favorites.removeWhere((c) => c['id'] == crypto['id']);
      } else {
        _favorites.add(crypto);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crypto Tracker'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.show_chart), text: 'Market'),
            Tab(icon: Icon(Icons.trending_up), text: 'Chart'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.favorite), text: 'Favorites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarketTab(),
          _buildChartTab(),
          _buildHistoryTab(),
          _buildFavoritesTab(),
        ],
      ),
    );
  }

  Widget _buildMarketTab() {
    return ListView.builder(
      itemCount: _cryptoPrices.length,
      itemBuilder: (context, index) {
        final crypto = _cryptoPrices[index];
        return ListTile(
          leading: Image.network(crypto['image'], width: 40),
          title: Text(crypto['name']),
          subtitle: Text('\$${crypto['current_price']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _favorites.any((c) => c['id'] == crypto['id'])
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color:
                      _favorites.any((c) => c['id'] == crypto['id'])
                          ? Colors.red
                          : Colors.white,
                ),
                onPressed: () => toggleFavorite(crypto),
              ),
              IconButton(
                icon: Icon(Icons.shopping_cart, color: Colors.green),
                onPressed: () => buyCrypto(crypto),
              ),
              IconButton(
                icon: Icon(Icons.sell, color: Colors.red),
                onPressed: () => sellCrypto(crypto),
              ),
            ],
          ),
          onTap: () => selectCrypto(crypto),
        );
      },
    );
  }

  Widget _buildChartTab() {
    return _priceHistory.isEmpty
        ? Center(child: Text('No Data'))
        : Padding(
          padding: const EdgeInsets.all(8.0),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots:
                      _priceHistory.map((e) {
                        final timestamp =
                            e[0] / 1000000; // Normalizing timestamp
                        final price = e[1].toDouble();
                        return FlSpot(timestamp, price);
                      }).toList(),
                  isCurved: true,
                  gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
                  barWidth: 2,
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildFavoritesTab() {
    return _favorites.isEmpty
        ? Center(child: Text('No Favorites'))
        : ListView.builder(
          itemCount: _favorites.length,
          itemBuilder: (context, index) {
            final crypto = _favorites[index];
            return ListTile(
              leading: Image.network(crypto['image'], width: 40),
              title: Text(crypto['name']),
              subtitle: Text('\$${crypto['current_price']}'),
              onTap: () => selectCrypto(crypto),
            );
          },
        );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      itemCount: _transactionHistory.length,
      itemBuilder: (context, index) {
        final transaction = _transactionHistory[index];
        return ListTile(
          title: Text('${transaction['type']} ${transaction['crypto']}'),
          subtitle: Text('Price: \$${transaction['price']}'),
          trailing:
              transaction.containsKey('profitLoss')
                  ? Text(
                    '\$${transaction['profitLoss'].toStringAsFixed(2)}',
                    style: TextStyle(
                      color:
                          transaction['profitLoss'] >= 0
                              ? Colors.green
                              : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  : null,
        );
      },
    );
  }
}
