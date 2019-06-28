import 'package:flutter_image_cache/cache_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('precaches images', () {
    var urls = [
      "https://i.dailymail.co.uk/1s/2019/06/27/11/15322710-0-image-a-75_1561632207565.jpg",
      "https://i.dailymail.co.uk/1s/2019/06/27/11/15322750-7187747-image-a-67_1561631405498.jpg",
      "https://i.dailymail.co.uk/1s/2019/06/27/11/15322740-7187747-image-a-69_1561631546144.jpg",
      "https://i.dailymail.co.uk/1s/2019/06/27/11/15322724-7187747-image-a-73_1561631895241.jpg",
      "https://i.dailymail.co.uk/1s/2019/06/27/11/15322738-7187747-image-a-71_1561631747228.jpg",
      "https://i.dailymail.co.uk/1s/2019/06/27/11/15323036-7187747-image-a-70_1561631740302.jpg",
    ];

    //
    urls.forEach((url) => ImageCache.instance.preCache(url));
  });
}
