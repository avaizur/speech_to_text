import 'package:in_app_purchase/in_app_purchase.dart';

class InAppPurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  Future<void> init() async {
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      throw Exception("In-App Purchases not available");
    }
  }

  Future<void> makePurchase(String productId) async {
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails({productId});
    if (response.notFoundIDs.isNotEmpty) {
      throw Exception("Product not found: $productId");
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);

    await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }
}
