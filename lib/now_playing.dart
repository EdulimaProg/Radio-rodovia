import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:radio_rodovia/Helper/model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

//import 'all_radio_station.dart';
import 'Helper/constant.dart';
import 'main.dart';

final _text = TextEditingController();
bool _validate = false;

///category list
List<Model> catList = [];

///current slider position
int _curSlider = 0;

///slider list
List<Model> slider_list = [];

///slider image list
List slider_image = [];

/// Social Media List
List<Social> social_media_list = [];

/// Social Media List
List social_media = [];

///favorite list size
int favSize = 0;

///is category loading
bool catloading = true;

///is error exist or not
bool errorExist = false;

///now playing inside class
class NowPlaying extends StatefulWidget {
  final VoidCallback? _refresh;

  ///constructor
  NowPlaying({VoidCallback? refresh}) : _refresh = refresh;

  @override
  State<StatefulWidget> createState() {
    return _PlayerWidgetState();
  }
}

class _PlayerWidgetState extends State<NowPlaying> {
  @override
  void initState() {
    //getRadioStation();
    getSliderApi();
    getSocialMediaApi();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var shortestSide = MediaQuery.of(context).size.shortestSide;
    useMobileLayout = shortestSide < 600;
    Future.delayed(Duration(seconds: 5));
    return Scaffold(
      body: curPlayList!.isEmpty ? Container() : getContent(),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(top: 40, bottom: 0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            getMediaButton(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  getBackground() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomCenter,
        stops: [0.4, 0.6, 0.8],
        colors: [
          Colors.white70,
          primary.withOpacity(0.5),
          secondary,
        ],
      ),
    );
  }

  Audio find(List<Audio> source, String fromPath) {
    return source.firstWhere((element) => element.path == fromPath);
  }

  getContent() {
    return assetsAudioPlayer.builderCurrent(
      builder: (BuildContext context, Playing playing) {
        final myAudio = find(audios, playing.audio.assetAudioPath);
        return Container(
          decoration: getBackground(),
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: Column(
            children: <Widget>[
              Stack(
                children: [
                  FutureBuilder(
                    builder: (context, snapshot) {
                      /*if (snapshot.connectionState != ConnectionState.active) {
                return SizedBox();
                }*/
                      final running = snapshot.hasData;
                      return slider_list.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(10),
                              child: Center(child: CircularProgressIndicator()),
                              height: MediaQuery.of(context).size.height,
                            )
                          : Stack(children: [
                              CarouselSlider(
                                  items: getSlider(running) as List<Widget>,
                                  options: CarouselOptions(
                                    autoPlay: true,
                                    //enlargeCenterPage: true,
                                    reverse: false,
                                    height:
                                        MediaQuery.of(context).size.height - 87,
                                    viewportFraction: 1.1,
                                    //autoPlayCurve : Curves.fastOutSlowIn,
                                    enlargeStrategy:
                                        CenterPageEnlargeStrategy.scale,
                                    autoPlayAnimationDuration:
                                        Duration(milliseconds: 1000),
                                    aspectRatio: useMobileLayout ? 2.0 : 3.0,

                                    onPageChanged: (index, reason) {
                                      setState(() {
                                        if (index < slider_list.length) {
                                          _curSlider = index;
                                        }
                                      });
                                    },
                                  )),
                            ]);
                    },
                  ),
                  // Text(
                  //   myAudio.metas.title!,
                  //   style: Theme.of(context).textTheme.headline6,
                  //   textAlign: TextAlign.center,
                  // ),
                  // Padding(
                  //   padding: const EdgeInsets.all(8.0),
                  //   child: Text(
                  //     myAudio.metas.artist!,
                  //     style: Theme.of(context)
                  //         .textTheme
                  //         .subtitle1!
                  //         .copyWith(color: Colors.black45),
                  //     textAlign: TextAlign.center,
                  //   ),
                  // ),
                ],
              ),
              //getMiddleButton(),
            ],
          ),
        );
      },
    );
  }

