class RouteNames {
  static const String root = '/';
  static const String home = '/home';
  static const String productDetail = '/product/:id';
  static const String cart = '/cart';
  static const String favorites = '/favorites';
  static const String checkout = '/checkout';
  static const String orderTrackingHome = '/tracking';
  static const String orderTracking = '/order/:id';
  static const String orderSuccess = '/order-success';
  static const String freebies = '/freebies';
  static const String freebieDetail = '/freebie/:id';
  static const String notifications = '/notifications';
  static const String categories = '/categories';
  static const String categoryProducts = '/category/:id';
  static const String carBrands = '/car-brands';
  static const String partsBrowser = '/parts-browser';
  static const String userSearch = '/user-search';
  static const String carModels = '/car-models';
  static const String carYears = '/car-years';
  static const String carTrims = '/car-trims';
  static const String carSectionsV2 = '/car-sections-v2';
  static const String carSubsections = '/car-subsections';
  static const String carSubsectionProducts = '/car-subsection-products';
  static const String partsBrowserProducts = '/parts-browser-products';
  static const String donateItem = '/donate-item';
  static const String requestDonation = '/request-donation';
  static const String influencerPartnership = '/influencer-partnership';

  // RFQ / Reverse Marketplace
  static const String rfqMyRequests = '/rfq';
  static const String rfqCreate = '/rfq/create';
  static const String rfqOffers = '/rfq/offers/:requestNumber';
  static const String rfqChat = '/rfq/chat/:requestNumber/:sellerId';

  static String productDetailPath(String id) => '/product/$id';
  static String orderTrackingHomePath() => orderTrackingHome;
  static String orderTrackingPath(String id) => '/order/$id';
  static String freebieDetailPath(String id) => '/freebie/$id';
  static String categoryProductsPath(String id) => '/category/$id';

  static String rfqOffersPath(String requestNumber) =>
      '/rfq/offers/$requestNumber';
  static String rfqChatPath(String requestNumber, String sellerId) =>
      '/rfq/chat/$requestNumber/$sellerId';
}
