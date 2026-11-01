import 'package:flutter/material.dart';

/// 3D illustrations used across the app instead of icons and emoji.
///
/// The pictures come from Microsoft's Fluent Emoji set (MIT licence, see
/// assets/art/LICENSE.txt). Using real artwork means every phone shows the
/// same pictures, and they look far richer than system emoji.

/// Shows one picture from assets/art by its file name (without .png).
class KidArt extends StatelessWidget {
  final String name;
  final double size;
  final bool grey;

  const KidArt(this.name, {super.key, this.size = 64, this.grey = false});

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      'assets/art/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );
    if (grey) {
      // Locked things show as a soft silhouette, like an empty sticker slot.
      img = Opacity(
        opacity: 0.35,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0, 0, 0, 1, 0,
          ]),
          child: img,
        ),
      );
    }
    return img;
  }
}

/// Draws the 3D picture that matches a content emoji (for example the cat
/// on the "CAT" word card). The emoji itself is never shown as text.
class KidEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  final bool grey;

  const KidEmoji(this.emoji, {super.key, this.size = 40, this.grey = false});

  /// The picture file for [emoji], or null.
  static String? artFor(String emoji) =>
      _emojiArt[emoji] ?? _emojiArt[emoji.replaceAll('️', '')];

  @override
  Widget build(BuildContext context) {
    final art = artFor(emoji);
    if (art != null) return KidArt(art, size: size, grey: grey);
    return SizedBox(
      width: size,
      height: size,
      child:
          FittedBox(child: Text(emoji, style: TextStyle(fontSize: size * 0.8))),
    );
  }
}

/// Three stars, filled with 3D gold stars for the ones earned.
class KidStars extends StatelessWidget {
  final int earned;
  final double size;
  const KidStars(this.earned, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          Icon(Icons.star_rounded,
              size: size,
              color: i < earned ? const Color(0xFFFFB800) : const Color(0xFFDCD8EE)),
      ],
    );
  }
}

const Map<String, String> _emojiArt = {
  '⏰': 'alarm_clock',
  '⏱️': 'stopwatch',
  '☀️': 'sun',
  '☁️': 'cloud',
  '⚙️': 'gear',
  '⚠️': 'warning',
  '⚡': 'high_voltage',
  '⚽': 'soccer_ball',
  '⛰️': 'mountain',
  '✅': 'check_mark_button',
  '✍️': 'writing_hand',
  '✏️': 'pencil',
  '✓': 'check_mark',
  '✨': 'sparkles',
  '❤️': 'red_heart',
  '⭐': 'star',
  '🃏': 'joker',
  '🌈': 'rainbow',
  '🌋': 'volcano',
  '🌍': 'globe_showing_europe_africa',
  '🌙': 'crescent_moon',
  '🌟': 'glowing_star',
  '🌳': 'deciduous_tree',
  '🍎': 'red_apple',
  '🎁': 'wrapped_gift',
  '🎂': 'birthday_cake',
  '🎈': 'balloon',
  '🎉': 'party_popper',
  '🎒': 'backpack',
  '🎓': 'graduation_cap',
  '🎨': 'artist_palette',
  '🎩': 'top_hat',
  '🎪': 'circus_tent',
  '🎮': 'video_game',
  '🏁': 'chequered_flag',
  '🏅': 'sports_medal',
  '🏆': 'trophy',
  '🏝️': 'desert_island',
  '🏠': 'house',
  '🏫': 'school',
  '🏰': 'castle',
  '🐙': 'octopus',
  '🐜': 'ant',
  '🐝': 'honeybee',
  '🐟': 'fish',
  '🐢': 'turtle',
  '🐣': 'hatching_chick',
  '🐦': 'bird',
  '🐮': 'cow_face',
  '🐱': 'cat_face',
  '🐶': 'dog_face',
  '🐷': 'pig_face',
  '🐸': 'frog',
  '🐻': 'bear',
  '🐼': 'panda',
  '🐾': 'paw_prints',
  '👀': 'eyes',
  '👋': 'waving_hand',
  '👍': 'thumbs_up',
  '👑': 'crown',
  '👨‍👩‍👧': 'girl',
  '👶': 'baby',
  '💎': 'gem_stone',
  '💡': 'light_bulb',
  '💨': 'dashing_away',
  '💪': 'flexed_biceps',
  '📄': 'page_facing_up',
  '📈': 'chart_increasing',
  '📊': 'bar_chart',
  '📋': 'clipboard',
  '📏': 'straight_ruler',
  '📚': 'books',
  '📝': 'memo',
  '📦': 'package',
  '📶': 'antenna_bars',
  '📷': 'camera',
  '📺': 'television',
  '🔀': 'shuffle_tracks_button',
  '🔁': 'repeat_button',
  '🔄': 'counterclockwise_arrows_button',
  '🔊': 'speaker_high_volume',
  '🔑': 'key',
  '🔒': 'locked',
  '🔔': 'bell',
  '🔚': 'end_arrow',
  '🔠': 'input_latin_uppercase',
  '🔡': 'input_latin_lowercase',
  '🔢': 'input_numbers',
  '🔤': 'input_latin_letters',
  '🔥': 'fire',
  '🕯️': 'candle',
  '🖊️': 'pen',
  '🖍️': 'crayon',
  '🖼️': 'framed_picture',
  '🗓️': 'spiral_calendar',
  '🗺️': 'world_map',
  '🚀': 'rocket',
  '🚌': 'bus',
  '🚗': 'automobile',
  '🛠️': 'hammer_and_wrench',
  '🛡️': 'shield',
  '🟠': 'orange_circle',
  '🟢': 'green_circle',
  '🤔': 'thinking_face',
  '🤖': 'robot',
  '🥚': 'egg',
  '🥛': 'glass_of_milk',
  '🥷': 'ninja',
  '🦁': 'lion',
  '🦄': 'unicorn',
  '🦆': 'duck',
  '🦇': 'bat',
  '🦖': 't_rex',
  '🧠': 'brain',
  '🧩': 'puzzle_piece',
  '🧱': 'brick',
  '🧸': 'teddy_bear',
  '🧽': 'sponge',
  '🪄': 'magic_wand',
};
