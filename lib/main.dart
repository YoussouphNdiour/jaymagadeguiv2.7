import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:meta_seo/meta_seo.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/features/favourite/controllers/favourite_controller.dart';
import 'package:sixam_mart/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/notification_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/theme/dark_theme.dart';
import 'package:sixam_mart/theme/light_theme.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/messages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/widgets/cookies_view.dart';
import 'package:url_strategy/url_strategy.dart';
import 'helper/get_di.dart' as di;
import 'package:sixam_mart/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart/util/app_constants.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


Future<void> main() async {
  if(ResponsiveHelper.isMobilePhone()) {
    HttpOverrides.global = MyHttpOverrides();
  }
  setPathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  if(GetPlatform.isWeb){
    await Firebase.initializeApp(options: const FirebaseOptions(
  apiKey: "AIzaSyCTUYKgsWUNGarex_wxUVN812RF9He7oPM",
  authDomain: "jayma-88682.firebaseapp.com",
  databaseURL: "https://jayma-88682-default-rtdb.europe-west1.firebasedatabase.app",
  projectId: "jayma-88682",
  storageBucket: "jayma-88682.appspot.com",
  messagingSenderId: "484779040551",
  appId: "1:484779040551:web:fcc1614cfd2dfd52341302",
  measurementId: "G-FNV6D046C0"
    ));
    MetaSEO().config();
  } else if(GetPlatform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
  apiKey: "AIzaSyCTUYKgsWUNGarex_wxUVN812RF9He7oPM",
  authDomain: "jayma-88682.firebaseapp.com",
  databaseURL: "https://jayma-88682-default-rtdb.europe-west1.firebasedatabase.app",
  projectId: "jayma-88682",
  storageBucket: "jayma-88682.appspot.com",
  messagingSenderId: "484779040551",
  appId: "1:484779040551:web:fcc1614cfd2dfd52341302",
  measurementId: "G-FNV6D046C0"
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  Map<String, Map<String, String>> languages = await di.init();

  NotificationBodyModel? body;
  try {
    if (GetPlatform.isMobile) {
      final RemoteMessage? remoteMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (remoteMessage != null) {
        body = NotificationHelper.convertNotification(remoteMessage.data);
      }
      await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
      FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
    }
  } catch(_) {}

  if (ResponsiveHelper.isWeb()) {
    await FacebookAuth.instance.webAndDesktopInitialize(
      appId: "380903914182154",
      cookie: true,
      xfbml: true,
      version: "v15.0",
    );
  }
  runApp(MyApp(languages: languages, body: body));
}

class MyApp extends StatefulWidget {
  
  final Map<String, Map<String, String>>? languages;
  final NotificationBodyModel? body;
  const MyApp({super.key, required this.languages, required this.body});

  @override
  State<MyApp> createState() => _MyAppState();
}
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();

    _route();
    initDynamicLink();
  }

  void _route() async {
    if(GetPlatform.isWeb) {
      Get.find<SplashController>().initSharedData();
      if(AddressHelper.getUserAddressFromSharedPref() != null && AddressHelper.getUserAddressFromSharedPref()!.zoneIds == null) {
        Get.find<AuthController>().clearSharedAddress();
      }

      if(!AuthHelper.isLoggedIn() && !AuthHelper.isGuestLoggedIn()) {
        await Get.find<AuthController>().guestLogin();
      }

      if((AuthHelper.isLoggedIn() || AuthHelper.isGuestLoggedIn()) && Get.find<SplashController>().cacheModule != null) {
        Get.find<CartController>().getCartDataOnline();
      }
    }

    Get.find<SplashController>().getConfigData(loadLandingData: GetPlatform.isWeb).then((bool isSuccess) async {
      if (isSuccess) {
        if (Get.find<AuthController>().isLoggedIn()) {
          Get.find<AuthController>().updateToken();
          if(Get.find<SplashController>().module != null) {
            await Get.find<FavouriteController>().getFavouriteList();
          }
        }
      }
    });
  }
