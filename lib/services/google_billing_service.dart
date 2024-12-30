import 'package:in_app_purchase/in_app_purchase.dart';

class GoogleBillingService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  Future<void> initBilling() async {
    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      print('In-App Purchases are not available.');
      return;
    }
    print('In-App Purchases are available.');
  }

  Future<void> buyProduct(String productId) async {
    // Fetch product details from the store
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({productId});
    if (response.notFoundIDs.isNotEmpty) {
      print('Product not found: $productId');
      return;
    }

    final productDetails = response.productDetails.first;
    final purchaseParam = PurchaseParam(productDetails: productDetails);
    _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }
}
