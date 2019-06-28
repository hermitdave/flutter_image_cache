library flutter_image_cache;

import 'dart:io';

import 'package:flutter/material.dart';
import 'cache_base.dart' as cache;

class CachedImage extends StatelessWidget {
  CachedImage({this.url, this.fit: BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: cache.ImageCache.instance.getFromCache(url).then((file) async {
        return await file.exists() ? file : null;
      }),
      builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.done:
            //print('rendering image from file ${snapshot.data != null}');
            return snapshot.data != null
                ? Image.file(snapshot.data, fit: fit)
                : Image.network(url, fit: fit);

          default:
            return Container();
        }
      },
    );
  }
}