void initDynamicLink() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();

 final ApiClient apiClient = ApiClient(appBaseUrl: AppConstants.baseUrl, sharedPreferences: sharedPreferences) ;
  FirebaseDynamicLinks.instance.onLink.listen((PendingDynamicLinkData? dynamicLink) async {
    final Uri? deepLink = dynamicLink?.link;
    if (deepLink != null) {
      if (deepLink.path == '/payment') {
        if(AuthHelper.isLoggedIn()){
          print("conneccte");
          Response response = await apiClient.getData('${AppConstants.historyOrderListUri}?offset=1&limit=1');
          var profilnumber =  Get.find<ProfileController>().userInfoModel?.phone;
          var firstOrder = response.body["orders"][0];
          print(firstOrder);
            if (firstOrder is Map<String, dynamic> && profilnumber != null ) {
              // Imprimer la première commande
              // Extraire et imprimer l'ID de la commande
              var orderId = firstOrder['id'] ;
              var phone = firstOrder["phone"];
                    Get.toNamed(RouteHelper.getOrderSuccessRoute(orderId.toString(),phone));
            } 
        }
        else{
          print("invite");
          Map<String, String>? header ={
            'Content-Type': 'application/json; charset=UTF-8',
            AppConstants.localizationKey: AppConstants.languages[0].languageCode!,
            AppConstants.moduleId: '${Get.find<SplashController>().getCacheModule()}',
            'Authorization': 'Bearer ${sharedPreferences.getString(AppConstants.token)}'
          };
          var guestId =  Get.find<AuthController>().getGuestId();
         // String guestId = Get.parameters['guest-id']!;
          print('guestid $guestId');
          Map<String, String> data = {};
          if(guestId.isNotEmpty) {
            data.addAll({"guest_id": guestId});
          }      
          Response response = await apiClient.getData('${AppConstants.historyOrderListUri}?offset=1&limit=1&guest_id=$guestId',headers: header);
          var profilnumber =  Get.find<ProfileController>().userInfoModel?.phone;
          var firstOrder = response.body["orders"][0];
          var guestid =  Get.find<AuthController>().getGuestNumber();
          if (firstOrder is Map<String, dynamic> && profilnumber != null ) {
            // Imprimer la première commande
            // Extraire et imprimer l'ID de la commande
            var orderId = firstOrder['id'] ;
            var phone = firstOrder["phone"];
              Get.toNamed(RouteHelper.getGuestTrackOrderScreen(orderId,phone));
            print('La première commande n\'est pas un Map<String, dynamic>');
          }
        }
      }
      
  
  }}).onError((error) async {
    print("Error receiving dynamic link: $error");
  });


  // final PendingDynamicLinkData? data = await FirebaseDynamicLinks.instance.getInitialLink();
  // final Uri? deepLink = data?.link;
  // print("Initial dynamic link: $deepLink");
  // if (deepLink != null) {
  //   print("Initial dynamic link: $deepLink");
  //   if (deepLink.path == '/payment') {
  //    Get.toNamed(RouteHelper.getProfileRoute());
  //   }
  // }
}
Future<String> createDynamicLink(String idShop, String numTable) async {
  const String urlPrefix = "https://jaymagadegui.page.link";

  final DynamicLinkParameters parameters = DynamicLinkParameters(
    uriPrefix: urlPrefix,
    link: Uri.parse('https://jaymagadegui.page.link/payment?boutique=$idShop'),
    androidParameters: const AndroidParameters(
      packageName: "sn.jayma.customer",
      minimumVersion: 0,
    ),
    iosParameters: const IOSParameters(
      bundleId: "com.techsupply.jayma",
      minimumVersion: "0",
    ),
  );

  final ShortDynamicLink shortLink = await FirebaseDynamicLinks.instance.buildShortLink(parameters);
  return shortLink.shortUrl.toString();
}

 

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(builder: (themeController) {
      return GetBuilder<LocalizationController>(builder: (localizeController) {
        return GetBuilder<SplashController>(builder: (splashController) {
          return (GetPlatform.isWeb && splashController.configModel == null) ? const SizedBox() : GetMaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            navigatorKey: Get.key,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
            ),
            theme: themeController.darkTheme ? dark() : light(),
            locale: localizeController.locale,
            translations: Messages(languages: widget.languages),
            fallbackLocale: Locale(AppConstants.languages[0].languageCode!, AppConstants.languages[0].countryCode),
            initialRoute: GetPlatform.isWeb ? RouteHelper.getInitialRoute() : RouteHelper.getSplashRoute(widget.body),
            getPages: RouteHelper.routes,
            defaultTransition: Transition.topLevel,
            transitionDuration: const Duration(milliseconds: 500),
            builder: (BuildContext context, widget) {
              return MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)), child: Material(
                child: Stack(children: [
                  widget!,
                  GetBuilder<SplashController>(builder: (splashController){
                    if(!splashController.savedCookiesData && !splashController.getAcceptCookiesStatus(splashController.configModel != null ? splashController.configModel!.cookiesText! : '')){
                      return ResponsiveHelper.isWeb() ? const Align(alignment: Alignment.bottomCenter, child: CookiesView()) : const SizedBox();
                    } else {
                      return const SizedBox();
                    }
                  })
                ]),
              ));
            },
          );
        });
      });
    });
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