  Future<void> getSliderApi() async {
    var data = {'access_key': '6808'};
    var response = await http.post(slider_api, body: data);
    var getdata = json.decode(response.body);
    print(getdata);
    if (!mounted) return null;
    setState(() {
      var error = getdata['error'].toString();

      if (error == 'false') {
        var data1 = (getdata['data']);

        slider_list = (data1 as List)
            .map((data) => Model.fromJson(data as Map<String, dynamic>))
            .toList();
        for (var f in slider_list) {
          slider_image.add(f.image);
        }
      }
    });
  }

  Future<void> getSocialMediaApi() async {
    var data = {'access_key': '6808'};
    var response = await http.post(social_links, body: data);
    var getdata = json.decode(response.body);
    print(getdata);
    if (!mounted) return null;
    setState(() {
      var error = getdata['error'].toString();

      if (error == 'false') {
        var data1 = (getdata['data']);

        social_media_list = (data1 as List)
            .map((data) => Social.fromJson(data as Map<String, dynamic>))
            .toList();
        // for (var f in social_media_list) {
        //   social_media.add(f.message);
        // }
      }
    });
  }

  List<Widget>? getSlider(dynamic running) {
    return map<Widget>(
      slider_image,
      (index1, i) {
        return assetsAudioPlayer.builderLoopMode(builder: (context, loopMode) {
          return PlayerBuilder.isPlaying(
              player: assetsAudioPlayer,
              builder: (context, isPlaying) {
                return GestureDetector(
                    child: Container(
                      margin: EdgeInsets.all(5.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                        child: CachedNetworkImage(
                          imageUrl: i.toString(),
                          placeholder: (context, url) =>
                              Container(),
                          width: 1000.0,
                          height: double.infinity,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    onTap: () async {
                      setState(() {
                        curPlayList = slider_list;
                      });
                      if (index1 < int.parse(curPlayList!.length.toString())) {
                        audios.clear();
                        updateQueue(
                            choiceIndex: 1,
                            start: true,
                            ind: index1,
                            context: context);
                        /*await assetsAudioPlayer.open(
                Playlist(audios: audios,startIndex:index1 ),
                showNotification: true,notificationSettings:NotificationSettings(seekBarEnabled: false,),
                autoStart: true,forceOpen: true,
              );*/
                        /* try {
                await assetsAudioPlayer.open(
                  Playlist(audios: audios,startIndex: index1),
                  autoStart: true,
                  showNotification: true,
                  playInBackground: PlayInBackground.enabled,
                  audioFocusStrategy: AudioFocusStrategy.request(
                      resumeAfterInterruption: true,
                      resumeOthersPlayersAfterDone: true),
                  headPhoneStrategy: HeadPhoneStrategy.pauseOnUnplug,
                  notificationSettings: NotificationSettings(
                  ),
                );
              } catch (e) {
                print(e);
              }*/
                      }
                    });
              });
        });
      },
    ).cast<Widget>().toList();
  }

  List<T?> map<T>(List list, Function handler) {
    List<T?> result = [];
    for (var i = 0; i < list.length; i++) {
      result.add(handler(i, list[i]));
    }

    return result;
  }

  getMiddleButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              if (Platform.isAndroid) {
                Share.share('I am listening to-\n'
                    '${curPlayList![index].title}\n'
                    '$appname\n'
                    'https://play.google.com/store/apps/details?id=$androidPackage&hl=en');
              } else {
                Share.share('I am listening to-\n'
                    '${curPlayList![index].title}\n'
                    '$appname\n'
                    '$iosPackage');
              }
            },
            color: Colors.white,
          ),
          FutureBuilder(
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return snapshot.data == true
                    ? IconButton(
                        icon: Icon(
                          Icons.favorite,
                          size: 30,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          await db.removeFav(curPlayList![favIndex].id);
                          if (!mounted) {
                            return;
                          }
                          setState(() {});
                          widget._refresh!();
                        })
                    : IconButton(
                        icon: Icon(
                          Icons.favorite_border,
                          size: 30,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          print(
                              "index in now playing is ......................$favIndex");
                          String? id, title, desc, img, url;
                          id = curPlayList![favIndex].id;
                          title = curPlayList![favIndex].name.toString();
                          desc = curPlayList![favIndex].description;
                          img = curPlayList![favIndex].image;
                          url = curPlayList![favIndex].radio_url;
                          await db.setFav(id, title, desc, img, url);
                          setState(() {});
                          widget._refresh!();
                        });
              } else {
                return Container();
              }
            },
            future: db.getFav(curPlayList![favIndex].id),
          ),
          IconButton(
            icon: Icon(Icons.queue_music),
            onPressed: () {
              panelController!.close();
            },
            color: Colors.white,
          ),
          IconButton(
            icon: Icon(Icons.report),
            onPressed: () {
              if (!mounted) {
                return;
              }
              setState(() {
                showDialog(
                    context: context,
                    builder: (_) {
                      return ReportDialog(
                        mediaItem: curPlayList![index].id,
                      );
                    });
              });
            },
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  getMediaButton() {
    return assetsAudioPlayer.builderCurrent(
      builder: (BuildContext context, Playing playing) {
        return PlayerBuilder.isPlaying(
          player: assetsAudioPlayer,
          builder: (context, isPlaying) {
            return Column(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            color: primary.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.all(Radius.circular(20.0)),
                          ),
                          width: MediaQuery.of(context).size.width - 50,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.only(left: 24, right: 24),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    FutureBuilder(
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return snapshot.data == true
                                              ? IconButton(
                                                  icon: Icon(
                                                    Icons.favorite,
                                                    size: 30,
                                                    color: Colors.white,
                                                  ),
                                                  onPressed: () async {
                                                    await db.removeFav(
                                                        curPlayList![favIndex]
                                                            .id);
                                                    if (!mounted) {
                                                      return;
                                                    }
                                                    setState(() {});
                                                    widget._refresh!();
                                                  })
                                              : IconButton(
                                                  icon: Icon(
                                                    Icons.favorite_border,
                                                    size: 30,
                                                    color: Colors.white,
                                                  ),
                                                  onPressed: () async {
                                                    print(
                                                        "index in now playing is ......................$favIndex");
                                                    String? id,
                                                        title,
                                                        desc,
                                                        img,
                                                        url;
                                                    id = curPlayList![favIndex]
                                                        .id;
                                                    title =
                                                        curPlayList![favIndex]
                                                            .name
                                                            .toString();
                                                    desc =
                                                        curPlayList![favIndex]
                                                            .description;
                                                    img = curPlayList![favIndex]
                                                        .image;
                                                    url = curPlayList![favIndex]
                                                        .radio_url;
                                                    await db.setFav(id, title,
                                                        desc, img, url);
                                                    setState(() {});
                                                    widget._refresh!();
                                                  });
                                        } else {
                                          return Container();
                                        }
                                      },
                                      future:
                                          db.getFav(curPlayList![favIndex].id),
                                    ),
                                    Row(children: [
                                      IconButton(
                                        icon: Icon(Icons.share),
                                        onPressed: () {
                                          if (Platform.isAndroid) {
                                            Share.share('I am listening to-\n'
                                                '${curPlayList![index].title}\n'
                                                '$appname\n'
                                                'https://play.google.com/store/apps/details?id=$androidPackage&hl=en');
                                          } else {
                                            Share.share('I am listening to-\n'
                                                '${curPlayList![index].title}\n'
                                                '$appname\n'
                                                '$iosPackage');
                                          }
                                        },
                                        color: Colors.white,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.report),
                                        onPressed: () {
                                          if (!mounted) {
                                            return;
                                          }
                                          setState(() {
                                            showDialog(
                                                context: context,
                                                builder: (_) {
                                                  return ReportDialog(
                                                    mediaItem:
                                                        curPlayList![index].id,
                                                  );
                                                });
                                          });
                                        },
                                        color: Colors.white,
                                      )
                                    ]),
                                  ],
                                ),
                              ),
                            ],
                          )),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.white12, offset: Offset(2, 2))
                              ],
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.topLeft,
                                stops: [0.2, 0.5, 0.9],
                                colors: [
                                  Colors.deepOrange.withOpacity(0.5),
                                  primary.withOpacity(0.7),
                                  primary,
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                  top: MediaQuery.of(context).size.height * .01,
                                  right: 15),
                              child: Container(
                                  alignment: Alignment.topCenter,
                                  child: PlayerBuilder.isBuffering(
                                    player: assetsAudioPlayer,
                                    builder: (context, isBuffering) {
                                      return isBuffering
                                          ? Container(
                                              alignment: Alignment.topCenter,
                                              padding: EdgeInsets.only(
                                                  top: 12, left: 10),
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            )
                                          : IconButton(
                                              onPressed: () async {
                                                assetsAudioPlayer.playOrPause();
                                              },
                                              icon: Icon(
                                                isPlaying
                                                    ? Icons.pause
                                                    : Icons.play_arrow,
                                                size: 48.0,
                                                color: Colors.white,
                                              ),
                                            );
                                    },
                                  )

                                  // if (playing)pauseButton(Icon(Icons.pause_circle_outline))
                                  // else playButton(Icon(Icons.play_circle_outline)),

                                  ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(left: 25,top: 10, right: 25),
                  height: MediaQuery.of(context).size.height * 0.15,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var f in social_media_list) buildIcon(f)
                      // GestureDetector(
                      //   onTap: () => print('oi'),
                      //   child :Icon(Icons.abc),
                      // ),
                      // Icon(Icons.abc),
                      // Icon(Icons.abc),
                      // Icon(Icons.abc),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  buildIcon(Social f) {
    int iconSize = 24;
    switch (f.type) {
      case 'facebook':
        return IconButton(
          iconSize: iconSize.toDouble(),
          onPressed: () => launch(f.message!),
          icon: FaIcon(FontAwesomeIcons.facebookSquare),
        );
      case 'instagram':
        return IconButton(
          iconSize: iconSize.toDouble(),
          onPressed: () => launch(f.message!),
          icon: FaIcon(FontAwesomeIcons.instagram),
        );
      case 'youtube':
        return IconButton(
          iconSize: iconSize.toDouble(),
          onPressed: () => launch(f.message!),
          icon: FaIcon(FontAwesomeIcons.youtubeSquare),
        );
      case 'twitter':
        return IconButton(
          iconSize: iconSize.toDouble(),
          onPressed: () => launch(f.message!),
          icon: FaIcon(FontAwesomeIcons.twitterSquare),
        );
      case 'site':
        return IconButton(
          iconSize: iconSize.toDouble(),
          onPressed: () => launch(f.message!),
          icon: FaIcon(FontAwesomeIcons.globe),
        );
      case 'whatsapp':
        return IconButton(
          iconSize: iconSize.toDouble(),
          onPressed: () => launch(f.message!),
          icon: FaIcon(FontAwesomeIcons.whatsapp),
        );
    }
  }
}

