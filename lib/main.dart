import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

//import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:launch_review/launch_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'about_us.dart';
import 'all_radio_station.dart';
import 'bottom_panel.dart';
import 'category.dart';
import 'city.dart';
import 'favorite.dart';
import 'Helper/constant.dart';
import 'Helper/favourite_helper.dart';
import 'Helper/model.dart';
import 'Helper/push_notification_service.dart';
import 'home.dart';
import 'now_playing.dart';
import 'privacy_policy.dart';
import 'splash.dart';
import 'terms.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(myForgroundMessageHandler);
  //await MobileAds.instance.initialize();

  runApp(MyApp());
}

///root of your application, starting point of execution
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rádio Rodovia',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: Directionality(
        textDirection: direction, // set this property
        child: Splash(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

///all radio station is loading
bool loading = true;

///offset for load more
int offset = 0;

///total radio station
int total = 0;

///no of item to load in one time
int perPage = 10;

///temp radio list for load more
List<Model> tempSongList = [];

///is error exist
bool errorExist = false;

///search list
List<Model> searchList = [];

///favorite database
var db = Favourite_Helper();

///bottom panel
PanelController? panelController;

///after search result list
List<Model> searchresult = [];

///currently is searching
bool? isSearching;

///home tab controller
TabController? tabController;

///main contianer of app
class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  GlobalKey<ScaffoldState> _globalKey = GlobalKey();
  final TextEditingController _controller = TextEditingController();
  DateTime? _currentBackPressTime;
  bool call = false;
  bool play = false;
  Icon iconSearch = Icon(
    Icons.search,
    color: Colors.white,
  );

  Widget appBarTitle = Text(
    appname,
    style: TextStyle(color: Colors.white),
  );

  _MyHomePageState() {
    _controller.addListener(() {
      if (_controller.text.isEmpty) {
        if (!mounted) return;
        setState(() {
          isSearching = false;
        });
      } else {
        isSearching = true;
      }
    });
  }

  @override
  void initState() {
    final pushNotificationService = PushNotificationService(context: context);
    pushNotificationService.initialise();
    subscriptions.add(assetsAudioPlayer.playlistAudioFinished.listen((data) {
      print('playlistAudioFinished : $data');
    }));
    subscriptions.add(assetsAudioPlayer.audioSessionId.listen((sessionId) {
      print('audioSessionId : $sessionId');
    }));
    subscriptions
        .add(AssetsAudioPlayer.addNotificationOpenAction((notification) {
      return false;
    }));
    isSearching = false;
    panelController = PanelController();
    tabController = TabController(length: 3, vsync: this);
    offset = 0;
    total = 0;
    tempSongList.clear();
    radioList.clear();
    getRadioStation();
    playerInit();
    super.initState();
  }

  playerInit() async {
    await assetsAudioPlayer.open(
      Playlist(audios: audios, startIndex: 0),
      showNotification: true,
      autoStart: false,
    );
  }

  @override
  void dispose() {
    if (!panelController!.isPanelClosed) {
      panelController!.close();
    }
    assetsAudioPlayer.dispose();
    // Dispose of the Tab Controller
    tabController!.dispose();
    super.dispose();
  }

  Future onDidReceiveLocalNotification(
      int id, String title, String body, String payload) {
    return showDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('Ok'),
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyApp(),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Future onSelectNotification(String payload) async {
    if (payload != null) {}
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    BorderRadiusGeometry radius = BorderRadius.only(
      topLeft: Radius.circular(25.0),
      topRight: Radius.circular(25.0),
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: direction,
        child: Scaffold(
          key: _globalKey,
          appBar: getAppbar(),
          drawer: getDrawer(),
          body: NowPlaying(
            refresh: _refresh,
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!panelController!.isPanelClosed) {
      panelController!.close();
      return Future<bool>.value(false);
    } else if (_globalKey.currentState!.isDrawerOpen) {
      Navigator.pop(context); // closes the drawer if opened
      return Future.value(false); // won't exit the app
    } else {
      var now = DateTime.now();
      if (_currentBackPressTime == null ||
          now.difference(_currentBackPressTime!) > Duration(seconds: 2)) {
        _currentBackPressTime = now;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Double tap to exit app',
            textAlign: TextAlign.center,
          ),
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
          elevation: 1.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50.0),
          ),
        ));
        return Future.value(false);
      }
      dispose();
      return Future.value(true);
    }
  }

  TabBarView getTabBarView(List<Widget> tabs) {
    return TabBarView(
      // Add tabs as widgets
      children: tabs,
      // set the controller
      controller: tabController,
      //  dragStartBehavior: DragStartBehavior.down,
    );
  }

  TabBar getTabBar() {
    return TabBar(
      indicatorColor: Colors.white,
      tabs: <Tab>[
        Tab(
          text: 'Home',
        ),
        Tab(
          text: cityMode ? 'City' : 'Category',
        ),
        Tab(
          text: 'All Radio',
        ),
      ],
      // setup the controller
      controller: tabController,
    );
  }

  void getRadioStation() async {
    var data = {
      'access_key': '6808',
      'limit': perPage.toString(),
      'offset': offset.toString()
    };
    var response = await http.post(radio_station, body: data);

    var getdata = json.decode(response.body);
    print(getdata);
    total = int.parse(getdata['total'].toString());
    var error = getdata['error'].toString();
    setState(() {
      if (error == 'true' || (total) == 0) {
        loading = false;
        errorExist = true;
      } else {
        var gData = getdata['data'];
        loading = false;
        if ((offset) < total) {
          tempSongList.clear();

          tempSongList = (gData as List)
              .map((data) => Model.fromJson(data as Map<String, dynamic>))
              .toList();

          radioList.addAll(tempSongList);

          curPlayList = radioList;
          updateQueue(choiceIndex: 0, start: false, ind: 0, context: context);
          offset = offset + perPage;
        }
      }
    });
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> searchOperation(String searchText) async {
    if (isSearching != null) {
      var data = {'access_key': '6808', 'keyword': searchText};

      var response = await http.post(search_api, body: data);
      var getdata = json.decode(response.body);

      var error = getdata['error'].toString();

      if (error == 'false') {
        searchresult.clear();
        searchList.clear();

        var data = (getdata['data']);

        searchList = (data as List)
            .map((data) => Model.fromJson(data as Map<String, dynamic>))
            .toList();
      }

      for (var i = 0; i < searchList.length; i++) {
        Model data = searchList[i];

        if (data.name!.toLowerCase().contains(searchText.toLowerCase())) {
          searchresult.add(data);
        }
      }
      if (!mounted) return;
      setState(() {});
    }
  }

  void _handleSearchStart() {
    if (!mounted) return;
    setState(() {
      isSearching = true;
      tabController!.animateTo(2);
    });
  }

  void _handleSearchEnd() {
    if (!mounted) return;
    setState(() {
      iconSearch = Icon(
        Icons.search,
        color: Colors.white,
      );
      appBarTitle = Text(
        appname,
        style: TextStyle(color: Colors.white),
      );
      isSearching = false;
      _controller.clear();
    });
  }

  AppBar getAppbar() {
    return AppBar(
      title: appBarTitle,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: primary,
        ),
      ),
      centerTitle: true,
      //bottom: getTabBar(),
      actions: <Widget>[
        IconButton(
          icon: iconSearch,
          onPressed: () {
            //print("call search");
            if (!mounted) return;
            setState(() {
              if (iconSearch.icon == Icons.search) {
                iconSearch = Icon(
                  Icons.close,
                  color: Colors.white,
                );
                appBarTitle = TextField(
                  controller: _controller,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.white),
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: Colors.white),
                  ),
                  onChanged: searchOperation,
                );
                _handleSearchStart();
              } else {
                _handleSearchEnd();
              }
            });
          },
        )
      ],
    );
  }

  Drawer getDrawer() {
    return Drawer(
      child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [
                  Color(0xffF8A11B),
                  Colors.black.withOpacity(1),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                // Add one stop for each color. Stops should increase from 0 to 1
                //stops: [0.2, 0.4, 0.9],
                tileMode: TileMode.clamp),
          ),
          child: ListView(
            physics: BouncingScrollPhysics(),
            children: <Widget>[
              Container(
                width: 150,
                height: 150,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/image/logo_amarelo.png',
                  fit: BoxFit.fill,
                  width: 220,
                  height: 90,
                ),
              ),
              ListTile(
                  leading: Icon(Icons.home, color: Colors.white),
                  title: Text(
                    'Home',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    tabController!.animateTo(0);
                  }),
              // ListTile(
              //     leading: Icon(Icons.category, color: Colors.white),
              //     title: Text(
              //       cityMode ? 'City' : 'Category',
              //       style: TextStyle(color: Colors.white),
              //     ),
              //     onTap: () {
              //       Navigator.pop(context);
              //       tabController!.animateTo(1);
              //     }),
              // ListTile(
              //     leading: Icon(Icons.radio, color: Colors.white),
              //     title: Text(
              //       'All Radio',
              //       style: TextStyle(color: Colors.white),
              //     ),
              //     onTap: () {
              //       Navigator.pop(context);
              //       tabController!.animateTo(2);
              //     }),
              // ListTile(
              //     leading: Icon(Icons.favorite, color: Colors.white),
              //     title: Text(
              //       'Favorito',
              //       style: TextStyle(color: Colors.white),
              //     ),
              //     onTap: () {
              //       Navigator.pop(context);
              //       Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //             builder: (context) => Directionality(
              //               textDirection: direction,
              //               child: Favorite(),
              //             ),
              //           ));
              //     }),
              Divider(),
              ListTile(
                  leading: Icon(Icons.share, color: Colors.white),
                  title: Text(
                    'Compartilhar App',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (Platform.isAndroid) {
                      Share.share('Eu estou escutando a -\n'
                          '$appname\n'
                          'https://play.google.com/store/apps/details?id=$androidPackage&hl=en');
                    } else {
                      Share.share('Eu estou escutando a -\n'
                          '$appname\n'
                          '$iosPackage');
                    }
                  }),
              ListTile(
                  leading: Icon(Icons.security, color: Colors.white),
                  title: Text(
                    'Politica de Privacidade',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Directionality(
                              textDirection: direction,
                              // set this property
                              child: PrivacyPolicy()),
                        ));
                  }),
              ListTile(
                  leading: Icon(Icons.warning, color: Colors.white),
                  title: Text(
                    'Termos',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Directionality(
                              textDirection: direction,
                              // set this property
                              child: Terms()),
                        ));
                  }),
              ListTile(
                  leading: Icon(Icons.info, color: Colors.white),
                  title: Text(
                    'Sobre',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Directionality(
                              textDirection: direction,
                              // set this property
                              child: AboutUS()),
                        ));
                  }),
              ListTile(
                  leading: Icon(Icons.star, color: Colors.white),
                  title: Text(
                    'Avalie o App',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    LaunchReview.launch(
                      androidAppId: "com.app.radiorodovia",
                      //your android package name
                      iOSAppId: "", //your ios app id
                    );
                  }),
            ],
          )),
    );
  }
}
