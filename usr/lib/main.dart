import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// --- MODELS ---

// Represents a product in the store.
class Product {
  final String sku;
  final String name;
  final double price;

  Product({required this.sku, required this.name, required this.price});
}

// Represents an item within the shopping cart.
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalPrice => product.price * quantity;
}

// --- MOCK DATA ---

// A list of sample products to populate the POS screen.
final List<Product> mockProducts = [
  Product(sku: 'RICE001', name: 'Basmati Rice 1kg', price: 80.0),
  Product(sku: 'OIL001', name: 'Sunflower Oil 1L', price: 180.0),
  Product(sku: 'TEA001', name: 'Tea Powder 500g', price: 200.0),
  Product(sku: 'SHIRT001', name: 'Formal Shirt (M)', price: 899.0),
  Product(sku: 'JEAN001', name: 'Denim Jeans (32)', price: 1299.0),
  Product(sku: 'BIR001', name: 'Chicken Biryani', price: 220.0),
  Product(sku: 'PIZ001', name: 'Margherita Pizza', price: 299.0),
];

// --- STATE MANAGEMENT (PROVIDER) ---

// Manages the state of the shopping cart.
class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get subtotal =>
      _items.fold(0, (total, current) => total + current.totalPrice);

  double get gstAmount => subtotal * 0.05; // 5% GST for simplicity
  double get total => subtotal + gstAmount;

  void addToCart(Product product) {
    for (var item in _items) {
      if (item.product.sku == product.sku) {
        item.quantity++;
        notifyListeners();
        return;
      }
    }
    _items.add(CartItem(product: product));
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

// --- PDF INVOICE SERVICE ---

// Handles the creation and sharing of PDF invoices.
class PdfInvoiceService {
  // Generates a PDF invoice from the list of sold items.
  Future<Uint8List> createInvoice(List<CartItem> soldItems) async {
    final pdf = pw.Document();
    final subtotal =
        soldItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final gst = subtotal * 0.05;
    final total = subtotal + gst;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TAX INVOICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.SizedBox(height: 20),
              pw.Text('Your Business Name'),
              pw.Text('123 Business St, City'),
              pw.Text('GSTIN: XXXXXXXXXXX'),
              pw.Divider(height: 30),
              pw.Text('Invoice #: INV-${DateTime.now().millisecondsSinceEpoch}'),
              pw.Text('Date: ${DateTime.now().toLocal().toString().substring(0, 16)}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Item', 'Qty', 'Price', 'Total'],
                data: soldItems
                    .map((item) => [
                          item.product.name,
                          item.quantity.toString(),
                          '${item.product.price.toStringAsFixed(2)}',
                          '${item.totalPrice.toStringAsFixed(2)}'
                        ])
                    .toList(),
              ),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ${subtotal.toStringAsFixed(2)}'),
                    pw.Text('GST (5%): ${gst.toStringAsFixed(2)}'),
                    pw.Text('Total: ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ]
                )
              ),
              pw.SizedBox(height: 50),
              pw.Center(child: pw.Text('Thank you for your business!')),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  // Saves the PDF to a temporary file and opens the share dialog.
  Future<void> saveAndSharePdf(Uint8List pdfBytes, String fileName) async {
    if (kIsWeb) {
      // For web, we use the printing package to open a preview/save dialog.
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
    } else {
      // For mobile, we save to a temp file and use share_plus.
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Here is your invoice!');
    }
  }
}

// --- MAIN APPLICATION ---

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CartProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PosScreen(),
    );
  }
}

// --- SCREENS ---

// The main Point of Sale screen displaying products.
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart POS'),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, child) => Badge(
              label: Text(cart.items.length.toString()),
              isLabelVisible: cart.items.isNotEmpty,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3 / 2.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: mockProducts.length,
        itemBuilder: (context, index) {
          final product = mockProducts[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                  Text('₹${product.price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyLarge),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      child: const Text('Add to Cart'),
                      onPressed: () {
                        Provider.of<CartProvider>(context, listen: false).addToCart(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart.'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// The screen displaying the contents of the shopping cart.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        title: Text(item.product.name),
                        subtitle: Text('Qty: ${item.quantity}'),
                        trailing: Text('₹${item.totalPrice.toStringAsFixed(2)}'),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildTotalRow('Subtotal', cart.subtotal),
                      _buildTotalRow('GST (5%)', cart.gstAmount),
                      const Divider(),
                      _buildTotalRow('Grand Total', cart.total, isBold: true),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Complete Sale'),
                          onPressed: () {
                            final soldItems = List<CartItem>.from(cart.items);
                            cart.clearCart();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoiceScreen(soldItems: soldItems),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTotalRow(String title, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 16),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 16),
          ),
        ],
      ),
    );
  }
}

// The screen shown after a sale is completed, providing invoice options.
class InvoiceScreen extends StatelessWidget {
  final List<CartItem> soldItems;
  final PdfInvoiceService _pdfService = PdfInvoiceService();

  InvoiceScreen({super.key, required this.soldItems});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Complete'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              Text(
                'Transaction Successful!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share Invoice'),
                  onPressed: () async {
                    final pdfBytes = await _pdfService.createInvoice(soldItems);
                    await _pdfService.saveAndSharePdf(pdfBytes, 'invoice.pdf');
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  child: const Text('Start New Sale'),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