///report dialog
class ReportDialog extends StatefulWidget {
  final mediaItem;

  const ReportDialog({Key? key, this.mediaItem}) : super(key: key);

  @override
  _MyDialogState createState() => _MyDialogState();
}

class _MyDialogState extends State<ReportDialog> {
  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: Text(
          'Reportar',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: primary, fontSize: 20),
        ),
      ),
      content: Column(
        children: <Widget>[
          Text('Seu problema com este rádio será verificado'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: Material(
              color: Colors.transparent,
              child: TextField(
                controller: _text,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                    hintText: 'Escreva aqui sua mensagem ou problema',
                    errorText:
                        _validate ? 'OS Valores Não\'Podem ser Vazios' : null,
                    border: OutlineInputBorder()),
                maxLines: 5,
                keyboardType: TextInputType.multiline,
              ),
            ),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(
              'CANCELAR',
              style: TextStyle(color: Colors.black),
            ),
            onPressed: () {
              _validate = false;
              Navigator.pop(context, 'Cancel');
            }),
        CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(
              'ENVIAR',
              style: TextStyle(color: Colors.black),
            ),
            onPressed: () {
              if (!mounted) {
                return;
              }
              setState(() {
                _text.text.isEmpty ? _validate = true : _validate = false;
                if (_validate == false) {
                  radioReport(widget.mediaItem, _text.text);
                  Navigator.pop(context, 'Cancel');
                }
              });
            }),
      ],
    );
  }

  Future<void> radioReport(String? station_id, String msg) async {
    print(station_id! + msg);
    var data = {
      'access_key': '6808',
      'radio_station_id': station_id.toString(),
      'message': msg
    };
    var response = await http.post(report_api, body: data);

    var getdata = json.decode(response.body);
    print(getdata);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Seu problema foi enviado com sucesso',
          textAlign: TextAlign.center,
        ),
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50.0),
        ),
      ));
    }
  }
}
