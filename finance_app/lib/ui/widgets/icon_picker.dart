import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class IconPickerModal extends StatefulWidget {
  final Function(IconData) onIconSelected;

  const IconPickerModal({
    super.key,
    required this.onIconSelected,
  });

  @override
  State<IconPickerModal> createState() => _IconPickerModalState();
}

class _IconPickerModalState extends State<IconPickerModal> {
  String _searchQuery = '';
  late List<IconData> _filteredIcons;

  @override
  void initState() {
    super.initState();
    _filteredIcons = allIcons;
  }

  // Comprehensive list of Cupertino icons
  static final List<IconData> allIcons = [
    // Common
    CupertinoIcons.home,
    CupertinoIcons.heart,
    CupertinoIcons.heart_fill,
    CupertinoIcons.star,
    CupertinoIcons.star_fill,
    CupertinoIcons.star_slash,
    CupertinoIcons.star_slash_fill,
    CupertinoIcons.bookmark,
    CupertinoIcons.bookmark_fill,
    CupertinoIcons.flag,
    CupertinoIcons.flag_fill,
    CupertinoIcons.flag_circle_fill,

    // Money & Finance
    CupertinoIcons.money_dollar,
    CupertinoIcons.money_dollar_circle,
    CupertinoIcons.money_dollar_circle_fill,
    CupertinoIcons.creditcard,
    CupertinoIcons.creditcard_fill,
    CupertinoIcons.cart,
    CupertinoIcons.cart_fill,
    CupertinoIcons.shopping_cart,
    CupertinoIcons.bag,
    CupertinoIcons.bag_fill,
    CupertinoIcons.bag_badge_minus,
    CupertinoIcons.bag_badge_plus,

    // Food & Drink
    CupertinoIcons.shopping_cart,
    CupertinoIcons.drop_fill,
    CupertinoIcons.drop,
    CupertinoIcons.drop_fill,
    CupertinoIcons.drop_fill,
    CupertinoIcons.drop_fill,
    CupertinoIcons.leaf_arrow_circlepath,
    CupertinoIcons.drop,
    CupertinoIcons.drop_fill,

    // Transport
    CupertinoIcons.car,
    CupertinoIcons.car_fill,
    CupertinoIcons.car,
    CupertinoIcons.car_fill,
    CupertinoIcons.car,
    CupertinoIcons.airplane,
    CupertinoIcons.train_style_one,
    CupertinoIcons.train_style_two,
    CupertinoIcons.train_style_one,
    CupertinoIcons.map,
    CupertinoIcons.map_fill,
    CupertinoIcons.location,
    CupertinoIcons.location_fill,
    CupertinoIcons.location_circle,
    CupertinoIcons.location_circle_fill,
    CupertinoIcons.map_fill,

    // Technology
    CupertinoIcons.device_phone_portrait,
    CupertinoIcons.device_phone_portrait,
    CupertinoIcons.device_laptop,
    CupertinoIcons.device_desktop,
    CupertinoIcons.square_stack_fill,
    CupertinoIcons.gamecontroller,
    CupertinoIcons.gamecontroller_fill,
    CupertinoIcons.waveform,
    CupertinoIcons.waveform_circle,
    CupertinoIcons.waveform_circle_fill,
    CupertinoIcons.wifi,
    CupertinoIcons.wifi,
    CupertinoIcons.wifi_exclamationmark,
    CupertinoIcons.wifi_slash,
    CupertinoIcons.bluetooth,

    // Media
    CupertinoIcons.camera,
    CupertinoIcons.camera_fill,
    CupertinoIcons.camera_viewfinder,
    CupertinoIcons.camera_on_rectangle,
    CupertinoIcons.camera_on_rectangle_fill,
    CupertinoIcons.film,
    CupertinoIcons.film_fill,
    CupertinoIcons.play,
    CupertinoIcons.play_fill,
    CupertinoIcons.play_circle,
    CupertinoIcons.play_circle_fill,
    CupertinoIcons.pause,
    CupertinoIcons.pause_fill,
    CupertinoIcons.pause_circle,
    CupertinoIcons.pause_circle_fill,
    CupertinoIcons.stop_fill,
    CupertinoIcons.music_note,
    CupertinoIcons.music_albums,
    CupertinoIcons.music_albums_fill,
    CupertinoIcons.speaker,
    CupertinoIcons.speaker_1,
    CupertinoIcons.speaker_2,
    CupertinoIcons.speaker_3,
    CupertinoIcons.speaker_fill,
    CupertinoIcons.speaker_1_fill,
    CupertinoIcons.speaker_2_fill,
    CupertinoIcons.speaker_3_fill,
    CupertinoIcons.speaker_zzz_fill,
    CupertinoIcons.mic,
    CupertinoIcons.mic_fill,
    CupertinoIcons.mic_fill,
    CupertinoIcons.mic_fill,

    // Health & Fitness
    CupertinoIcons.heart_circle,
    CupertinoIcons.heart_circle_fill,
    CupertinoIcons.heart_slash,
    CupertinoIcons.heart_slash_fill,
    CupertinoIcons.plus_circle,
    CupertinoIcons.plus_circle_fill,
    CupertinoIcons.minus_circle,
    CupertinoIcons.minus_circle_fill,
    CupertinoIcons.checkmark_circle,
    CupertinoIcons.checkmark_circle_fill,
    CupertinoIcons.xmark_circle,
    CupertinoIcons.xmark_circle_fill,
    CupertinoIcons.flame,
    CupertinoIcons.flame_fill,
    CupertinoIcons.bolt,
    CupertinoIcons.bolt_fill,

    // Household
    CupertinoIcons.home,
    CupertinoIcons.building_2_fill,
    CupertinoIcons.bed_double_fill,
    CupertinoIcons.home,
    CupertinoIcons.home,
    CupertinoIcons.drop_fill,
    CupertinoIcons.drop_fill,
    CupertinoIcons.drop_fill,
    CupertinoIcons.drop_fill,
    CupertinoIcons.shopping_cart,
    CupertinoIcons.scissors,
    CupertinoIcons.hammer_fill,
    CupertinoIcons.wrench,
    CupertinoIcons.wrench_fill,

    // Shopping & Fashion
    CupertinoIcons.bag,
    CupertinoIcons.bag_fill,
    CupertinoIcons.bag_fill,
    CupertinoIcons.bag_fill,
    CupertinoIcons.eyeglasses,
    CupertinoIcons.clock,
    CupertinoIcons.clock_fill,
    CupertinoIcons.eyeglasses,
    CupertinoIcons.star_fill,
    CupertinoIcons.star_fill,
    CupertinoIcons.sparkles,

    // Education
    CupertinoIcons.book,
    CupertinoIcons.book_fill,
    CupertinoIcons.book_circle,
    CupertinoIcons.book_circle_fill,
    CupertinoIcons.square_stack,
    CupertinoIcons.square_stack_fill,
    CupertinoIcons.pencil,
    CupertinoIcons.pencil_circle,
    CupertinoIcons.pencil_circle_fill,
    CupertinoIcons.pencil_circle_fill,
    CupertinoIcons.paintbrush,
    CupertinoIcons.paintbrush_fill,
    CupertinoIcons.paintbrush,
    CupertinoIcons.paintbrush_fill,
    CupertinoIcons.book_fill,
    CupertinoIcons.book_fill,

    // Time & Calendar
    CupertinoIcons.calendar,
    CupertinoIcons.calendar_circle,
    CupertinoIcons.calendar_circle_fill,
    CupertinoIcons.calendar_badge_plus,
    CupertinoIcons.calendar_badge_minus,
    CupertinoIcons.clock,
    CupertinoIcons.clock_fill,
    CupertinoIcons.timer,
    CupertinoIcons.timer_fill,
    CupertinoIcons.hourglass,
    CupertinoIcons.hourglass_bottomhalf_fill,
    CupertinoIcons.hourglass_tophalf_fill,
    CupertinoIcons.stopwatch,
    CupertinoIcons.stopwatch_fill,
    CupertinoIcons.sun_min,
    CupertinoIcons.sun_min_fill,
    CupertinoIcons.moon,
    CupertinoIcons.moon_fill,
    CupertinoIcons.moon_circle,
    CupertinoIcons.moon_circle_fill,
    CupertinoIcons.moon_stars,
    CupertinoIcons.moon_stars_fill,
    CupertinoIcons.sunrise_fill,
    CupertinoIcons.sunset_fill,
    CupertinoIcons.sunrise,
    CupertinoIcons.sunset,

    // Weather
    CupertinoIcons.cloud,
    CupertinoIcons.cloud_fill,
    CupertinoIcons.cloud_sun,
    CupertinoIcons.cloud_sun,
    CupertinoIcons.cloud_sun,
    CupertinoIcons.cloud_sun_fill,
    CupertinoIcons.cloud_rain,
    CupertinoIcons.cloud_rain_fill,
    CupertinoIcons.cloud_rain,
    CupertinoIcons.cloud_rain_fill,
    CupertinoIcons.cloud_snow,
    CupertinoIcons.cloud_snow_fill,
    CupertinoIcons.cloud_sleet,
    CupertinoIcons.cloud_sleet_fill,
    CupertinoIcons.cloud_hail,
    CupertinoIcons.cloud_hail_fill,
    CupertinoIcons.wind,
    CupertinoIcons.wind,
    CupertinoIcons.wind,
    CupertinoIcons.snow,
    CupertinoIcons.flame_fill,
    CupertinoIcons.drop,
    CupertinoIcons.drop_fill,
    CupertinoIcons.umbrella,
    CupertinoIcons.umbrella_fill,
    CupertinoIcons.thermometer,
    CupertinoIcons.thermometer_sun,

    // Nature & Animals
    CupertinoIcons.leaf_arrow_circlepath,
    CupertinoIcons.leaf_arrow_circlepath,
    CupertinoIcons.leaf_arrow_circlepath,
    CupertinoIcons.heart_fill,
    CupertinoIcons.heart_fill,
    CupertinoIcons.ant_fill,
    CupertinoIcons.ant_fill,
    CupertinoIcons.hare_fill,
    CupertinoIcons.tortoise_fill,
    CupertinoIcons.tortoise_fill,
    CupertinoIcons.heart_fill,

    // Sports & Recreation
    CupertinoIcons.sportscourt_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.square_stack_fill,
    CupertinoIcons.bolt_fill,

    // Travel & Places
    CupertinoIcons.airplane,
    CupertinoIcons.airplane,
    CupertinoIcons.airplane,
    CupertinoIcons.globe,
    CupertinoIcons.globe,
    CupertinoIcons.globe,
    CupertinoIcons.map,
    CupertinoIcons.map_fill,
    CupertinoIcons.location_fill,
    CupertinoIcons.umbrella_fill,
    CupertinoIcons.location_fill,
    CupertinoIcons.location_fill,
    CupertinoIcons.train_style_one,
    CupertinoIcons.train_style_two,

    // Security & Safety
    CupertinoIcons.lock,
    CupertinoIcons.lock_fill,
    CupertinoIcons.lock_circle,
    CupertinoIcons.lock_circle_fill,
    CupertinoIcons.lock_slash,
    CupertinoIcons.lock_slash_fill,
    CupertinoIcons.lock_rotation,
    CupertinoIcons.lock_rotation_open,
    CupertinoIcons.lock_rotation_open,
    CupertinoIcons.lock_rotation_open,
    CupertinoIcons.lock_rotation_open,
    CupertinoIcons.lock_rotation_open,
    CupertinoIcons.shield,
    CupertinoIcons.shield_fill,
    CupertinoIcons.shield_slash,
    CupertinoIcons.shield_slash_fill,
    CupertinoIcons.shield_lefthalf_fill,
    CupertinoIcons.exclamationmark_triangle,
    CupertinoIcons.exclamationmark_triangle_fill,
    CupertinoIcons.exclamationmark_circle,
    CupertinoIcons.exclamationmark_circle_fill,
    CupertinoIcons.eye,
    CupertinoIcons.eye_fill,
    CupertinoIcons.eye_slash,
    CupertinoIcons.eye_slash_fill,
    CupertinoIcons.eye_fill,
    CupertinoIcons.eye_fill,
    CupertinoIcons.checkmark,
    CupertinoIcons.checkmark_alt,
    CupertinoIcons.checkmark_circle,
    CupertinoIcons.checkmark_circle_fill,
    CupertinoIcons.xmark,
    CupertinoIcons.xmark_circle,
    CupertinoIcons.xmark_circle_fill,
    CupertinoIcons.xmark_octagon,
    CupertinoIcons.xmark_octagon_fill,

    // Misc
    CupertinoIcons.ellipsis,
    CupertinoIcons.ellipsis_vertical,
    CupertinoIcons.arrow_up,
    CupertinoIcons.arrow_down,
    CupertinoIcons.arrow_left,
    CupertinoIcons.arrow_right,
    CupertinoIcons.arrow_up_circle,
    CupertinoIcons.arrow_down_circle,
    CupertinoIcons.arrow_left_circle,
    CupertinoIcons.arrow_right_circle,
    CupertinoIcons.arrow_up_circle_fill,
    CupertinoIcons.arrow_down_circle_fill,
    CupertinoIcons.arrow_left_circle_fill,
    CupertinoIcons.arrow_right_circle_fill,
    CupertinoIcons.arrowtriangle_up_fill,
    CupertinoIcons.arrowtriangle_down_fill,
    CupertinoIcons.arrowtriangle_left_fill,
    CupertinoIcons.arrowtriangle_right_fill,
    CupertinoIcons.pin,
    CupertinoIcons.pin_fill,
    CupertinoIcons.pin_slash,
    CupertinoIcons.pin_slash_fill,
    CupertinoIcons.pin_fill,
    CupertinoIcons.pin_fill,
    CupertinoIcons.gift,
    CupertinoIcons.gift_fill,
    CupertinoIcons.hand_raised,
    CupertinoIcons.hand_raised_fill,
    CupertinoIcons.hand_thumbsup,
    CupertinoIcons.hand_thumbsup_fill,
    CupertinoIcons.hand_thumbsdown,
    CupertinoIcons.hand_thumbsdown_fill,
    CupertinoIcons.hand_draw,
    CupertinoIcons.hand_draw_fill,
  ];

  void _updateSearch(String value) {
    setState(() {
      _searchQuery = value;
      // Simple filtering - in the future could add icon name matching
      _filteredIcons = allIcons;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: Spacing.xl),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Choose Icon',
              style: AppStyles.titleStyle(context)
                  .copyWith(fontSize: TypeScale.title2),
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppStyles.getBackground(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoTextField(
                placeholder:
                    'Search icons (${_filteredIcons.length} available)',
                placeholderStyle:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                style: TextStyle(color: AppStyles.getTextColor(context)),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                onChanged: _updateSearch,
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // Icons Grid
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const cols = 4;
                const hPad = 16.0;
                const spacing = 16.0;
                final gridW = constraints.maxWidth - hPad * 2;
                final itemW = (gridW - (cols - 1) * spacing) / cols;
                return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: hPad),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: spacing,
                mainAxisSpacing: 20,
                childAspectRatio: itemW / (itemW / 0.9),
              ),
              itemCount: _filteredIcons.length,
              itemBuilder: (context, index) {
                final icon = _filteredIcons[index];
                return GestureDetector(
                  onTap: () {
                    widget.onIconSelected(icon);
                    Navigator.pop(context);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 24,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
                );
              },
            ),
          ),
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}
